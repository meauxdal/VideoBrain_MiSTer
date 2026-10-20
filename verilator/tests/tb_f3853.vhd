LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.env.ALL;

LIBRARY work;
USE work.base_pack.ALL;

ENTITY tb_f3853 IS
END ENTITY;

ARCHITECTURE test OF tb_f3853 IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na, io_wr, int_ack : std_logic := '0';
  SIGNAL io_addr, io_wdata, io_rdata : uv8 := x"00";
  SIGNAL irq, request, selected : std_logic;
  SIGNAL vector : uv16;
  SIGNAL current_y : unsigned(8 DOWNTO 0) := to_unsigned(255, 9);
  SIGNAL target_y : uv8 := x"00";
  SIGNAL target_hi : std_logic := '1';
BEGIN
  clk <= NOT clk AFTER 5 ns;

  yint : ENTITY work.uv201_yint
    PORT MAP (
      clk => clk, reset_na => reset_na, cur_vpos => current_y,
      y_int => target_y, yint_ho => target_hi, cmd_int => '1',
      cmd_frz => '0', irq_level => irq);

  dut : ENTITY work.f3853
    PORT MAP (
      clk => clk, reset_na => reset_na, ce => '0',
      io_addr => io_addr, io_rd => '0', io_wr => io_wr,
      io_wdata => io_wdata, io_rdata => io_rdata, io_sel => selected,
      ext_int => irq, int_req => request, int_vector => vector,
      int_ack => int_ack);

  PROCESS
    PROCEDURE tick IS
    BEGIN
      WAIT UNTIL rising_edge(clk);
      WAIT FOR 1 ns;
    END PROCEDURE;

    PROCEDURE settle IS
    BEGIN
      tick;
      tick;
      tick;
    END PROCEDURE;

    PROCEDURE write_port(address_v, data_v : uv8) IS
    BEGIN
      io_addr <= address_v;
      io_wdata <= data_v;
      io_wr <= '1';
      tick;
      io_wr <= '0';
      tick;
    END PROCEDURE;
  BEGIN
    tick;
    reset_na <= '1';
    write_port(x"0C", x"46");
    write_port(x"0D", x"F7");
    write_port(x"0E", x"01");
    ASSERT vector = x"46F7" REPORT "External vector changed" SEVERITY failure;

    current_y <= to_unsigned(256, 9);
    settle;
    ASSERT request = '1' REPORT "Missing Y256 request" SEVERITY failure;
    int_ack <= '1';
    tick;
    int_ack <= '0';
    settle;
    ASSERT request = '0' REPORT "Held Y match retriggered after acknowledge" SEVERITY failure;

    -- BIOS writes the low Y byte before the high bit at the field boundary.
    current_y <= to_unsigned(257, 9);
    settle;
    target_y <= x"02";
    current_y <= to_unsigned(258, 9);
    settle;
    ASSERT request = '1' REPORT "Missing intermediate Y258 request" SEVERITY failure;
    target_hi <= '0';
    current_y <= to_unsigned(259, 9);
    settle;
    ASSERT irq = '0' AND request = '1' REPORT "Request did not latch" SEVERITY failure;

    -- MK3853 interrupt-control writes clear pending external requests.
    write_port(x"0E", x"01");
    ASSERT request = '0' REPORT "Rearm retained intermediate Y request" SEVERITY failure;
    current_y <= to_unsigned(0, 9);
    settle;
    ASSERT request = '0' REPORT "Premature sound interrupt at field start" SEVERITY failure;
    current_y <= to_unsigned(2, 9);
    settle;
    ASSERT request = '1' REPORT "Rearm lost the next Y2 request" SEVERITY failure;

    write_port(x"0E", x"00");
    ASSERT request = '0' REPORT "Disable retained external request" SEVERITY failure;
    write_port(x"0E", x"01");
    settle;
    ASSERT request = '0' REPORT "Rearm retriggered a held input" SEVERITY failure;
    current_y <= to_unsigned(3, 9);
    settle;
    current_y <= to_unsigned(2, 9);
    settle;
    ASSERT request = '1' REPORT "Fresh edge after rearm was lost" SEVERITY failure;

    REPORT "3853 external interrupt rearm test passed";
    stop;
    WAIT;
  END PROCESS;
END ARCHITECTURE;
