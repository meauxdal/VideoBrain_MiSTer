LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.base_pack.ALL;

ENTITY tb_apl_loader IS
  GENERIC (
    cart_path : string := "../software/converted/The Computational Language (APL-S).bin";
    dump_path : string := "../software/21 games for apl_s/guess.bin"
  );
END ENTITY;

ARCHITECTURE test OF tb_apl_loader IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na, dl_wr : std_logic := '0';
  SIGNAL dl_addr : unsigned(15 DOWNTO 0) := (OTHERS => '0');
  SIGNAL dl_data, dl_index : uv8 := (OTHERS => '0');
  SIGNAL pc : uv16;
  SIGNAL video_x : unsigned(7 DOWNTO 0);
  SIGNAL available, load_error : std_logic;
BEGIN
  clk <= NOT clk AFTER 5 ns;
  dut : ENTITY work.videobrain_core
    PORT MAP (
      clk => clk, reset_na => reset_na,
      kbd_matrix => (OTHERS => '0'), joy_fire => (OTHERS => '0'),
      joy_pots => (OTHERS => '0'), joy_timer_base => to_unsigned(2580, 14),
      joy_timer_step => to_unsigned(7, 7), joy_timer_curve => '0',
      audio_code => OPEN, audio_stb => OPEN, joy_enable => OPEN,
      f8_po_a_n => OPEN, f8_po_b_n => OPEN, brclk_ena => OPEN,
      ce_pix => OPEN, vid_idx => OPEN, vid_r => OPEN, vid_g => OPEN,
      vid_b => OPEN, vid_de => OPEN, vid_hs => OPEN, vid_vs => OPEN,
      vid_hb => OPEN, vid_vb => OPEN, fifo_valid => OPEN, fifo_level => OPEN,
      hblank => OPEN, vblank => OPEN, burst => OPEN, csync => OPEN,
      scanline => OPEN, field => OPEN, hpos => video_x, vpos => OPEN,
      final_mod => OPEN, background => OPEN, x_zoom => OPEN,
      y_zoom => OPEN, video_en => OPEN,
      dl_addr => dl_addr, dl_data => dl_data, dl_wr => dl_wr,
      dl_index => dl_index, unknown_cart_profile => x"00",
      apl_available => available, apl_load_error => load_error,
      pc0 => pc, pc1 => OPEN, dc0 => OPEN
    );

  PROCESS
    TYPE binary_file IS FILE OF character;
    FILE image : binary_file;
    VARIABLE byte : character;
    VARIABLE n : natural;
    VARIABLE saved_pc : uv16;
    VARIABLE saved_x : unsigned(7 DOWNTO 0);
    VARIABLE moved : boolean;
    TYPE program_t IS ARRAY (natural RANGE <>) OF uv8;
    CONSTANT program : program_t :=
      (x"2A", x"0C", x"00", x"20", x"A5", x"17", x"29", x"00", x"00");

    PROCEDURE tick IS
    BEGIN
      WAIT UNTIL rising_edge(clk);
      WAIT FOR 1 ns;
    END PROCEDURE;

    PROCEDURE load_file(path : string; index : natural) IS
    BEGIN
      file_open(image, path, read_mode);
      dl_index <= to_unsigned(index, 8);
      dl_wr <= '1';
      n := 0;
      WHILE NOT endfile(image) LOOP
        read(image, byte);
        dl_addr <= to_unsigned(n, 16);
        dl_data <= to_unsigned(character'pos(byte), 8);
        tick;
        n := n + 1;
      END LOOP;
      file_close(image);
      dl_wr <= '0';
      dl_index <= x"FF";
      tick; tick;
    END PROCEDURE;
  BEGIN
    -- Repeated system RAM stores exercise the arbiter's pending-write path.
    dl_index <= x"00";
    dl_wr <= '1';
    dl_data <= x"70";
    FOR i IN 0 TO 2047 LOOP
      dl_addr <= to_unsigned(i, 16); tick;
    END LOOP;
    FOR i IN program'RANGE LOOP
      dl_addr <= to_unsigned(i, 16);
      dl_data <= program(i); tick;
    END LOOP;
    dl_wr <= '0'; tick;
    load_file(cart_path, 2);
    reset_na <= '1';
    FOR i IN 0 TO 100 LOOP tick; END LOOP;
    ASSERT available = '1' REPORT "APL cartridge not recognized" SEVERITY failure;
    load_file(dump_path, 4);
    -- Allow the current ROMC cycle to drain before checking the copy interval.
    FOR i IN 0 TO 100 LOOP tick; END LOOP;
    saved_pc := pc;
    saved_x := video_x;
    moved := false;
    FOR i IN 0 TO 3900 LOOP
      tick;
      ASSERT pc = saved_pc REPORT "CPU advanced during APL copy" SEVERITY failure;
      IF video_x /= saved_x THEN moved := true; END IF;
    END LOOP;
    ASSERT moved REPORT "Video timing stopped during APL copy" SEVERITY failure;
    moved := false;
    FOR i IN 0 TO 500 LOOP
      tick;
      IF pc /= saved_pc THEN moved := true; END IF;
    END LOOP;
    ASSERT moved AND load_error = '0' AND available = '1'
      REPORT "CPU did not resume after APL copy" SEVERITY failure;
    REPORT "APL loader CPU pause test passed";
    std.env.stop;
    WAIT;
  END PROCESS;
END ARCHITECTURE;
