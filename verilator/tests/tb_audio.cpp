#include "Vvideobrain_audio.h"
#include "verilated.h"
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

static void check_response(int period, double max_gain_db) {
    reset();
    const double pi = std::acos(-1.0);
    const double omega = 2 * pi / period;
    const int settle = (30000 / period + 1) * period;
    std::complex<double> raw_sum = 0, filtered_sum = 0;
    dut.stb = 1;
    for (int i = 0; i < settle + period * 32; ++i) {
        dut.code = (i % period < period / 2) ? 0 : 3;
        int sample = tick();
        assert(sample >= -8194 && sample <= 4096);
        if (i < settle) continue;
        auto phase = std::polar(1.0, -omega * (i % period));
        raw_sum += static_cast<double>(dut.code * 4096 - 8192) * phase;
        filtered_sum += static_cast<double>(sample) * phase;
    }
    auto z = std::polar(1.0, -omega);
    std::complex<double> response = 1;
    for (int shift : {10, 9, 8, 8}) {
        double alpha = 1.0 / (1 << shift);
        response *= alpha / (1.0 - (1.0 - alpha) * z);
    }
    double gain_db = 20 * std::log10(std::abs(filtered_sum / raw_sum));
    double expected_db = 20 * std::log10(std::abs(response));
    std::printf("%.1f Hz: %.2f dB (expected %.2f dB)\n",
                14318181.0 / period, gain_db, expected_db);
    assert(std::abs(gain_db - expected_db) < (period > 1000 ? 0.1 : 1.5));
    assert(gain_db < max_gain_db);
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
        for (int i = 0; i < 20000; ++i) {
            int sample = tick();
            assert(sample >= -8194 && sample <= 4096);
            if (code == 0) assert(sample <= prev);
            else assert(sample >= prev);
            prev = sample;
        }
        assert(std::abs(prev - target) <= 2);
        dut.code = code ^ 3;
        for (int i = 0; i < 2000; ++i) tick();
        assert(std::abs(static_cast<int16_t>(dut.sample) - target) <= 2);
    }
    reset();
    for (int i = 0; i < 2000; ++i) assert(tick() == 0);
    puts("Audio reset, latch, range and DC tests passed");

    check_response(28636, 0);
    check_response(14318, 0);
    check_response(7158, 0);
    check_response(596, -53);
    check_response(448, -62);
    check_response(298, -75);
    puts("Audio passband and stopband tests passed");

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
