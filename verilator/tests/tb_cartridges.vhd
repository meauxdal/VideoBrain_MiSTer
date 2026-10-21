LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.base_pack.ALL;
USE work.uv202_pack.ALL;

ENTITY tb_cartridges IS
  GENERIC (apl_image : string := ""; info_image : string := "";
           apl_dump : string := ""; music_image : string := "");
END ENTITY;

ARCHITECTURE test OF tb_cartridges IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na : std_logic := '0';
  SIGNAL addr : unsigned(13 DOWNTO 0) := (OTHERS => '0');
  SIGNAL wr : std_logic := '0';
  SIGNAL wdata, rdata, bb_rdata : uv8;
  SIGNAL bb_addr : unsigned(12 DOWNTO 0) := (OTHERS => '0');
  SIGNAL dl_addr : unsigned(15 DOWNTO 0) := (OTHERS => '0');
  SIGNAL dl_data : uv8 := (OTHERS => '0');
  SIGNAL dl_wr : std_logic := '0';
  SIGNAL dl_index, fallback : uv8 := (OTHERS => '0');
  SIGNAL cart_unload : std_logic := '0';
  SIGNAL cart_loaded : std_logic;
  SIGNAL apl_hold, apl_error, apl_available : std_logic;
  SIGNAL apl_symbols : std_logic;
  SIGNAL fetch : std_logic := '0';
  SIGNAL apl_input_ready, apl_key_accepted : std_logic;
  SIGNAL apl_paused : std_logic := '0';
  SIGNAL joy_base : unsigned(13 DOWNTO 0);
  SIGNAL joy_step : unsigned(6 DOWNTO 0);
  SIGNAL background : uv8;
  SIGNAL command : std_logic_vector(7 DOWNTO 0);
  SIGNAL y_int, final_mod : uv8;
