LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.env.ALL;
USE work.base_pack.ALL;

ENTITY tb_expander1_playback IS
  GENERIC (firmware : string := "");
END ENTITY;

ARCHITECTURE test OF tb_expander1_playback IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na : std_logic := '0';
  SIGNAL host_data_n, host_clock_n : std_logic := '1';
  SIGNAL data_n, clock_n, interrupt_n, record_data, record_enable : std_logic;
  SIGNAL playback_data : std_logic := '1';
  SIGNAL playback_enable, recorded : std_logic := '0';
  SIGNAL dl_addr : unsigned(15 DOWNTO 0) := (OTHERS => '0');
  SIGNAL dl_data : uv8 := (OTHERS => '0');
  SIGNAL dl_wr : std_logic := '0';
BEGIN
  clk <= NOT clk AFTER 34920639 fs;
  dut : ENTITY work.expander1
    PORT MAP (
      clk => clk, reset_na => reset_na,
      host_data_n => host_data_n, host_clock_n => host_clock_n,
      data_n => data_n, clock_n => clock_n, interrupt_n => interrupt_n,
      record_data => record_data, record_enable => record_enable,
      playback_data => playback_data, playback_enable => playback_enable,
      dl_addr => dl_addr, dl_data => dl_data, dl_wr => dl_wr, dl_index => x"03"
      );

  PROCESS IS
    TYPE delays_t IS ARRAY (0 TO 1023) OF time;
    VARIABLE delays : delays_t;
    VARIABLE stamp : time;
    VARIABLE count : natural := 0;
    VARIABLE level : std_logic;
  BEGIN
    WAIT UNTIL rising_edge(record_enable);
    stamp := now;
    level := record_data;
    LOOP
      WAIT ON record_data, record_enable;
      EXIT WHEN record_enable = '0';
      IF record_data /= level THEN
        delays(count) := now - stamp;
        count := count + 1;
        stamp := now;
        level := record_data;
      END IF;
    END LOOP;
    recorded <= '1';
    WAIT UNTIL rising_edge(playback_enable);
    playback_data <= '1';
    FOR i IN 0 TO count - 1 LOOP
      WAIT FOR delays(i);
      playback_data <= NOT playback_data;
    END LOOP;
    WAIT;
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
        WAIT UNTIL rising_edge(interrupt_n);
      END LOOP;
      REPORT "Host byte " & natural'image(value) & " reply " &
             work.base_pack.to_hstring(result);
    END PROCEDURE;
  BEGIN
    file_open(image, firmware, read_mode);
    FOR i IN 0 TO 2047 LOOP
      read(image, byte);
      WAIT UNTIL falling_edge(clk);
      dl_addr <= to_unsigned(i, 16);
      dl_data <= to_unsigned(character'pos(byte), 8);
      dl_wr <= '1';
    END LOOP;
    file_close(image);
    WAIT UNTIL falling_edge(clk);
    dl_wr <= '0';
    reset_na <= '1';
    WAIT FOR 100 us;
    host_clock_n <= '0';
    transfer(2, reply);
    transfer(0, reply);
    transfer(1, reply);
    transfer(0, reply);
    transfer(0, reply);
    transfer(1, reply);
    transfer(16#A5#, reply);
    transfer(16#7E#, reply);
    transfer(16#D6#, reply);
    WAIT UNTIL recorded = '1';
    reset_na <= '0';
    host_data_n <= '1';
    host_clock_n <= '1';
    WAIT FOR 1 us;
    reset_na <= '1';
    WAIT FOR 100 us;
    host_clock_n <= '0';
    transfer(1, reply);
    transfer(0, reply);
    transfer(1, reply);
    transfer(0, reply);
    transfer(0, reply);
    ASSERT reply = 0 REPORT "Wrong length high" SEVERITY failure;
    transfer(0, reply);
    ASSERT reply = 1 REPORT "Wrong length low" SEVERITY failure;
    transfer(0, reply);
    ASSERT reply = x"A5" REPORT "Wrong playback payload" SEVERITY failure;
    transfer(0, reply);
    ASSERT reply = x"7E" REPORT "Wrong playback CRC low" SEVERITY failure;
    transfer(0, reply);
    ASSERT reply = x"D6" REPORT "Wrong playback CRC high" SEVERITY failure;
    WAIT UNTIL falling_edge(playback_enable) FOR 1 sec;
    ASSERT playback_enable = '0' REPORT "Playback did not stop" SEVERITY failure;
    WAIT UNTIL falling_edge(interrupt_n) FOR 5 ms;
    ASSERT interrupt_n = '0' AND data_n = '0' AND clock_n = '1'
      REPORT "Incorrect playback status" SEVERITY failure;
    REPORT "Original firmware SAVE/LOAD round trip passed";
    stop;
    WAIT;
  END PROCESS;

  PROCESS IS
  BEGIN
    WAIT FOR 3 sec;
    ASSERT false REPORT "Playback simulation timed out" SEVERITY failure;
  END PROCESS;
END ARCHITECTURE;
