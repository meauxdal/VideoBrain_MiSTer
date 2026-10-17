LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.base_pack.ALL;
USE work.uv201_pack.ALL;

ENTITY video_test_source IS
  PORT (
    clk, reset_na : IN std_logic;
    ce_pix, field, de, hs, vs, hb, vb : OUT std_logic;
    hpos : OUT unsigned(7 DOWNTO 0);
    vpos : OUT unsigned(8 DOWNTO 0);
    r, g, b : OUT uv8
  );
END ENTITY;

ARCHITECTURE test OF video_test_source IS
  SIGNAL brclk_ena, hblank, vblank, field_l : std_logic;
  SIGNAL x : unsigned(7 DOWNTO 0);
  SIGNAL y : unsigned(8 DOWNTO 0);
  SIGNAL background : std_logic_vector(7 DOWNTO 0);
BEGIN
  clocks : ENTITY work.uv202_clkgen
    PORT MAP (clk => clk, reset_na => reset_na,
              mclk_ena => OPEN, brclk_ena => brclk_ena,
              brclk_phase => OPEN, cpu_ena => OPEN);

  timing : ENTITY work.uv202_timing
    PORT MAP (clk => clk, reset_na => reset_na, brclk_ena => brclk_ena,
              hblank => hblank, vblank => vblank, field => field_l,
              hpos => x, vpos => y, burst => OPEN, csync => OPEN,
              scanline => OPEN, line_start => OPEN,
              hblank_falling => OPEN, hblank_rising => OPEN);

  -- Field-dependent color and live changes on the last visible rows.
  background <= "000" & field_l & std_logic_vector(y(3 DOWNTO 0));
  render : ENTITY work.uv201_render
    PORT MAP (clk => clk, reset_na => reset_na, brclk_ena => brclk_ena,
              hblank => hblank, vblank => vblank, hpos => x, vpos => y,
              fifo_valid => '0', fifo_entry => UV201_FIFO_ENTRY_ZERO,
              fifo_pop => OPEN, final_mod => x"00", background => background,
              x_zoom => '0', video_en => '1', ce_pix => ce_pix, idx => OPEN,
              r => r, g => g, b => b, de => de, hs => hs, vs => vs,
              hb => hb, vb => vb);

  field <= field_l;
  hpos <= x;
  vpos <= y;
END ARCHITECTURE;