BEGIN
  clk <= NOT clk AFTER 5 ns;
  dut : ENTITY work.sys_bus
    PORT MAP (
      clk => clk, reset_na => reset_na,
      ext_addr => addr, ext_rd => '1', ext_wr => wr,
      ext_fetch => fetch,
      ext_wdata => wdata, ext_rdata => rdata,
      bb_addr => bb_addr, bb_rdata => bb_rdata,
      uv_cur_field => '0', uv_cur_vpos => (OTHERS => '0'),
      uv_capture_stb => '0', uv_capture_x => (OTHERS => '0'),
      uv_capture_y => (OTHERS => '0'),
      uv_o_x_zm => command(0), uv_o_frz => command(1), uv_o_enb => command(2),
      uv_o_int => command(3), uv_o_kbd => command(4), uv_o_y_zm => command(5),
      uv_o_a_b => command(6), uv_o_yint_ho => command(7), uv_y_int => y_int,
      uv_final_mod => final_mod, uv_background => background,
      uv_obj_addr => (OTHERS => '0'), uv_obj_rdata => OPEN,
      dl_addr => dl_addr, dl_data => dl_data, dl_wr => dl_wr,
      dl_index => dl_index, unknown_cart_profile => fallback,
      cart_unload => cart_unload, cart_loaded => cart_loaded,
      apl_hold => apl_hold, apl_paused => apl_paused,
      apl_available => apl_available, apl_load_error => apl_error,
      apl_symbols => apl_symbols,
      apl_input_ready => apl_input_ready, apl_key_accepted => apl_key_accepted,
      joy_linear_base => joy_base, joy_linear_step => joy_step
    );

  PROCESS
    TYPE binary_file IS FILE OF character;
    FILE image : binary_file;
    VARIABLE byte : character;
    VARIABLE n : natural;
    TYPE lut_t IS ARRAY (0 TO 3, 0 TO 3) OF natural;
    CONSTANT banks : lut_t := ((0, 1, 2, 0), (2, 1, 2, 1),
                              (0, 2, 2, 0), (2, 2, 2, 2));
    TYPE pair_t IS ARRAY (0 TO 2, 0 TO 1) OF natural;
    CONSTANT chips : pair_t := ((2, 3), (4, 6), (4, 5));

    PROCEDURE tick IS
    BEGIN
      WAIT UNTIL rising_edge(clk);
      WAIT FOR 1 ns;
    END PROCEDURE;

    PROCEDURE read_at(a, expected : natural) IS
    BEGIN
      addr <= to_unsigned(a, 14);
      tick;
      ASSERT rdata = to_unsigned(expected, 8)
        REPORT "CPU read mismatch at " & integer'image(a) SEVERITY failure;
    END PROCEDURE;

    PROCEDURE write_at(a, data : natural) IS
    BEGIN
      addr <= to_unsigned(a, 14);
      wdata <= to_unsigned(data, 8);
      wr <= '1';
      tick;
      wr <= '0';
      tick;
    END PROCEDURE;

    PROCEDURE dma_at(a, expected : natural) IS
    BEGIN
      bb_addr <= to_unsigned(a, 13);
      tick;
      ASSERT bb_rdata = to_unsigned(expected, 8)
        REPORT "DMA read mismatch at " & integer'image(a) SEVERITY failure;
    END PROCEDURE;

    PROCEDURE load_file(path : string) IS
    BEGIN
      file_open(image, path, read_mode);
      dl_index <= to_unsigned(2, 8);
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
      dl_index <= (OTHERS => '0');
      tick;
      tick;
    END PROCEDURE;

    -- Zero-filled images with CRC-matching suffixes; no cartridge ROM needed.
    PROCEDURE load_signature(size : positive; tail : uv32; step : natural;
                             base : natural := 2580) IS
    BEGIN
      dl_index <= to_unsigned(2, 8);
      dl_wr <= '1';
      FOR i IN 0 TO size - 1 LOOP
        dl_addr <= to_unsigned(i, 16);
        dl_data <= (OTHERS => '0');
        IF i >= size - 4 THEN
          dl_data <= tail((size - 1 - i) * 8 + 7 DOWNTO (size - 1 - i) * 8);
        END IF;
        tick;
        IF i = 0 THEN
          ASSERT joy_base = 2580 AND joy_step = 7
            REPORT "Joystick preset not cleared on replacement" SEVERITY failure;
        END IF;
      END LOOP;
      dl_wr <= '0';
      dl_index <= (OTHERS => '0');
      tick; tick;
      ASSERT joy_base = base AND joy_step = step
        REPORT "Joystick preset mismatch" SEVERITY failure;
    END PROCEDURE;

