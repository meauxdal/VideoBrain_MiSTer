LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.base_pack.ALL;

ENTITY tb_power_cycle_core IS END ENTITY;

ARCHITECTURE test OF tb_power_cycle_core IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na, dl_wr : std_logic := '0';
  SIGNAL dl_addr : uv16 := x"0000";
  SIGNAL dl_data : uv8 := x"00";
  SIGNAL pc : uv16;
  SIGNAL power_cycle : std_logic := '0';
  SIGNAL timing_reset_na : std_logic := '0';
  SIGNAL hpos : unsigned(7 DOWNTO 0);
  SIGNAL vpos : unsigned(8 DOWNTO 0);
  SIGNAL keys : std_logic_vector(35 DOWNTO 0) := (OTHERS => '0');
  SIGNAL fire : std_logic_vector(3 DOWNTO 0) := "0000";
BEGIN
  clk <= NOT clk AFTER 5 ns;

  -- Exercise the actual core wiring, including keyboard and Expander inputs.
  dut : ENTITY work.videobrain_core
    PORT MAP (
      clk => clk, reset_na => reset_na,
      power_cycle => power_cycle, timing_reset_na => timing_reset_na,
      kbd_matrix => keys, joy_fire => fire,
      joy_pots => (OTHERS => '0'), joy_timer_base => to_unsigned(2580, 14),
      joy_timer_step => to_unsigned(7, 7), joy_timer_curve => '0',
      audio_code => OPEN, audio_stb => OPEN, joy_enable => OPEN,
      expander_record_data => OPEN, expander_record_enable => OPEN,
      expander_playback_enable => OPEN, expander_modem_txd => OPEN,
      expander_printer_txd => OPEN,
      f8_po_a_n => OPEN, f8_po_b_n => OPEN, brclk_ena => OPEN,
      ce_pix => OPEN, vid_idx => OPEN, vid_r => OPEN, vid_g => OPEN,
      vid_b => OPEN, vid_de => OPEN, vid_hs => OPEN, vid_vs => OPEN,
      vid_hb => OPEN, vid_vb => OPEN, fifo_valid => OPEN, fifo_level => OPEN,
      hblank => OPEN, vblank => OPEN, burst => OPEN, csync => OPEN,
      scanline => OPEN, field => OPEN, hpos => hpos, vpos => vpos,
      final_mod => OPEN, background => OPEN, x_zoom => OPEN,
      y_zoom => OPEN, video_en => OPEN,
      dl_addr => dl_addr, dl_data => dl_data, dl_wr => dl_wr,
      dl_index => x"00", unknown_cart_profile => x"00",
      apl_available => OPEN, apl_load_error => OPEN,
      pc0 => pc, pc1 => OPEN, dc0 => OPEN
    );

  PROCESS
    VARIABLE old_hpos : unsigned(7 DOWNTO 0);
    PROCEDURE tick IS
    BEGIN
      WAIT UNTIL falling_edge(clk);
    END PROCEDURE;
  BEGIN
    power_cycle <= '1';
    FOR i IN 0 TO 7 LOOP tick; END LOOP;
    power_cycle <= '0'; reset_na <= '1';
    FOR i IN 0 TO 1022 LOOP
      tick;
      ASSERT pc = 0 REPORT "CPU ran before RAM clear completed" SEVERITY failure;
    END LOOP;
    FOR i IN 0 TO 3000 LOOP tick; END LOOP;
    ASSERT pc /= 0 REPORT "CPU did not restart after power cycle" SEVERITY failure;
    timing_reset_na <= '1';
    FOR i IN 0 TO 10 LOOP tick; END LOOP;
    old_hpos := hpos;
    reset_na <= '0';
    FOR i IN 0 TO 19 LOOP tick; END LOOP;
    ASSERT hpos = old_hpos + 5
      REPORT "Master Control stopped or reset video timing" SEVERITY failure;
    ASSERT pc = 0 REPORT "Master Control did not reset CPU" SEVERITY failure;
    FOR i IN 0 TO 2999 LOOP tick; END LOOP;
    ASSERT vpos /= 0 REPORT "Video timing stopped during Master Control" SEVERITY failure;
    reset_na <= '1';
    FOR i IN 0 TO 3000 LOOP tick; END LOOP;
    ASSERT pc /= 0 REPORT "CPU did not restart after Master Control" SEVERITY failure;
    REPORT "Core power-cycle hold and continuous Master Control timing passed";
    std.env.stop;
    WAIT;
  END PROCESS;
  PROCESS
  BEGIN
    WAIT FOR 1 ms;
    ASSERT false REPORT "Core power-cycle test timed out" SEVERITY failure;
  END PROCESS;
END ARCHITECTURE;
