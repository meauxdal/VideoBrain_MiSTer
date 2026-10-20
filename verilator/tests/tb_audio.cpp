#include "Vvideobrain_audio.h"
#include "verilated.h"
#include <algorithm>
#include <cassert>
#include <cmath>
#include <complex>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

static Vvideobrain_audio dut;

static int tick() {
    dut.clk = 0;
    dut.eval();
    dut.clk = 1;
    dut.eval();
    return static_cast<int16_t>(dut.sample);
}

static void reset() {
    dut.reset = 1;
    assert(tick() == 0);
    dut.reset = 0;
    dut.stb = 0;
}

static void check_response(int period, double min_gain_db, double max_gain_db) {
    reset();
    const double pi = std::acos(-1.0);
    const double omega = 2 * pi / period;
    const int settle = (60000 / period + 1) * period;
    std::complex<double> raw_sum = 0, filtered_sum = 0;
    dut.stb = 1;
    for (int i = 0; i < settle + period * 32; ++i) {
        dut.code = (i % period < period / 2) ? 0 : 3;
        int sample = tick();
        assert(sample >= -8256 && sample <= 4160);
        if (i < settle) continue;
        auto phase = std::polar(1.0, -omega * (i % period));
        raw_sum += static_cast<double>(dut.code * 4096 - 8192) * phase;
        filtered_sum += static_cast<double>(sample) * phase;
    }
    double gain_db = 20 * std::log10(std::abs(filtered_sum / raw_sum));
    if (gain_db < -100)
        std::printf("%.1f Hz: below output resolution\n", 14318181.0 / period);
    else
        std::printf("%.1f Hz: %.2f dB\n", 14318181.0 / period, gain_db);
    assert(gain_db >= min_gain_db);
    assert(gain_db < max_gain_db);
}

static void check_decimation_alias(int period) {
    reset();
    double sum = 0, power = 0;
    const int count = 262144;
    for (int i = 0; i < 60000 + count; ++i) {
        dut.stb = 1;
        dut.code = (i % period < period / 2) ? 0 : 3;
        double sample = tick();
        if (i < 60000) continue;
        sum += sample;
        power += sample * sample;
    }
    double variance = power / count - (sum / count) * (sum / count);
    std::printf("Decimation input %.1f Hz: AC RMS %.4f\n",
                14318181.0 / period, std::sqrt(std::max(variance, 0.0)));
    assert(variance < 0.25);
}

static void capture_sweep(const char* path) {
    FILE* output = std::fopen(path, "wb");
    assert(output);
    for (int note = 0; note < 36; ++note) {
        int period = std::lround(14318181.0 / (1046.5023 * std::pow(2.0, note / 12.0)));
        reset();
        int64_t poles[4] = {}, dac = 0;
        int count = 0;
        for (int i = 0; count < 262144; ++i) {
            dut.stb = 1;
            dut.code = (i % period < period / 2) ? 0 : 3;
            int filtered = tick();
            int64_t delta[] = {dac * 1024 - poles[0], poles[0] - poles[1],
                               poles[1] - poles[2], poles[2] - poles[3]};
            int shifts[] = {10, 9, 8, 8};
            for (int p = 0; p < 4; ++p) poles[p] += delta[p] >> shifts[p];
            dac = dut.code * 4096 - 8192;
            assert(filtered >= -8256 && filtered <= 4160);
            if (i < 60000) continue;
            int32_t row[] = {note, static_cast<int32_t>(poles[3] >> 10), filtered};
            assert(std::fwrite(row, sizeof(row), 1, output) == 1);
            ++count;
        }
    }
    std::fclose(output);
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    reset();
    for (int code = 0; code < 4; ++code) {
        dut.code = code;
        dut.stb = 1;
        tick();
        dut.stb = 0;
        int target = code * 4096 - 8192;
        int prev = static_cast<int16_t>(dut.sample);
        for (int i = 0; i < 60000; ++i) {
            int sample = tick();
            assert(sample >= -8256 && sample <= 4160);
            prev = sample;
        }
        std::printf("DC code %d: %d (target %d)\n", code, prev, target);
        assert(std::abs(prev - target) <= 2);
        dut.code = code ^ 3;
        for (int i = 0; i < 2000; ++i) tick();
        assert(std::abs(static_cast<int16_t>(dut.sample) - target) <= 2);
    }
    reset();
    for (int i = 0; i < 60000; ++i) assert(tick() == 0);
    puts("Audio reset, latch, range and DC tests passed");

    check_response(28636, -0.5, -0.33);
    check_response(14318, -1.65, -1.4);
    check_response(7158, -4.7, -4.45);
    check_response(1302, -23, -22.4);
    check_response(1101, -33, -31);
    check_response(1023, -71, -65);
    check_response(988, -INFINITY, -85);
    check_response(596, -INFINITY, -85);
    check_response(448, -INFINITY, -85);
    check_response(298, -INFINITY, -85);
    puts("Audio passband and stopband tests passed");
    for (int period : {64, 126, 128, 130, 256}) check_decimation_alias(period);

    if (argc == 3 && std::string(argv[1]) == "--sweep") {
        capture_sweep(argv[2]);
        return 0;
    }
    if (argc != 3) return 0;
    struct Event { unsigned long long cycle; int code; };
    std::vector<Event> events;
    std::ifstream input(argv[1]);
    assert(input.good());
    std::string line;
    std::getline(input, line);
    while (std::getline(input, line)) {
        std::stringstream row(line);
        std::string value;
        std::getline(row, value, ',');
        unsigned long long cycle = std::stoull(value);
        for (int i = 0; i < 3; ++i) std::getline(row, value, ',');
        events.push_back({cycle, std::stoi(value)});
    }
    assert(!events.empty());
    FILE* output = std::fopen(argv[2], "w");
    assert(output);
    std::fprintf(output, "cycle,raw,filtered\n");
    size_t event = 0;
    unsigned phase = 0;
    int code = 2;
    reset();
    for (auto cycle = events.front().cycle; cycle <= events.back().cycle; ++cycle) {
        dut.stb = event < events.size() && cycle == events[event].cycle;
        if (dut.stb) {
            code = events[event++].code;
            dut.code = code;
        }
        int sample = tick();
        phase += 384000;
        if (phase >= 14318181) {
            phase -= 14318181;
            std::fprintf(output, "%llu,%d,%d\n", cycle, code * 4096 - 8192, sample);
        }
    }
    std::fclose(output);
    return 0;
}
