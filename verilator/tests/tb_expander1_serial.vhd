LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.env.ALL;
USE work.base_pack.ALL;

ENTITY tb_expander1_serial IS
  GENERIC (firmware : string := "");
END ENTITY;

ARCHITECTURE test OF tb_expander1_serial IS
  CONSTANT bit_time : time := 1 sec / 300;
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na : std_logic := '0';
  SIGNAL host_data_n, host_clock_n : std_logic := '1';
  SIGNAL data_n, clock_n, interrupt_n : std_logic;
  SIGNAL modem_rxd, printer_rxd : std_logic := '1';
  SIGNAL modem_txd, printer_txd : std_logic;
  SIGNAL dl_addr : unsigned(15 DOWNTO 0) := (OTHERS => '0');
  SIGNAL dl_data : uv8 := (OTHERS => '0');
  SIGNAL dl_wr : std_logic := '0';
  SIGNAL running : boolean := false;
  SIGNAL reverse_ports : boolean := false;
  SIGNAL tx_line, copy_line, rx_line : std_logic;
  SIGNAL tx_done, copy_done, host_done, rx_done : boolean := false;
BEGIN
  clk <= NOT clk AFTER 34920639 fs;
  tx_line <= printer_txd WHEN reverse_ports ELSE modem_txd;
  copy_line <= modem_txd WHEN reverse_ports ELSE printer_txd;
  modem_rxd <= rx_line WHEN NOT reverse_ports ELSE '1';
  printer_rxd <= rx_line WHEN reverse_ports ELSE '1';

  dut : ENTITY work.expander1
    PORT MAP (
      clk => clk, reset_na => reset_na,
      host_data_n => host_data_n, host_clock_n => host_clock_n,
      data_n => data_n, clock_n => clock_n, interrupt_n => interrupt_n,
      record_data => OPEN, record_enable => OPEN,
      modem_rxd => modem_rxd, modem_txd => modem_txd,
      printer_rxd => printer_rxd, printer_txd => printer_txd,
      dl_addr => dl_addr, dl_data => dl_data, dl_wr => dl_wr, dl_index => x"03"
      );

  PROCESS IS
    PROCEDURE receive_byte(SIGNAL pin : IN std_logic; expected : uv8) IS
      VARIABLE value : uv8;
    BEGIN
      WAIT UNTIL falling_edge(pin) FOR 15 ms;
      ASSERT pin = '0' REPORT "Serial start timed out" SEVERITY failure;
      WAIT FOR bit_time / 2;
      ASSERT pin = '0' REPORT "Invalid serial start bit" SEVERITY failure;
      FOR i IN 0 TO 7 LOOP
        WAIT FOR bit_time;
        value(i) := pin;
      END LOOP;
      WAIT FOR bit_time;
      ASSERT pin = '1' REPORT "Invalid serial stop bit" SEVERITY failure;
      ASSERT value = expected
        REPORT "Serial data: " & work.base_pack.to_hstring(value) &
               " expected " & work.base_pack.to_hstring(expected) SEVERITY failure;
    END PROCEDURE;
  BEGIN
    FOR test IN 0 TO 1 LOOP
      WAIT UNTIL running;
      tx_done <= false;
      receive_byte(tx_line, x"A5");
      tx_done <= true;
      WAIT UNTIL NOT running;
    END LOOP;
    WAIT;
  END PROCESS;

  PROCESS IS
    VARIABLE value : uv8;
  BEGIN
    FOR test IN 0 TO 1 LOOP
      WAIT UNTIL running;
      copy_done <= false;
      WAIT UNTIL falling_edge(copy_line) FOR 15 ms;
      ASSERT copy_line = '0' REPORT "Receive copy timed out" SEVERITY failure;
      WAIT FOR bit_time / 2;
      ASSERT copy_line = '0' REPORT "Invalid copied start bit" SEVERITY failure;
      FOR i IN 0 TO 7 LOOP
        WAIT FOR bit_time;
        value(i) := copy_line;
      END LOOP;
      WAIT FOR bit_time;
      ASSERT copy_line = '1' AND value = x"3C"
        REPORT "Incorrect serial receive copy" SEVERITY failure;
      copy_done <= true;
      WAIT UNTIL NOT running;
    END LOOP;
    WAIT;
  END PROCESS;

  PROCESS IS
    VARIABLE value : uv8;
  BEGIN
    FOR test IN 0 TO 1 LOOP
      WAIT UNTIL running;
      host_done <= false;
      LOOP
        WAIT UNTIL falling_edge(interrupt_n) FOR 15 ms;
        ASSERT interrupt_n = '0' REPORT "Host receive timed out" SEVERITY failure;
        EXIT WHEN clock_n = '1';
      END LOOP;
      FOR i IN 0 TO 7 LOOP
        WAIT UNTIL falling_edge(interrupt_n) FOR 5 ms;
        ASSERT interrupt_n = '0' REPORT "Host receive bit timed out" SEVERITY failure;
        value(i) := NOT clock_n;
      END LOOP;
      WAIT UNTIL falling_edge(interrupt_n) FOR 5 ms;
      ASSERT interrupt_n = '0' AND clock_n = '0' AND value = x"3C"
        REPORT "Incorrect host serial receive" SEVERITY failure;
      host_done <= true;
      WAIT UNTIL NOT running;
    END LOOP;
    WAIT;
  END PROCESS;

  PROCESS IS
    CONSTANT value : uv8 := x"3C";
  BEGIN
    rx_line <= '1';
    FOR test IN 0 TO 1 LOOP
      WAIT UNTIL running;
      rx_done <= false;
      WAIT FOR 437 us;
      rx_line <= '0';
      WAIT FOR bit_time;
      FOR i IN 0 TO 7 LOOP
        rx_line <= value(i);
        WAIT FOR bit_time;
      END LOOP;
      rx_line <= '1';
      WAIT FOR bit_time;
      rx_done <= true;
      WAIT UNTIL NOT running;
    END LOOP;
    WAIT;
  END PROCESS;

  PROCESS IS
    TYPE binary_file IS FILE OF character;
    FILE image : binary_file;
    VARIABLE byte : character;
    CONSTANT payload : uv8 := x"A5";
    PROCEDURE transfer(value : natural) IS
      VARIABLE bits : uv8;
    BEGIN
      bits := to_unsigned(value, 8);
      FOR i IN 7 DOWNTO 0 LOOP
        WAIT UNTIL falling_edge(interrupt_n) FOR 5 ms;
        ASSERT interrupt_n = '0' REPORT "Command timed out" SEVERITY failure;
        host_data_n <= NOT bits(i);
        host_clock_n <= '1';
        WAIT UNTIL rising_edge(interrupt_n) FOR 1 ms;
        ASSERT interrupt_n = '1' REPORT "Command strobe stuck" SEVERITY failure;
      END LOOP;
    END PROCEDURE;
    PROCEDURE serial_bit(value : std_logic) IS
    BEGIN
      WAIT UNTIL falling_edge(interrupt_n) FOR 5 ms;
      ASSERT interrupt_n = '0' REPORT "Serial timer stopped" SEVERITY failure;
      host_data_n <= NOT value;
    END PROCEDURE;
  BEGIN
    ASSERT firmware /= "" REPORT "Supply the original 2K firmware" SEVERITY failure;
    WAIT FOR 1 us;
    ASSERT modem_txd = '1' AND printer_txd = '1'
      REPORT "Unloaded serial outputs are not idle" SEVERITY failure;
    file_open(image, firmware, read_mode);
    FOR i IN 0 TO 2047 LOOP
      ASSERT NOT endfile(image) REPORT "Short firmware" SEVERITY failure;
      read(image, byte);
      WAIT UNTIL falling_edge(clk);
      dl_addr <= to_unsigned(i, 16);
      dl_data <= to_unsigned(character'pos(byte), 8);
      dl_wr <= '1';
    END LOOP;
    ASSERT endfile(image) REPORT "Oversize firmware" SEVERITY failure;
    file_close(image);
    WAIT UNTIL falling_edge(clk);
    dl_wr <= '0';

    FOR test IN 0 TO 1 LOOP
      reverse_ports <= test = 1;
      host_data_n <= '1';
      host_clock_n <= '1';
      reset_na <= '1';
      WAIT FOR 100 us;
      host_clock_n <= '0';
      transfer(4);
      transfer(2);
      IF test = 0 THEN transfer(16#0D#); ELSE transfer(16#32#); END IF;
      host_data_n <= '0';
      running <= true;
      serial_bit('0');
      FOR i IN 0 TO 7 LOOP serial_bit(payload(i)); END LOOP;
      serial_bit('1');
      WAIT FOR 12 ms;
      ASSERT tx_done AND copy_done AND host_done AND rx_done
        REPORT "Serial transaction did not complete" SEVERITY failure;
      reset_na <= '0';
      running <= false;
      WAIT FOR 1 us;
      ASSERT modem_txd = '1' AND printer_txd = '1' AND interrupt_n = '1'
        REPORT "Reset did not release serial/host outputs" SEVERITY failure;
    END LOOP;
    REPORT "Original ROM serial transmit, receive, routing and reset passed";
    stop;
    WAIT;
  END PROCESS;

  PROCESS IS
  BEGIN
    WAIT FOR 200 ms;
    ASSERT false REPORT "Serial simulation timed out" SEVERITY failure;
  END PROCESS;
END ARCHITECTURE;
