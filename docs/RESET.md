# Reset and Master Control

**Reset**, the MiSTer reset input and the framework reset button perform a power cycle. Loaded BIOS, cartridge and Expander ROMs remain installed. System RAM, cartridge RAM and both CPUs' scratch registers are cleared before execution resumes; the cartridge bank returns to zero. Zero fill is a deterministic startup convention, not a claim about unpowered SRAM contents.

**Master Control** and enabled Esc follow the board's key circuit. U39 samples the active-low key into two 74LS74 stages on falling VBLANK. U26 ORs Q2 and /Q1 to produce one active-low reset pulse lasting one field. Holding the key does not repeat reset; release must be sampled before another press. Video timing continues through this pulse. RAM and the cartridge bank remain powered. Other held keyboard keys remain pressed.

Source: Sean Riddle's [board connections](https://seanriddle.com/videobrain.xlsx), `all connections`: U39.12 = keyboard connector 6/26, U39.9 = U39.2, U39.3/11 = inverted VBLANK, U26.1/2 = U39.9/6. U26.3 drives CPU /EXTRES, UV201, UV202 and cartridge reset. The [Expander connections](https://seanriddle.com/vbexpander1.xlsx) connect its reset to the host accessory port.

ROM downloads and cartridge unload retain their existing machine-reset behavior. **Reset on Cartridge Load > Off** still permits hot loading.

`make -C verilator test-download-reset test-cartridges test-cpu-reset test-power-cycle` checks key pulse timing, reset sources, RAM retention/clearing, cartridge bank restoration, CPU scratch state and continuous video timing during Master Control.