--     PROCEDURE load_dump(mode : natural) IS
--     BEGIN
--       file_open(image, apl_dump, read_mode);
--       dl_index <= to_unsigned(4, 8);
--       dl_wr <= '1';
--       n := 0;
--       WHILE NOT endfile(image) LOOP
--         read(image, byte);
--         EXIT WHEN mode = 1 AND n = 16383;
--         dl_addr <= to_unsigned(n, 16);
--         dl_data <= to_unsigned(character'pos(byte), 8);
--         IF (mode = 2 AND n = 16#1000#) OR
--            (mode = 3 AND n = 16#2C00#) THEN
--           dl_data <= to_unsigned(character'pos(byte), 8) XOR x"01";
--         END IF;
--         IF mode = 4 AND n = 2 THEN dl_addr <= x"0001"; END IF;
--         tick;
--         n := n + 1;
--       END LOOP;
--       file_close(image);
--       IF mode = 5 THEN
--         dl_addr <= x"4000"; tick;
--       END IF;
--       dl_wr <= '0';
--       dl_index <= x"FF";
--       tick;
--       tick;
--     END PROCEDURE;
  BEGIN
    tick;
    ASSERT cart_loaded = '0' REPORT "Cartridge present at power-on" SEVERITY failure;
    read_at(16#1000#, 255); dma_at(16#1800#, 255);
    dl_addr <= x"0000"; dl_data <= x"A6"; dl_index <= x"00"; dl_wr <= '1'; tick;
    dl_data <= x"5A"; dl_index <= x"01"; tick;
    dl_wr <= '0'; dl_index <= x"FF"; tick;
    -- Give each chip a distinct value to expose bank/address aliasing.
    dl_index <= to_unsigned(2, 8);
    dl_wr <= '1';
    FOR i IN 0 TO 16383 LOOP
      dl_addr <= to_unsigned(i, 16);
      dl_data <= to_unsigned(i / 2048 + 16, 8);
      tick;
    END LOOP;
    dl_wr <= '0';
    dl_index <= (OTHERS => '0');
    reset_na <= '1';
    fallback <= to_unsigned(CART_COMPLANG, 8);
    tick;
    tick;
    fetch <= '1'; addr <= to_unsigned(16#3C14#, 14); tick;
    ASSERT apl_input_ready = '0' AND apl_key_accepted = '0'
      REPORT "Unrecognized ROM enabled input handshake" SEVERITY failure;
    addr <= to_unsigned(16#3C20#, 14); tick;
    ASSERT apl_key_accepted = '0'
      REPORT "Unrecognized ROM accepted key" SEVERITY failure;
    addr <= to_unsigned(16#14D8#, 14); tick;
    ASSERT apl_input_ready = '0' REPORT "Unrecognized ROM enabled music readiness" SEVERITY failure;
    addr <= to_unsigned(16#14E4#, 14); tick;
    ASSERT apl_key_accepted = '0' REPORT "Unrecognized ROM accepted music key" SEVERITY failure;
    addr <= to_unsigned(16#158F#, 14); tick;
    ASSERT apl_input_ready = '0' REPORT "Unrecognized ROM enabled live music input" SEVERITY failure;
    addr <= to_unsigned(16#1154#, 14); tick;
    ASSERT apl_key_accepted = '0' REPORT "Unrecognized ROM accepted music bank" SEVERITY failure;
    fetch <= '0';
    read_at(16#1000#, 16);
    read_at(16#1BFF#, 17);
    FOR data IN 0 TO 3 LOOP
      FOR a IN 0 TO 3 LOOP
        write_at(16#1000# + a, data);
        read_at(16#3000#, 16 + chips(banks(data, a), 0));
        read_at(16#3FFF#, 16 + chips(banks(data, a), 1));
      END LOOP;
    END LOOP;
    write_at(16#1C00#, 16#A5#);
    read_at(16#1C00#, 16#A5#);
    dma_at(16#1C00#, 16#A5#);
    dma_at(16#1000#, 16);
    reset_na <= '0'; tick; reset_na <= '1'; tick;
    -- MASTER CONTROL resets the machine without resetting cartridge state.
    read_at(16#3000#, 20);
    read_at(16#3800#, 21);
    read_at(16#1C00#, 16#A5#);

    fallback <= to_unsigned(CART_INFOMAN, 8); tick;
    read_at(16#1000#, 16);
    read_at(16#3000#, 18);
    read_at(16#3800#, 19);
    write_at(16#1800#, 16#5A#);
    read_at(16#1C00#, 16#5A#);
    dma_at(16#1800#, 16#5A#);
    dma_at(16#1C00#, 16#5A#);

    fallback <= to_unsigned(CART_TIMESHARE, 8); tick;
    read_at(16#1000#, 16); read_at(16#1800#, 16#5A#);
    read_at(16#3000#, 255);
    fallback <= to_unsigned(CART_MONEYMINDER, 8); tick;
    read_at(16#1800#, 17); read_at(16#3800#, 16#5A#);
    fallback <= to_unsigned(CART_STD, 8); tick;
    read_at(16#1800#, 17); read_at(16#3800#, 255);

    -- The retired download index must not alter RAM or pause the CPU.
    write_at(16#0FE2#, 16#A5#);
    dl_index <= to_unsigned(4, 8); dl_wr <= '1';
    dl_addr <= x"0FE2"; dl_data <= x"00"; tick;
    dl_wr <= '0'; dl_index <= x"FF"; tick; tick;
    read_at(16#0FE2#, 16#A5#);
    ASSERT apl_hold = '0' AND apl_error = '0'
      REPORT "Retired dump index is active" SEVERITY failure;

    IF apl_image /= "" THEN
      load_file(apl_image);
      -- Data reads and other banks must not impersonate the input routine.
      addr <= to_unsigned(16#3C14#, 14); tick;
      ASSERT apl_input_ready = '0' REPORT "Data read signalled ready" SEVERITY failure;
      FOR bank IN 1 TO 2 LOOP
        write_at(16#1000# + bank, 0);
        fetch <= '1'; addr <= to_unsigned(16#3C14#, 14); tick;
        ASSERT apl_input_ready = '0' REPORT "Wrong bank signalled ready" SEVERITY failure;
        addr <= to_unsigned(16#3C20#, 14); tick;
        ASSERT apl_key_accepted = '0' REPORT "Wrong bank accepted key" SEVERITY failure;
        fetch <= '0';
      END LOOP;
      write_at(16#1000#, 0);
      read_at(16#3C14#, 16#28#);
      read_at(16#3C20#, 16#13#);
      fetch <= '1'; addr <= to_unsigned(16#3C14#, 14); tick;
      ASSERT apl_input_ready = '1' REPORT "Input loop not ready" SEVERITY failure;
      fetch <= '0'; addr <= to_unsigned(16#3C20#, 14); tick;
      ASSERT apl_input_ready = '1' AND apl_key_accepted = '0'
        REPORT "Data read accepted key" SEVERITY failure;
      fetch <= '1'; tick;
      ASSERT apl_input_ready = '0' AND apl_key_accepted = '1'
        REPORT "Input loop did not accept key" SEVERITY failure;
      addr <= to_unsigned(16#3C14#, 14); tick;
      ASSERT apl_input_ready = '1' REPORT "Input did not resume" SEVERITY failure;
      fetch <= '0'; reset_na <= '0'; tick; reset_na <= '1'; tick;
      ASSERT apl_input_ready = '0' REPORT "Reset retained readiness" SEVERITY failure;
      read_at(16#1000#, 16#AA#);
      read_at(16#3000#, 16#08#);
      write_at(16#1001#, 0);
      read_at(16#3000#, 16#15#);
--       IF apl_dump /= "" THEN
--         write_at(16#0FE2#, 1);
--         ASSERT apl_symbols = '1' REPORT "APL symbol mode not observed" SEVERITY failure;
--         write_at(16#2FE2#, 0);
--         ASSERT apl_symbols = '0' REPORT "APL mirrored symbol mode not observed" SEVERITY failure;
--         write_at(ADDR_UV201_LO + REG_Y_INTERRUPT, 16#B0#);
--         write_at(ADDR_UV201_LO + REG_FINAL_MOD, 16#03#);
--         write_at(ADDR_UV201_LO + REG_BACKGROUND, 16#12#);
--         write_at(ADDR_UV201_LO + REG_COMMAND, 16#4C#);
--         write_at(16#0C00#, 16#A5#);
--         write_at(16#1C00#, 16#5A#);
--         FOR mode IN 1 TO 5 LOOP
--           load_dump(mode);
--           ASSERT apl_error = '1' AND apl_hold = '0'
--             REPORT "Invalid APL dump accepted" SEVERITY failure;
--           read_at(16#0C00#, 16#A5#);
--           read_at(16#1C00#, 16#5A#);
--         END LOOP;
--         load_dump(0);
--         ASSERT apl_available = '1' AND apl_hold = '1' AND apl_error = '0'
--           REPORT "Valid APL dump rejected" SEVERITY failure;
--         read_at(16#0C00#, 16#A5#);
--         read_at(16#1C00#, 16#5A#);
--         apl_paused <= '1';
--         FOR i IN 0 TO 32772 LOOP
--           tick;
--           ASSERT y_int = x"B0" AND final_mod = x"03" AND
--                  background = x"12" AND command = x"4C"
--             REPORT "APL load changed write-only video controls" SEVERITY failure;
--         END LOOP;
--         ASSERT apl_hold = '0' REPORT "APL copy did not finish" SEVERITY failure;
--         apl_paused <= '0';
--         file_open(image, apl_dump, read_mode);
--         FOR i IN 0 TO 16383 LOOP
--           read(image, byte);
--           IF (i >= 16#0C00# AND i <= 16#0FFF#) OR
--              (i >= 16#1C00# AND i <= 16#1FFF#) OR
--              (i >= 16#2B00# AND i <= 16#2B8F#) THEN
--             read_at(i, character'pos(byte));
--           END IF;
--         END LOOP;
--         file_close(image);
--         read_at(16#1000#, 16#AA#);
--         read_at(16#3000#, 16#15#);
--         -- Reset cancels a validated transfer waiting for the CPU.
--         load_dump(0);
--         reset_na <= '0'; tick; reset_na <= '1'; tick;
--         ASSERT apl_hold = '0' REPORT "Reset did not cancel APL load" SEVERITY failure;
--       END IF;
--     END IF;
      write_at(16#0FE2#, 1);
      ASSERT apl_symbols = '1' REPORT "APL symbol mode not observed" SEVERITY failure;
      write_at(16#2FE2#, 0);
      ASSERT apl_symbols = '0' REPORT "APL mirrored symbol mode not observed" SEVERITY failure;
    END IF;
    IF info_image /= "" THEN
      load_file(info_image);
      write_at(16#1800#, 16#C3#);
      read_at(16#1C00#, 16#C3#);
      read_at(16#3000#, 16#14#);
    END IF;
    -- Replacing a recognized cartridge must clear its mapper and size.
    dl_index <= to_unsigned(2, 8);
    dl_wr <= '1';
    FOR i IN 0 TO 2047 LOOP
      dl_addr <= to_unsigned(i, 16);
      dl_data <= to_unsigned(16#6D#, 8);
      tick;
    END LOOP;
    dl_wr <= '0';
    dl_index <= (OTHERS => '0');
    tick; tick;
    read_at(16#1000#, 16#6D#);
    read_at(16#1800#, 16#6D#);
    dma_at(16#1C00#, 16#6D#);
    read_at(16#3000#, 255);
--     IF apl_dump /= "" THEN
--       write_at(16#0C00#, 16#A5#);
--       load_dump(0);
--       ASSERT apl_available = '0' AND apl_error = '1' AND apl_hold = '0'
--         REPORT "APL dump accepted without interpreter cartridge" SEVERITY failure;
--       read_at(16#0C00#, 16#A5#);
--     END IF;
    load_signature(4096, x"78F61A44", 24, 2644); -- Tennis CRC 1942F852.
    reset_na <= '0'; tick; reset_na <= '1'; tick;
    ASSERT joy_base = 2644 AND joy_step = 24
      REPORT "Reset cleared joystick preset" SEVERITY failure;
    fallback <= to_unsigned(CART_TIMESHARE, 8); tick;
    ASSERT joy_base = 2644 AND joy_step = 24
      REPORT "Mapper fallback changed joystick preset" SEVERITY failure;
    load_signature(4096, x"BB09D7FB", 7); -- Gladiator CRC E6A88A49.
    load_signature(4096, x"78F61A44", 24, 2644);
    load_signature(2048, x"23469D84", 7); -- Tennis CRC, wrong length.
    load_signature(4096, x"78F61A45", 7); -- Altered Tennis fingerprint.
    load_signature(4096, x"78F61A44", 24, 2644);
    ASSERT cart_loaded = '1' REPORT "Loaded cartridge absent" SEVERITY failure;
    write_at(16#0C00#, 16#A5#);
    cart_unload <= '1'; reset_na <= '0'; tick;
    cart_unload <= '0'; reset_na <= '1'; tick; tick;
    ASSERT cart_loaded = '0' AND apl_available = '0' AND
           joy_base = 2580 AND joy_step = 7
      REPORT "Unload retained cartridge state" SEVERITY failure;
    FOR mapper IN CART_STD TO CART_INFOMAN LOOP
      fallback <= to_unsigned(mapper, 8); tick;
      read_at(16#1000#, 255); read_at(16#1800#, 255);
      read_at(16#3000#, 255); read_at(16#3800#, 255);
      dma_at(16#1000#, 255); dma_at(16#1800#, 255);
    END LOOP;
    read_at(16#0C00#, 16#A5#);
    read_at(16#0000#, 16#A6#); read_at(16#2000#, 16#5A#);
    dma_at(16#0000#, 16#5A#);
    reset_na <= '0'; tick; reset_na <= '1'; tick;
    ASSERT cart_loaded = '0' REPORT "Reset restored unloaded cartridge" SEVERITY failure;
    load_signature(4096, x"BB09D7FB", 7);
    ASSERT cart_loaded = '1' REPORT "Replacement cartridge absent" SEVERITY failure;
    IF music_image /= "" THEN
      load_file(music_image);
      read_at(16#158F#, 16#18#);
      read_at(16#1154#, 16#72#);
      addr <= to_unsigned(16#14D8#, 14); tick;
      ASSERT apl_input_ready = '0' REPORT "Music data read signalled ready" SEVERITY failure;
      fetch <= '1'; tick;
      ASSERT apl_input_ready = '1' REPORT "Music release not detected" SEVERITY failure;
      fetch <= '0'; addr <= to_unsigned(16#14E4#, 14); tick;
      ASSERT apl_input_ready = '1' AND apl_key_accepted = '0'
        REPORT "Music data read accepted key" SEVERITY failure;
      fetch <= '1'; tick;
      ASSERT apl_input_ready = '0' AND apl_key_accepted = '0'
        REPORT "Music key acknowledged before bank selection" SEVERITY failure;
      addr <= to_unsigned(16#1154#, 14); tick;
      ASSERT apl_input_ready = '0' AND apl_key_accepted = '1'
        REPORT "Music bank selection not detected" SEVERITY failure;
      addr <= to_unsigned(16#34D8#, 14); tick;
      ASSERT apl_input_ready = '0' REPORT "Music alias signalled ready" SEVERITY failure;
      addr <= to_unsigned(16#3154#, 14); tick;
      ASSERT apl_key_accepted = '0' REPORT "Music alias accepted key" SEVERITY failure;
      addr <= to_unsigned(16#14D8#, 14); tick;
      ASSERT apl_input_ready = '1' REPORT "Music input did not resume" SEVERITY failure;
      addr <= to_unsigned(16#14C8#, 14); tick;
      ASSERT apl_input_ready = '0' REPORT "Music entry retained readiness" SEVERITY failure;
      -- Live playing accepts the next key without the idle input routine.
      addr <= to_unsigned(16#158F#, 14); tick;
      ASSERT apl_input_ready = '1' REPORT "Live note release not detected" SEVERITY failure;
      addr <= to_unsigned(16#10A1#, 14); tick;
      ASSERT apl_input_ready = '0' REPORT "Live note acceptance retained readiness" SEVERITY failure;
      addr <= to_unsigned(16#158F#, 14); tick;
      ASSERT apl_input_ready = '1' REPORT "Live bank input not ready" SEVERITY failure;
      fetch <= '0'; addr <= to_unsigned(16#1154#, 14); tick;
      ASSERT apl_input_ready = '1' AND apl_key_accepted = '0'
        REPORT "Music bank data read accepted key" SEVERITY failure;
      fetch <= '1'; tick;
      ASSERT apl_input_ready = '0' AND apl_key_accepted = '1'
        REPORT "Live bank selection not detected" SEVERITY failure;
      addr <= to_unsigned(16#14D8#, 14); tick;
      ASSERT apl_input_ready = '1' REPORT "Live bank release not detected" SEVERITY failure;
      addr <= to_unsigned(16#14D8#, 14); tick;
      fetch <= '0'; reset_na <= '0'; tick; reset_na <= '1'; tick;
      ASSERT apl_input_ready = '0' REPORT "Music reset retained readiness" SEVERITY failure;
      fetch <= '1'; tick;
      cart_unload <= '1'; tick; cart_unload <= '0'; tick;
      ASSERT apl_input_ready = '0' AND apl_key_accepted = '0'
        REPORT "Music unload retained readiness" SEVERITY failure;
      fetch <= '0';
    END IF;
    REPORT "Cartridge tests passed";
    std.env.stop;
    WAIT;
  END PROCESS;
END ARCHITECTURE;
