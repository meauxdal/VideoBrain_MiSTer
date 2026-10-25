LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.base_pack.ALL;
USE work.f8_pack.ALL;

ENTITY tb_smi_vector IS END ENTITY;

ARCHITECTURE test OF tb_smi_vector IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na, cpu_ce, timer_ce, io_wr, ext_int : std_logic := '0';
  SIGNAL address, data : uv8 := x"00";
  SIGNAL request, ack, dv : std_logic;
  SIGNAL vector, pc0, pc1 : uv16;
  SIGNAL dr : uv8;
  SIGNAL romc : uv5 := ROMC_1C;
  SIGNAL phase : uint4 := 0;
BEGIN
  clk <= NOT clk AFTER 5 ns;
  smi : ENTITY work.f3853 GENERIC MAP (PRESCALE => 1)
    PORT MAP (clk => clk, reset_na => reset_na, ce => timer_ce,
      io_addr => address, io_rd => '0', io_wr => io_wr, io_wdata => data,
      io_rdata => OPEN, io_sel => OPEN, ext_int => ext_int,
      int_req => request, int_vector => vector, int_ack => ack);
  busif : ENTITY work.f8_busif
    PORT MAP (clk => clk, reset_na => reset_na, ce => cpu_ce,
      dw => x"00", dr => dr, dv => dv, romc => romc, tick => '0', phase => phase,
      ext_addr => OPEN, ext_rd => OPEN, ext_wr => OPEN,
      ext_wdata => OPEN, ext_rdata => x"2B", ext_req => OPEN,
      ext_class => OPEN, ext_grant => '0', io_addr => OPEN,
      io_rd => OPEN, io_wr => OPEN, io_wdata => OPEN, io_rdata => x"00",
      int_vector => vector, int_ack => ack, pc0o => pc0, pc1o => pc1, dc0o => OPEN);

  PROCESS
    VARIABLE expected_vector : uv16;
    VARIABLE cases : natural := 0;
    PROCEDURE tick IS
    BEGIN
      WAIT UNTIL rising_edge(clk); WAIT FOR 1 ns;
    END PROCEDURE;
    PROCEDURE write_port(a, d : uv8) IS
    BEGIN
      address <= a; data <= d; io_wr <= '1'; tick;
      io_wr <= '0'; tick;
    END PROCEDURE;
    PROCEDURE timer_clock IS
    BEGIN
      timer_ce <= '1'; tick; timer_ce <= '0';
    END PROCEDURE;
  BEGIN
    -- Sweep every half-phase of both vector states, the clearing edge itself,
    -- and the first edge after it. Test both sources and the other-source event.
    -- The timer is pre-positioned one enabled clock before a repeat timeout.
    FOR timer_source IN boolean LOOP
      FOR other_source IN boolean LOOP
        FOR event_at IN 0 TO 25 LOOP
          reset_na <= '0'; cpu_ce <= '0'; timer_ce <= '0';
          io_wr <= '0'; ext_int <= '0'; tick;
          ASSERT ack = '0' REPORT "Reset retained acknowledge" SEVERITY failure;
          reset_na <= '1'; tick;
          write_port(x"0C", x"12"); write_port(x"0D", x"B4");
          IF timer_source THEN
            write_port(x"0E", x"03"); expected_vector := x"1234";
            write_port(x"0F", x"7F"); timer_clock; timer_clock;
            -- 255 clocks per repeat; leave exactly one clock to the next one.
            FOR i IN 1 TO 254 LOOP timer_clock; END LOOP;
          ELSE
            write_port(x"0E", x"01"); expected_vector := x"12B4";
            ext_int <= '1'; tick; ext_int <= '0'; tick;
            -- A masked timer expiry during external entry must survive ack.
            write_port(x"0F", x"7F"); timer_clock;
          END IF;
          timer_ce <= '0'; tick;
          ASSERT request = '1' REPORT "Missing initial request" SEVERITY failure;

          -- The CPU has accepted the IRQ. Neither entry state acknowledges it.
          FOR state IN 0 TO 1 LOOP
            IF state = 0 THEN romc <= ROMC_10; ELSE romc <= ROMC_1C; END IF;
            FOR p IN 0 TO 11 LOOP
              phase <= p; cpu_ce <= '1'; tick;
              ASSERT ack = '0' AND request = '1'
                REPORT "Request cleared before vector delivery" SEVERITY failure;
            END LOOP;
          END LOOP;
          FOR step IN 0 TO 25 LOOP
            IF step < 12 THEN romc <= ROMC_0F; phase <= step;
            ELSIF step < 24 THEN romc <= ROMC_13; phase <= step - 12;
            ELSE romc <= ROMC_00; phase <= step - 24; END IF;
            cpu_ce <= '1'; timer_ce <= '0'; ext_int <= '0';
            IF step = event_at THEN
              IF timer_source XOR other_source THEN timer_ce <= '1';
              ELSE ext_int <= '1'; END IF;
            END IF;
            tick;
            ASSERT vector = expected_vector
              REPORT "Pending event changed vector selection" SEVERITY failure;
            IF step = 2 THEN
              ASSERT dv = '1' AND dr = expected_vector(7 DOWNTO 0)
                REPORT "Incorrect vector low byte" SEVERITY failure;
            ELSIF step = 14 THEN
              ASSERT dv = '1' AND dr = expected_vector(15 DOWNTO 8)
                REPORT "Incorrect vector high byte" SEVERITY failure;
            END IF;
            IF step < 23 THEN
              ASSERT ack = '0' AND request = '1'
                REPORT "Early acknowledge during vector delivery" SEVERITY failure;
            ELSIF step = 23 THEN
              ASSERT ack = '1' AND request = '1'
                REPORT "Missing end-of-ROMC13 acknowledge" SEVERITY failure;
            ELSE
              ASSERT ack = '0' REPORT "Acknowledge lasted more than one MCLK" SEVERITY failure;
            END IF;
            IF step >= 24 THEN
              IF NOT other_source AND event_at = 25 AND step = 25 THEN
                ASSERT request = '1' REPORT "Lost event after acknowledge" SEVERITY failure;
              ELSE
                ASSERT request = '0' REPORT "Vector-delivery event retriggered IRQ" SEVERITY failure;
              END IF;
            END IF;
          END LOOP;
          cpu_ce <= '0'; timer_ce <= '0'; ext_int <= '0'; tick;
          ASSERT pc0 = expected_vector AND pc1 = x"0000"
            REPORT "Vector or return address corrupted" SEVERITY failure;
          IF other_source AND NOT timer_source THEN
            write_port(x"0E", x"03");
            ASSERT request = '1' REPORT "External ack lost masked timer expiry" SEVERITY failure;
          END IF;
          -- A held phase11 with ce=0 must not generate another ack.
          romc <= ROMC_13; phase <= 11; tick; tick;
          ASSERT ack = '0' REPORT "Acknowledge ignored CPU enable" SEVERITY failure;
          cases := cases + 1;
        END LOOP;
      END LOOP;
    END LOOP;
    REPORT "SMI vector delivery: " & integer'image(cases) & " source/event/phase cases passed";
    std.env.stop;
    WAIT;
  END PROCESS;
END ARCHITECTURE;
