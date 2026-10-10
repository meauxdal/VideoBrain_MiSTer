LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.base_pack.ALL;
USE work.uv202_pack.ALL;

ENTITY tb_cartridges IS
  GENERIC (apl_image : string := ""; info_image : string := "");
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
BEGIN
  clk <= NOT clk AFTER 5 ns;
  dut : ENTITY work.sys_bus
    PORT MAP (
      clk => clk, reset_na => reset_na,
      ext_addr => addr, ext_rd => '1', ext_wr => wr,
      ext_wdata => wdata, ext_rdata => rdata,
      bb_addr => bb_addr, bb_rdata => bb_rdata,
      uv_cur_field => '0', uv_cur_vpos => (OTHERS => '0'),
      uv_capture_stb => '0', uv_capture_x => (OTHERS => '0'),
      uv_capture_y => (OTHERS => '0'),
      uv_o_x_zm => OPEN, uv_o_frz => OPEN, uv_o_enb => OPEN,
      uv_o_int => OPEN, uv_o_kbd => OPEN, uv_o_y_zm => OPEN,
      uv_o_a_b => OPEN, uv_o_yint_ho => OPEN, uv_y_int => OPEN,
      uv_final_mod => OPEN, uv_background => OPEN,
      uv_obj_addr => (OTHERS => '0'), uv_obj_rdata => OPEN,
      dl_addr => dl_addr, dl_data => dl_data, dl_wr => dl_wr,
      dl_index => dl_index, unknown_cart_profile => fallback
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
  BEGIN
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

    IF apl_image /= "" THEN
      load_file(apl_image);
      read_at(16#1000#, 16#AA#);
      read_at(16#3000#, 16#08#);
      write_at(16#1001#, 0);
      read_at(16#3000#, 16#15#);
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
    REPORT "Cartridge tests passed";
    std.env.stop;
    WAIT;
  END PROCESS;
END ARCHITECTURE;
