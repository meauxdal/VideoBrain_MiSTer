LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.base_pack.ALL;

ENTITY tb_smi_clock IS END ENTITY;

ARCHITECTURE test OF tb_smi_clock IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na, dl_wr : std_logic := '0';
  SIGNAL dl_addr : uv16 := x"0000";
  SIGNAL dl_data : uv8 := x"00";
  SIGNAL pc : uv16;
  SIGNAL audio_stb : std_logic;
  SIGNAL keys : std_logic_vector(35 DOWNTO 0) := (OTHERS => '0');
  SIGNAL fire : std_logic_vector(3 DOWNTO 0) := "0000";
BEGIN
  clk <= NOT clk AFTER 5 ns;

  -- Exercise the actual timer wiring and CPU interrupt-to-DAC path.
  dut : ENTITY work.videobrain_core
    PORT MAP (
      clk => clk, reset_na => reset_na,
      kbd_matrix => keys, joy_fire => fire,
      joy_pots => (OTHERS => '0'), joy_timer_base => to_unsigned(2580, 14),
      joy_timer_step => to_unsigned(7, 7), joy_timer_curve => '0',
      audio_code => OPEN, audio_stb => audio_stb, joy_enable => OPEN,
      expander_record_data => OPEN, expander_record_enable => OPEN,
      expander_playback_enable => OPEN, expander_modem_txd => OPEN,
      expander_printer_txd => OPEN,
      f8_po_a_n => OPEN, f8_po_b_n => OPEN, brclk_ena => OPEN,
      ce_pix => OPEN, vid_idx => OPEN, vid_r => OPEN, vid_g => OPEN,
      vid_b => OPEN, vid_de => OPEN, vid_hs => OPEN, vid_vs => OPEN,
      vid_hb => OPEN, vid_vb => OPEN, fifo_valid => OPEN, fifo_level => OPEN,
      hblank => OPEN, vblank => OPEN, burst => OPEN, csync => OPEN,
      scanline => OPEN, field => OPEN, hpos => OPEN, vpos => OPEN,
      final_mod => OPEN, background => OPEN, x_zoom => OPEN,
      y_zoom => OPEN, video_en => OPEN,
      dl_addr => dl_addr, dl_data => dl_data, dl_wr => dl_wr,
      dl_index => x"00", unknown_cart_profile => x"00",
      apl_available => OPEN, apl_load_error => OPEN,
      pc0 => pc, pc1 => OPEN, dc0 => OPEN
    );

  PROCESS
    TYPE program_t IS ARRAY(natural RANGE <>) OF uv8;
    CONSTANT program : program_t(0 TO 71) := (
      0 => x"20", 1 => x"00", 2 => x"BC", -- Vector high.
      3 => x"20", 4 => x"40", 5 => x"BD", -- Timer vector $0040.
      6 => x"20", 7 => x"03", 8 => x"BE", -- Enable timer interrupts.
      9 => x"20", 10 => x"FE", 11 => x"BF", -- Full 255-count period.
      12 => x"1B", 13 => x"90", 14 => x"FF", -- EI; BR to itself.
      64 => x"20", 65 => x"10", 66 => x"B1", -- Physical I/O-14 low.
      67 => x"70", 68 => x"B1", -- Rising I/O-14 marks each IRQ at DAC.
      69 => x"1B", 70 => x"1C", -- EI; POP.
      OTHERS => x"2B"
    );
    VARIABLE previous_irq : time := 0 ns;
    VARIABLE interval : time;
    PROCEDURE tick IS
    BEGIN
      WAIT UNTIL rising_edge(clk);
      WAIT FOR 1 ns;
    END PROCEDURE;
  BEGIN
    dl_wr <= '1';
    FOR i IN program'range LOOP
      dl_addr <= to_unsigned(i, 16);
      dl_data <= program(i);
      tick;
    END LOOP;
    dl_wr <= '0';
    FOR i IN 1 TO 20 LOOP tick; END LOOP;
    reset_na <= '1';
    FOR interrupt_number IN 1 TO 3 LOOP
      WAIT UNTIL rising_edge(audio_stb) FOR 1 ms;
      ASSERT audio_stb = '1' REPORT "Timer interrupt timed out" SEVERITY failure;
      IF previous_irq /= 0 ns THEN
        interval := now - previous_irq;
        -- 255 * 31 PHI periods at 2 MHz. Test master clock is 10 ns,
        -- representing 1/14.318181 MHz: about 565.94 us in simulation.
        -- Allow instruction-boundary interrupt latency (one short cycle).
        ASSERT interval > 565 us AND interval < 567 us
          REPORT "F3853 must count full CPU PHI periods, interval=" & time'image(interval)
          SEVERITY failure;
      END IF;
      previous_irq := now;
    END LOOP;
    REPORT "Full-core F3853 PHI clock period test passed";
    std.env.stop;
    WAIT;
  END PROCESS;
END ARCHITECTURE;
