LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.env.ALL;
LIBRARY work;
USE work.base_pack.ALL;

ENTITY tb_expander1 IS END ENTITY;
ARCHITECTURE test OF tb_expander1 IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na : std_logic := '0';
  SIGNAL data_n, interrupt_n : std_logic;
  SIGNAL host_clock_n : std_logic := '1';
  SIGNAL dl_addr : unsigned(15 DOWNTO 0) := (OTHERS => '0');
  SIGNAL dl_data : uv8 := (OTHERS => '0');
  SIGNAL dl_wr : std_logic := '0';
BEGIN
  clk <= NOT clk AFTER 35 ns;
  dut : ENTITY work.expander1
    PORT MAP (
      clk => clk, reset_na => reset_na,
      host_data_n => '1', host_clock_n => host_clock_n,
      data_n => data_n, interrupt_n => interrupt_n,
      clock_n => OPEN,
      record_data => OPEN, record_enable => OPEN,
      dl_addr => dl_addr, dl_data => dl_data, dl_wr => dl_wr, dl_index => x"03"
      );
  PROCESS IS
  BEGIN
    WAIT FOR 1 us;
    reset_na <= '1';
    WAIT FOR 10 us;
    ASSERT data_n = '1' AND interrupt_n = '1'
      REPORT "Unloaded Expander drives host lines" SEVERITY failure;
    reset_na <= '0';
    FOR i IN 0 TO 2047 LOOP
      WAIT UNTIL falling_edge(clk);
      dl_addr <= to_unsigned(i, 16);
      CASE i IS
        WHEN 0 => dl_data <= x"73"; -- LIS 3
        WHEN 1 => dl_data <= x"B1"; -- OUTS 1
        WHEN 2 => dl_data <= x"90"; -- BR
        WHEN 3 => dl_data <= x"FF";
        WHEN OTHERS => dl_data <= x"2B";
      END CASE;
      dl_wr <= '1';
    END LOOP;
    WAIT UNTIL falling_edge(clk);
    dl_wr <= '0';
    WAIT FOR 1 us;
    ASSERT data_n = '1' AND interrupt_n = '1'
      REPORT "Reset Expander drives host lines" SEVERITY failure;
    reset_na <= '1';
    WAIT FOR 20 us;
    ASSERT data_n = '0' AND interrupt_n = '0'
      REPORT "Expander firmware did not drive P1.0/P1.1" SEVERITY failure;
    reset_na <= '0';
    WAIT FOR 1 us;
    ASSERT data_n = '1' AND interrupt_n = '1'
      REPORT "Expander reset did not release host lines" SEVERITY failure;
    reset_na <= '1';
    WAIT FOR 20 us;
    ASSERT data_n = '0' AND interrupt_n = '0'
      REPORT "Expander firmware did not survive host reset" SEVERITY failure;
    reset_na <= '0';
    FOR i IN 0 TO 2047 LOOP
      WAIT UNTIL falling_edge(clk);
      dl_addr <= to_unsigned(i, 16);
      CASE i IS
        WHEN 0 => dl_data <= x"70"; -- Release P1
        WHEN 1 | 8 => dl_data <= x"B1";
        WHEN 2 => dl_data <= x"A1"; -- Read host clock at P1.7
        WHEN 3 => dl_data <= x"21";
        WHEN 4 => dl_data <= x"80";
        WHEN 5 => dl_data <= x"14"; -- Shift P1.7 to P1.1
        WHEN 6 | 7 => dl_data <= x"12";
        WHEN 9 => dl_data <= x"90";
        WHEN 10 => dl_data <= x"F8";
        WHEN OTHERS => dl_data <= x"2B";
      END CASE;
      dl_wr <= '1';
    END LOOP;
    WAIT UNTIL falling_edge(clk);
    dl_wr <= '0';
    reset_na <= '1';
    WAIT FOR 60 us;
    ASSERT interrupt_n = '1' REPORT "Released host clock reads low" SEVERITY failure;
    host_clock_n <= '0';
    WAIT FOR 60 us;
    ASSERT interrupt_n = '0' REPORT "Host clock did not reach P1.7" SEVERITY failure;
    host_clock_n <= '1';
    WAIT FOR 60 us;
    ASSERT interrupt_n = '1' REPORT "Host clock release did not reach P1.7" SEVERITY failure;
    WAIT UNTIL falling_edge(clk);
    dl_addr <= x"0800";
    dl_wr <= '1';
    WAIT UNTIL falling_edge(clk);
    dl_wr <= '0';
    WAIT FOR 1 us;
    ASSERT data_n = '1' AND interrupt_n = '1'
      REPORT "Oversize firmware left Expander active" SEVERITY failure;

    -- Timer ISR sets R0; the main loop reports success only after returning.
    FOR enabled IN 0 TO 1 LOOP
      reset_na <= '0';
      FOR i IN 0 TO 2047 LOOP
        WAIT UNTIL falling_edge(clk);
        dl_addr <= to_unsigned(i, 16);
        CASE i IS
          WHEN 0 => dl_data <= x"70"; -- LIS 0
          WHEN 1 | 28 | 37 | 97 => dl_data <= x"B1";
          WHEN 2 | 36 => dl_data <= x"50"; -- LR R0,A
          WHEN 3 | 17 => dl_data <= x"20";
          WHEN 4 => dl_data <= x"04";
          WHEN 5 => dl_data <= x"B7"; -- Timer modulo 4
          WHEN 6 => dl_data <= x"26"; -- IN 7: read stopped timer
          WHEN 7 => dl_data <= x"07";
          WHEN 8 | 13 | 23 => dl_data <= x"25";
          WHEN 9 => dl_data <= x"04";
          WHEN 10 | 15 | 25 => dl_data <= x"94";
          WHEN 11 => dl_data <= x"55"; -- Failure at 0x060
          WHEN 12 => dl_data <= x"A6"; -- INS 6: read EXT INT pin
          WHEN 14 => dl_data <= x"80";
          WHEN 16 => dl_data <= x"50";
          WHEN 18 => dl_data <= x"AA"; -- /40, run, timer IRQ
          WHEN 19 | 34 => dl_data <= x"B6";
          WHEN 20 =>
            IF enabled = 1 THEN dl_data <= x"1B"; ELSE dl_data <= x"2B"; END IF;
          WHEN 21 => dl_data <= x"2B";
          WHEN 22 => dl_data <= x"40"; -- Poll R0
          WHEN 24 => dl_data <= x"01";
          WHEN 26 => dl_data <= x"FC";
          WHEN 27 => dl_data <= x"72"; -- Report return on P1
          WHEN 29 | 98 => dl_data <= x"90";
          WHEN 30 | 99 => dl_data <= x"FF";
          WHEN 32 => dl_data <= x"08"; -- LR K,P
          WHEN 33 => dl_data <= x"70"; -- Stop and mask timer
          WHEN 35 => dl_data <= x"71";
          WHEN 38 => dl_data <= x"1B";
          WHEN 39 => dl_data <= x"09"; -- LR P,K
          WHEN 40 => dl_data <= x"1C"; -- POP
          WHEN 96 => dl_data <= x"73"; -- Readback failure
          WHEN OTHERS => dl_data <= x"2B";
        END CASE;
        dl_wr <= '1';
      END LOOP;
      WAIT UNTIL falling_edge(clk);
      dl_wr <= '0';
      reset_na <= '1';
      WAIT FOR 50 us;
      ASSERT data_n = '1' AND interrupt_n = '1'
        REPORT "Timer interrupt arrived before the /40 interval" SEVERITY failure;
      WAIT FOR 250 us;
      IF enabled = 1 THEN
        ASSERT data_n = '1' AND interrupt_n = '0'
          REPORT "Timer ISR or return to main program failed" SEVERITY failure;
        reset_na <= '0';
        WAIT FOR 1 us;
        ASSERT data_n = '1' AND interrupt_n = '1'
          REPORT "Reset after timer interrupt did not release host lines" SEVERITY failure;
        reset_na <= '1';
        WAIT FOR 50 us;
        ASSERT data_n = '1' AND interrupt_n = '1'
          REPORT "Reset left stale timer state" SEVERITY failure;
        WAIT FOR 250 us;
        ASSERT data_n = '1' AND interrupt_n = '0'
          REPORT "Timer firmware did not restart after reset" SEVERITY failure;
      ELSE
        ASSERT data_n = '1' AND interrupt_n = '1'
          REPORT "Timer interrupt ignored the CPU interrupt mask" SEVERITY failure;
      END IF;
    END LOOP;
    REPORT "Expander 1 host interface, timer ISR, interrupt mask and reset passed";
    stop;
    WAIT;
  END PROCESS;
END ARCHITECTURE;
