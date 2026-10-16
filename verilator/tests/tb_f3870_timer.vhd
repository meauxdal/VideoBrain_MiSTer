LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.env.ALL;
LIBRARY work;
USE work.base_pack.ALL;

ENTITY tb_f3870_timer IS END ENTITY;
ARCHITECTURE test OF tb_f3870_timer IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na, ce_phi, io_wr, int_start, int_ack : std_logic := '0';
  SIGNAL ext_int : std_logic := '1';
  SIGNAL io_addr, io_wdata, io_rdata : uv8 := x"00";
  SIGNAL int_req : std_logic;
  SIGNAL int_vector : uv16;
BEGIN
  clk <= NOT clk AFTER 5 ns;
  dut : ENTITY work.f3870_timer
    PORT MAP (
      clk => clk, reset_na => reset_na, ce_phi => ce_phi,
      io_addr => io_addr, io_wr => io_wr, io_wdata => io_wdata,
      io_rdata => io_rdata, ext_int => ext_int, int_req => int_req,
      int_vector => int_vector, int_start => int_start, int_ack => int_ack
      );

  PROCESS IS
    TYPE divisors_t IS ARRAY (1 TO 7) OF positive;
    CONSTANT DIVISORS : divisors_t := (2, 5, 10, 20, 40, 100, 200);
    PROCEDURE step(phi : std_logic := '0'; n : positive := 1) IS
    BEGIN
      FOR i IN 1 TO n LOOP
        WAIT UNTIL falling_edge(clk);
        ce_phi <= phi;
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ce_phi <= '0';
      END LOOP;
    END PROCEDURE;
    PROCEDURE restart IS
    BEGIN
      reset_na <= '0';
      step;
      reset_na <= '1';
      step;
    END PROCEDURE;
    PROCEDURE put(port_number, value : natural) IS
    BEGIN
      io_addr <= to_unsigned(port_number, 8);
      io_wdata <= to_unsigned(value, 8);
      io_wr <= '1';
      step;
      io_wr <= '0';
    END PROCEDURE;
    PROCEDURE expect_count(value : natural) IS
    BEGIN
      io_addr <= x"07";
      WAIT FOR 1 ns;
      ASSERT io_rdata = value REPORT "Incorrect timer count" SEVERITY failure;
    END PROCEDURE;
    PROCEDURE pin(value : std_logic) IS
    BEGIN
      ext_int <= value;
      step;
    END PROCEDURE;
    PROCEDURE select_irq(vector : uv16) IS
    BEGIN
      int_start <= '1';
      step;
      int_start <= '0';
      ASSERT int_vector = vector REPORT "Incorrect interrupt vector" SEVERITY failure;
    END PROCEDURE;
    PROCEDURE acknowledge IS
    BEGIN
      int_ack <= '1';
      step;
      int_ack <= '0';
    END PROCEDURE;
  BEGIN
    restart;
    expect_count(0);
    ASSERT int_req = '0' REPORT "Reset left interrupt pending" SEVERITY failure;

    -- Each interval must last N complete prescaled phi periods.
    FOR mask IN 1 TO 7 LOOP
      restart;
      put(7, 3);
      put(6, mask * 32 + 10);
      step('0', 5);
      expect_count(3);
      step('1', 3 * DIVISORS(mask) - 1);
      expect_count(1);
      ASSERT int_req = '0' REPORT "Timer expired early" SEVERITY failure;
      step('1');
      expect_count(3);
      ASSERT int_req = '1' REPORT "Timer did not expire" SEVERITY failure;
      select_irq(x"0020");
      acknowledge;
      ASSERT int_req = '0' REPORT "Timer acknowledge failed" SEVERITY failure;
      step('1', 3 * DIVISORS(mask));
      ASSERT int_req = '1' REPORT "Timer did not repeat" SEVERITY failure;
    END LOOP;

    restart;
    put(7, 0);
    put(6, 42); -- /2, run, timer interrupt enable.
    step('1', 511);
    expect_count(1);
    ASSERT int_req = '0' REPORT "Modulo zero expired before 256 counts" SEVERITY failure;
    step('1');
    expect_count(0);
    ASSERT int_req = '1' REPORT "Modulo zero did not expire" SEVERITY failure;
    put(7, 1);
    ASSERT int_req = '0' REPORT "Timer reload did not clear request" SEVERITY failure;
    step('1', 2);
    expect_count(1);
    ASSERT int_req = '1' REPORT "Modulo one did not expire" SEVERITY failure;

    -- Stop retains the count, discards the partial prescale, and masks the IRQ.
    restart;
    put(7, 3);
    put(6, 74); -- /5.
    step('1', 7);
    expect_count(2);
    put(6, 64);
    step('1', 20);
    expect_count(2);
    put(6, 72);
    step('1', 4);
    expect_count(2);
    step('1', 6);
    expect_count(3);
    ASSERT int_req = '0' REPORT "Masked timer request escaped" SEVERITY failure;
    put(6, 66);
    ASSERT int_req = '1' REPORT "Masked timer request was lost" SEVERITY failure;
    put(6, 64);
    ASSERT int_req = '0' REPORT "Timer mask failed" SEVERITY failure;
    put(6, 66);
    ASSERT int_req = '1' REPORT "Timer mask cleared pending latch" SEVERITY failure;
    put(7, 4);
    ASSERT int_req = '0' REPORT "Port 7 did not clear pending latch" SEVERITY failure;

    -- Port 6 reports the pin level, regardless of programmed polarity.
    restart;
    put(6, 255);
    io_addr <= x"06";
    WAIT FOR 1 ns;
    ASSERT io_rdata = x"80" REPORT "Port 6 returned control bits" SEVERITY failure;
    pin('0');
    ASSERT io_rdata = x"00" REPORT "Port 6 did not read low pin" SEVERITY failure;

    -- External requests latch only while enabled and clear when disabled.
    restart;
    pin('1');
    pin('0');
    put(6, 1);
    ASSERT int_req = '0' REPORT "Disabled edge was latched" SEVERITY failure;
    pin('1');
    ASSERT int_req = '0' REPORT "Wrong active-low edge" SEVERITY failure;
    pin('0');
    ASSERT int_req = '1' REPORT "Active-low edge was lost" SEVERITY failure;
    select_irq(x"00A0");
    acknowledge;
    ASSERT int_req = '0' REPORT "External acknowledge failed" SEVERITY failure;
    step('0', 4);
    ASSERT int_req = '0' REPORT "External input was level triggered" SEVERITY failure;
    put(6, 5);
    pin('1');
    ASSERT int_req = '1' REPORT "Active-high edge was lost" SEVERITY failure;
    put(6, 4);
    put(6, 5);
    ASSERT int_req = '0' REPORT "External disable did not clear latch" SEVERITY failure;

    -- Event mode counts leading edges and gives timer requests priority.
    restart;
    pin('1');
    put(7, 2);
    put(6, 11);
    step('1', 20);
    expect_count(2);
    pin('0');
    expect_count(1);
    pin('1');
    expect_count(1);
    pin('0');
    expect_count(2);
    select_irq(x"0020");
    acknowledge;
    ASSERT int_req = '1' REPORT "Timer acknowledge cleared external request" SEVERITY failure;
    select_irq(x"00A0");
    -- A timer request arriving during external vector delivery must survive.
    pin('1');
    pin('0');
    pin('1');
    pin('0');
    ASSERT int_vector = x"00A0" REPORT "Vector changed during delivery" SEVERITY failure;
    acknowledge;
    ASSERT int_req = '1' REPORT "External acknowledge cleared timer request" SEVERITY failure;
    select_irq(x"0020");
    acknowledge;
    ASSERT int_req = '0' REPORT "Priority requests did not clear separately" SEVERITY failure;

    -- Pulse width mode gates phi and interrupts on the trailing edge.
    restart;
    pin('1');
    put(7, 4);
    put(6, 59); -- /2, pulse width, active low, both interrupts enabled.
    step('1', 8);
    expect_count(4);
    pin('0');
    ASSERT int_req = '0' REPORT "Pulse width interrupted on leading edge" SEVERITY failure;
    step('1', 3);
    expect_count(3);
    pin('1');
    ASSERT int_req = '1' REPORT "Pulse width missed trailing interrupt" SEVERITY failure;
    select_irq(x"00A0");
    acknowledge;
    step('1', 8);
    expect_count(3);
    pin('0');
    step('1');
    expect_count(3);
    step('1', 5);
    expect_count(4);
    ASSERT int_req = '1' REPORT "Pulse width timer did not reload" SEVERITY failure;
    restart;
    ASSERT int_req = '0' REPORT "Reset did not clear pending requests" SEVERITY failure;
    expect_count(0);
    REPORT "3870 timer prescales, modes, readback and interrupts passed";
    stop;
    WAIT;
  END PROCESS;
END ARCHITECTURE;
