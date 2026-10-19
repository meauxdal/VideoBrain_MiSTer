#include "Vtb_audio_path.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    if (argc != 4) return 2;
    const int frequency = std::atoi(argv[1]);
    const int rate = std::atoi(argv[2]);
    if (frequency < 100 || frequency > 8000 || (rate != 48000 && rate != 96000)) return 2;
    FILE* output = std::fopen(argv[3], "wb");
    if (!output) return 2;
    Vtb_audio_path dut;
    dut.reset = 1;
    dut.sample_rate = rate == 96000;
    dut.tone_hz = frequency;
    dut.clk_core = 0;
    dut.clk_audio = 0;
    dut.eval();
    uint64_t core_edge = 1, audio_edge = 1;
    uint64_t core_ticks = 0, last_transition = 0;
    uint16_t word = 0;
    int bits = 0, frames = 0, captured = 0;
    int16_t left = 0, core = 0;
    bool synchronized = false;
    bool last_lrclk = dut.lrclk;
    const int settle = rate / 4;
    const int count = rate / 4;
    while (captured < count) {
        if (audio_edge > 2ULL * 24576000) {
            std::fprintf(stderr, "I2S capture did not complete within one simulated second\n");
            return 1;
        }
        // Integer event times keep the two oscillator frequencies independent.
        const uint64_t core_time = core_edge * 24576000ULL;
        const uint64_t audio_time = audio_edge * 14318181ULL;
        bool core_event = core_time <= audio_time;
        bool audio_event = audio_time <= core_time;
        bool old_bclk = dut.bclk;
        int old_code = dut.tone_code;
        if (core_event) { dut.clk_core = !dut.clk_core; ++core_edge; }
        if (audio_event) { dut.clk_audio = !dut.clk_audio; ++audio_edge; }
        if (audio_edge > 200) dut.reset = 0;
        dut.eval();
        if (core_event && dut.clk_core && !dut.reset) {
            ++core_ticks;
            if (dut.tone_code != old_code) {
                auto width = core_ticks - last_transition;
                int minimum = 14318181 / (2 * frequency);
                if (last_transition && (width < unsigned(minimum) || width > unsigned(minimum + 1))) {
                    std::fprintf(stderr, "Irregular source pulse: %llu clocks\n", static_cast<unsigned long long>(width));
                    return 1;
                }
                last_transition = core_ticks;
            }
        }
        if (dut.reset) { last_lrclk = dut.lrclk; continue; }
        if (old_bclk || !dut.bclk) continue;
        word = (word << 1) | dut.sdata;
        ++bits;
        // I2S changes LRCLK one bit before the next channel's MSB.
        if (dut.lrclk == last_lrclk) continue;
        if (synchronized) {
            if (bits != 16) { std::fprintf(stderr, "I2S word length: %d\n", bits); return 1; }
            if (!last_lrclk) {
                left = static_cast<int16_t>(word);
                core = static_cast<int16_t>(dut.core_sample);
            } else if (frames++ >= settle) {
                int16_t row[] = {core, left, static_cast<int16_t>(word)};
                if (std::fwrite(row, sizeof(row), 1, output) != 1) return 1;
                ++captured;
            }
        }
        synchronized = true;
        last_lrclk = dut.lrclk;
        word = 0;
        bits = 0;
    }
    std::fclose(output);
    std::printf("%d Hz, %d samples/s: decoded %d stereo I2S frames\n", frequency, rate, captured);
    return 0;
}
