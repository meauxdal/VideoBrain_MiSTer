LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.base_pack.ALL;

ENTITY tb_cpu_ports IS END ENTITY;

ARCHITECTURE test OF tb_cpu_ports IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na, dl_wr : std_logic := '0';
  SIGNAL dl_addr : uv16 := x"0000";
  SIGNAL dl_data : uv8 := x"00";
  SIGNAL pc : uv16;
  SIGNAL keys : std_logic_vector(35 DOWNTO 0) := (OTHERS => '0');
  SIGNAL fire : std_logic_vector(3 DOWNTO 0) := "0000";
BEGIN
  clk <= NOT clk AFTER 5 ns;

  -- Exercise the actual core wiring, including keyboard and Expander inputs.
  dut : ENTITY work.videobrain_core
    PORT MAP (
      clk => clk, reset_na => reset_na,
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
    VARIABLE program : program_t(0 TO 18) := (
      x"20", x"01", x"B0", -- Select keyboard column 0 through port 0.
      x"20", x"00", x"B0", -- LI value; OUTS port
      x"A0",               -- INS port
      x"25", x"00",        -- CI expected
      x"94", x"07",        -- BF 4,fail (displacement relative to operand)
      x"29", x"00", x"0E", -- JMP pass
      x"90", x"FF", x"2B", -- pass: BR pass; NOP
      x"90", x"FF"         -- fail: BR fail
    );
    VARIABLE input_bits, expected : uv8;
    VARIABLE finished : boolean;
    VARIABLE cases : natural := 0;

    PROCEDURE tick IS
    BEGIN
      WAIT UNTIL rising_edge(clk);
      WAIT FOR 1 ns;
    END PROCEDURE;
  BEGIN
    FOR port_number IN 0 TO 1 LOOP
      FOR input_case IN 0 TO 3 LOOP
        EXIT WHEN port_number = 0 AND input_case > 0;
        keys <= (OTHERS => '0');
        fire <= "0000";
        input_bits := x"00";
        IF input_case = 1 OR input_case = 3 THEN
          fire <= "0101";
          input_bits := x"05";
        END IF;
        IF input_case = 2 OR input_case = 3 THEN
          keys(1) <= '1'; -- Selected column 0, row 1.
          keys(7) <= '1'; -- Unselected column 1 must not add row 3.
          input_bits := input_bits OR x"02";
        END IF;
        FOR value IN 0 TO 255 LOOP
          expected := to_unsigned(value, 8) OR input_bits;
          program(4) := to_unsigned(value, 8);
          program(5) := to_unsigned(16#B0# + port_number, 8);
          program(6) := to_unsigned(16#A0# + port_number, 8);
          program(8) := expected;
          reset_na <= '0';
          dl_wr <= '1';
          FOR i IN program'range LOOP
            dl_addr <= to_unsigned(i, 16);
            dl_data <= program(i);
            tick;
          END LOOP;
          dl_wr <= '0';
          FOR i IN 1 TO 20 LOOP tick; END LOOP;
          reset_na <= '1';
          finished := false;
          FOR i IN 1 TO 5000 LOOP
            tick;
            ASSERT pc /= 17
              REPORT "Port readback failed: port=" & integer'image(port_number) &
                " value=" & integer'image(value) & " inputs=" & integer'image(input_case)
              SEVERITY failure;
            IF pc = 14 THEN
              finished := true;
              EXIT;
            END IF;
          END LOOP;
          ASSERT finished REPORT "CPU port test timed out" SEVERITY failure;
          cases := cases + 1;
        END LOOP;
      END LOOP;
    END LOOP;
    REPORT "CPU port readback and external input tests passed: " & integer'image(cases) & " cases";
    std.env.stop;
    WAIT;
  END PROCESS;
END ARCHITECTURE;
