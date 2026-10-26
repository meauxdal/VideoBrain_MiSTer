derive_pll_clocks
derive_clock_uncertainty

# core specific constraints

# The core runs entirely on clk_sys (14.318181 MHz UV202 master clock).
# derive_pll_clocks above names it; nothing crosses domains inside the core.

# The board's user activity LED has no external capture clock.
set_false_path -to [get_ports {LED[0]}]
