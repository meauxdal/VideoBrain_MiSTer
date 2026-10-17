#include "Vvideobrain_audio_fir.h"
#include "verilated.h"
#include <cassert>
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <string>
#include <vector>

static Vvideobrain_audio_fir dut;

static int32_t tick() {
    dut.clk = 0;
    dut.eval();
    dut.clk = 1;
    dut.eval();
    int32_t value = dut.output_sample;
    return (value & 0x800000) ? value - 0x1000000 : value;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    assert(argc == 2);
    std::ifstream source(argv[1]);
    assert(source.good());
    std::vector<int64_t> coeff;
    std::string line;
    const std::string prefix = "coefficient = 24'sh";
    while (std::getline(source, line)) {
        auto start = line.find(prefix);
        if (start == std::string::npos) continue;
        int64_t value = std::stoll(line.substr(start + prefix.size(), 6), nullptr, 16);
        coeff.push_back((value & 0x800000) ? value - 0x1000000 : value);
    }
    assert(coeff.size() == 81);
    for (int i = 79; i >= 0; --i) coeff.push_back(coeff[i]);
    uint32_t random = 1;
    for (int pass = 0; pass < 2; ++pass) {
        dut.reset = 1;
        assert(tick() == 0);
        dut.reset = 0;
        std::vector<int64_t> history(161, 0);
        int32_t previous = 0;
        for (int sample = 0; sample < 600; ++sample) {
            random = random * 1664525u + 1013904223u;
            for (int i = 160; i > 0; --i) history[i] = history[i - 1];
            history[0] = static_cast<int32_t>(random % 6000001u) - 3000000;
            int64_t sum = 0;
            for (int i = 0; i < 161; ++i) sum += history[i] * coeff[i];
            int32_t expected = static_cast<int32_t>((sum + (1 << 22)) >> 23);
            for (int cycle = 0; cycle < 128; ++cycle) {
                // Only the decimation instant may capture the input.
                dut.input_sample = cycle == 0 ? history[0] : 123456;
                assert(tick() == (cycle < 83 ? previous : expected));
            }
            previous = expected;
        }
        // Reset with reads and a multiply in flight, leaving RAM populated.
        for (int i = 0; i < 17; ++i) tick();
    }
    puts("FIR convolution, wraparound, hold and warm reset tests passed");
}
