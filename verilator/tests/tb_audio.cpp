#include "Vvideobrain_audio.h"
#include "verilated.h"
#include <cassert>
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
