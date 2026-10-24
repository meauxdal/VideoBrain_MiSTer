-- Independent transcription of Fairchild F3850 Table 3, printed pp.3-21..3-25
-- (refs/orphanedgames.com/fairchild-3850.pdf, PDF pages 15..19).
-- Check executing CPU/bus ROMC sequences and durations, not MICROCODE contents.
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.base_pack.ALL;
USE work.f8_pack.ALL;
ENTITY tb_cpu_opcode_timing IS END ENTITY;
ARCHITECTURE test OF tb_cpu_opcode_timing IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na : std_logic := '0';
  SIGNAL dr, dw, ext_rdata : uv8;
  SIGNAL romc : uv5;
  SIGNAL phase : uint4;
  SIGNAL ext_addr : unsigned(13 DOWNTO 0);
  SIGNAL pc0 : uv16;
  SIGNAL visar : uv6;
  SIGNAL flags : uv5;
  SIGNAL test_opcode, setup_flags, setup_isar : natural := 0;
  TYPE cycles_t IS ARRAY(natural RANGE <>) OF natural;
  TYPE sequence_t IS RECORD
    count : natural;
    states, clocks : cycles_t(0 TO 4);
  END RECORD;
  FUNCTION reference(op, w, isar_low : natural) RETURN sequence_t IS
    VARIABLE r : sequence_t := (1, (OTHERS => 0), (OTHERS => 4));
    VARIABLE taken : boolean;
  BEGIN
    CASE op IS
      WHEN 16#08# => r := (3, (7,11,0,0,0), (6,6,4,4,4));
      WHEN 16#09# => r := (3, (21,24,0,0,0), (6,6,4,4,4));
      WHEN 16#0C# => r := (3, (18,20,0,0,0), (6,6,4,4,4));
      WHEN 16#0D# => r := (3, (23,20,0,0,0), (6,6,4,4,4));
      WHEN 16#0E# | 16#11# => r := (3, (6,9,0,0,0), (6,6,4,4,4));
      WHEN 16#0F# | 16#10# => r := (3, (22,25,0,0,0), (6,6,4,4,4));
      WHEN 16#16# => r := (2, (2,0,0,0,0), (6,4,4,4,4));
      WHEN 16#17# => r := (2, (5,0,0,0,0), (6,4,4,4,4));
      WHEN 16#1A# | 16#1B# | 16#1D# => r := (2, (28,0,0,0,0), (4,4,4,4,4));
      WHEN 16#1C# => r := (2, (4,0,0,0,0), (4,4,4,4,4));
      WHEN 16#20# TO 16#25# => r := (2, (3,0,0,0,0), (6,4,4,4,4));
      WHEN 16#26# => r := (3, (3,27,0,0,0), (6,6,4,4,4));
      WHEN 16#27# => r := (3, (3,26,0,0,0), (6,6,4,4,4));
      WHEN 16#28# => r := (5, (3,13,12,20,0), (6,4,6,6,4));
      WHEN 16#29# => r := (4, (3,12,20,0,0), (6,6,6,4,4));
      WHEN 16#2A# => r := (5, (17,3,14,3,0), (6,4,6,4,4));
      WHEN 16#2C# => r := (2, (29,0,0,0,0), (4,4,4,4,4));
      WHEN 16#30# TO 16#3E# => r.clocks(0) := 6;
      WHEN 16#80# TO 16#87# | 16#90# TO 16#9F# =>
        taken := (to_unsigned(op MOD 16,4) AND to_unsigned(w MOD 16,4)) /= 0;
        IF op >= 16#90# THEN taken := NOT taken; END IF;
        r := (3, (28,3,0,0,0), (4,4,4,4,4));
        IF taken THEN r.states(1) := 1; r.clocks(1) := 6; END IF;
      WHEN 16#88# TO 16#8D# => r := (2, (2,0,0,0,0), (6,4,4,4,4));
      WHEN 16#8E# => r := (2, (10,0,0,0,0), (6,4,4,4,4));
      WHEN 16#8F# =>
        r := (2, (3,0,0,0,0), (4,4,4,4,4));
        IF isar_low /= 7 THEN r.states(0) := 1; r.clocks(0) := 6; END IF;
      WHEN 16#A0# TO 16#A1# | 16#B0# TO 16#B1# | 16#D0# TO 16#DE# =>
        r := (2, (28,0,0,0,0), (4,4,4,4,4));
      WHEN 16#A4# TO 16#AF# => r := (3, (28,27,0,0,0), (6,6,4,4,4));
      WHEN 16#B4# TO 16#BF# => r := (3, (28,26,0,0,0), (6,6,4,4,4));
      WHEN OTHERS => NULL; -- Documented single-short-cycle instructions.
    END CASE;
    RETURN r;
  END FUNCTION;
  FUNCTION documented(op : natural) RETURN boolean IS
  BEGIN
    RETURN NOT (op >= 16#2D# AND op <= 16#2F#) AND
      NOT (op >= 16#30# AND op MOD 16 = 15 AND (op < 16#60# OR op >= 16#C0#)) AND
      op /= 16#A2# AND op /= 16#A3# AND op /= 16#B2# AND op /= 16#B3#;
  END FUNCTION;
BEGIN
  clk <= NOT clk AFTER 5 ns;
  PROCESS(all)
  BEGIN
    ext_rdata <= x"00";
    CASE to_integer(ext_addr) IS
      WHEN 0 => ext_rdata <= x"20"; -- LI 0
      WHEN 1 => ext_rdata <= x"00";
      WHEN 2 => ext_rdata <= x"0B"; -- LR IS,A
      WHEN 3 TO 66 => ext_rdata <= x"5D"; -- Clear every scratch register.
      WHEN 67 => ext_rdata <= x"20";
      WHEN 68 => ext_rdata <= to_unsigned(setup_flags,8);
      WHEN 69 => ext_rdata <= x"59"; -- LR J,A
      WHEN 70 => ext_rdata <= x"1D"; -- LR W,J
      WHEN 71 => ext_rdata <= x"20";
      WHEN 72 => ext_rdata <= to_unsigned(setup_isar,8);
      WHEN 73 => ext_rdata <= x"0B"; -- LR IS,A
      WHEN 74 => ext_rdata <= to_unsigned(test_opcode,8);
      WHEN OTHERS => NULL;
    END CASE;
  END PROCESS;
  cpu : ENTITY work.f8_cpu
    PORT MAP (
      clk => clk, ce => '1', reset_na => reset_na,
      dr => dr, dw => dw, dv => OPEN, romc => romc,
      tick => OPEN, phase => phase,
      po_a_n => OPEN, pi_a_n => x"FF",
      po_b_n => OPEN, pi_b_n => x"FF", port1_wr => OPEN,
      intreq => '0', acco => OPEN, visaro => visar, iozcso => flags
    );

  busif : ENTITY work.f8_busif
    PORT MAP (
      clk => clk, ce => '1', reset_na => reset_na,
      dw => dw, dr => dr, dv => OPEN, romc => romc,
      tick => '0', phase => phase,
      ext_addr => ext_addr, ext_rd => OPEN, ext_wr => OPEN,
      ext_wdata => OPEN, ext_rdata => ext_rdata,
      ext_req => OPEN, ext_class => OPEN, ext_grant => '0',
      io_addr => OPEN, io_rd => OPEN, io_wr => OPEN,
      io_wdata => OPEN, io_rdata => x"00",
      int_vector => x"0000", int_ack => OPEN,
      pc0o => pc0, pc1o => OPEN, dc0o => OPEN
    );

  PROCESS
    VARIABLE expected : sequence_t;
    VARIABLE started : time;
    VARIABLE cases : natural := 0;
    PROCEDURE next_cycle IS
    BEGIN
      FOR i IN 1 TO 1000 LOOP
        WAIT UNTIL falling_edge(clk);
        IF phase = 1 THEN RETURN; END IF;
      END LOOP;
      ASSERT false REPORT "CPU cycle failed to complete" SEVERITY failure;
    END PROCEDURE;
  BEGIN
    FOR op IN 0 TO 255 LOOP
      IF documented(op) THEN
        FOR variant IN 0 TO 3 LOOP
          test_opcode <= op;
          setup_flags <= (variant MOD 2)*15;
          setup_isar <= 3 + (variant / 2)*4;
          expected := reference(op,(variant MOD 2)*15,3+(variant/2)*4);
          reset_na <= '0'; WAIT FOR 100 ns;
          WAIT UNTIL falling_edge(clk); reset_na <= '1';
          FOR setup_cycle IN 0 TO 100 LOOP
            next_cycle;
            EXIT WHEN romc = ROMC_00 AND pc0 = 74;
            ASSERT setup_cycle < 100 REPORT "Setup timed out" SEVERITY failure;
          END LOOP;
          next_cycle;
          FOR step IN 0 TO expected.count-1 LOOP
            ASSERT to_integer(romc) = expected.states(step)
              REPORT "ROMC mismatch: opcode=" & integer'image(op) &
                " variant=" & integer'image(variant) & " step=" & integer'image(step) &
                " actual=" & integer'image(to_integer(romc)) &
                " expected=" & integer'image(expected.states(step)) SEVERITY failure;
            started := now;
            next_cycle;
            ASSERT now-started = expected.clocks(step)*20 ns
              REPORT "Cycle length mismatch: opcode=" & integer'image(op) &
                " variant=" & integer'image(variant) & " step=" & integer'image(step) &
                " actual=" & time'image(now-started) SEVERITY failure;
          END LOOP;
          cases := cases+1;
        END LOOP;
      END IF;
    END LOOP;
    REPORT "Fairchild Table 3 opcode ROMC/timing tests passed: " & integer'image(cases) & " cases";
    std.env.stop;
    WAIT;
  END PROCESS;
END ARCHITECTURE;
