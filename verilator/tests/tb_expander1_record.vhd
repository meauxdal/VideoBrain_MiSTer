LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.env.ALL;
USE std.textio.ALL;
USE work.base_pack.ALL;

ENTITY tb_expander1_record IS
  GENERIC (firmware : string := ""; bad_crc : boolean := false;
           capture_file : string := "out/expander1/record.csv");
END ENTITY;

ARCHITECTURE test OF tb_expander1_record IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na : std_logic := '0';
  SIGNAL host_data_n, host_clock_n : std_logic := '1';
  SIGNAL data_n, clock_n, interrupt_n, record_data, record_enable : std_logic;
  SIGNAL dl_addr : unsigned(15 DOWNTO 0) := (OTHERS => '0');
  SIGNAL dl_data : uv8 := (OTHERS => '0');
  SIGNAL dl_wr : std_logic := '0';
  SIGNAL pulses : natural := 0;
BEGIN
  clk <= NOT clk AFTER 34920639 fs;
  dut : ENTITY work.expander1
    PORT MAP (
      clk => clk, reset_na => reset_na,
      host_data_n => host_data_n, host_clock_n => host_clock_n,
      data_n => data_n, interrupt_n => interrupt_n,
      clock_n => clock_n,
      record_data => record_data, record_enable => record_enable,
      dl_addr => dl_addr, dl_data => dl_data, dl_wr => dl_wr, dl_index => x"03"
      );

  PROCESS (record_data) IS
  BEGIN
    IF rising_edge(record_data) AND record_enable = '1' THEN
      pulses <= pulses + 1;
    END IF;
  END PROCESS;

  PROCESS (record_data, record_enable) IS
    FILE capture : text OPEN write_mode IS capture_file;
    VARIABLE row : line;
  BEGIN
    write(row, time'image(now) & "," & std_logic'image(record_data) &
               "," & std_logic'image(record_enable));
    writeline(capture, row);
  END PROCESS;

  PROCESS IS
    TYPE binary_file IS FILE OF character;
    FILE image : binary_file;
    VARIABLE byte : character;
    VARIABLE reply : uv8;

    PROCEDURE transfer(value : natural; VARIABLE result : OUT uv8) IS
      VARIABLE bits : uv8;
    BEGIN
      bits := to_unsigned(value, 8);
      FOR i IN 7 DOWNTO 0 LOOP
        WAIT UNTIL falling_edge(interrupt_n) FOR 1 sec;
        ASSERT interrupt_n = '0' REPORT "Host transfer timed out" SEVERITY failure;
        host_data_n <= NOT bits(i);
        host_clock_n <= '1';
        WAIT FOR 1 ns;
        result(i) := NOT clock_n;
        -- P1.7 is the Expander's reply, shared with the host clock line.
        WAIT UNTIL rising_edge(interrupt_n);
      END LOOP;
      REPORT "Host byte " & natural'image(value) & " reply " &
             work.base_pack.to_hstring(result);
    END PROCEDURE;
  BEGIN
    ASSERT firmware /= "" REPORT "Supply the original 2K firmware" SEVERITY failure;
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
    reset_na <= '1';
    WAIT FOR 100 us;
    host_clock_n <= '0';
    transfer(2, reply); -- Record, timing index 0, one record, no motor delay.
    transfer(0, reply);
    transfer(1, reply);
    transfer(0, reply);
    transfer(0, reply); -- Length high.
    transfer(1, reply); -- Length low.
    transfer(16#A5#, reply);
    IF bad_crc THEN
      transfer(16#7F#, reply);
    ELSE
      transfer(16#7E#, reply); -- Firmware CRC of 00 01 A5, low byte first.
    END IF;
    transfer(16#D6#, reply);
    WAIT UNTIL falling_edge(record_enable) FOR 1 sec;
    ASSERT record_enable = '0' REPORT "Record did not stop" SEVERITY failure;
    ASSERT pulses = 342 + boolean'pos(bad_crc)
      REPORT "Incorrect cassette pulse count" SEVERITY failure;
    WAIT UNTIL falling_edge(interrupt_n) FOR 5 ms;
    ASSERT interrupt_n = '0' AND data_n = '0' AND
           ((clock_n = '1' AND NOT bad_crc) OR (clock_n = '0' AND bad_crc))
      REPORT "Incorrect firmware record status" SEVERITY failure;
    REPORT "Original firmware record pulses: " & natural'image(pulses);
    WAIT FOR 1 ns;
    stop;
    WAIT;
  END PROCESS;

  PROCESS IS
  BEGIN
    WAIT FOR 2 sec;
    ASSERT false REPORT "Record simulation timed out" SEVERITY failure;
  END PROCESS;
END ARCHITECTURE;
