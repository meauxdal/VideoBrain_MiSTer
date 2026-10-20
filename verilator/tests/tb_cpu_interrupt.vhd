LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.base_pack.ALL;
USE work.f8_pack.ALL;

ENTITY tb_cpu_interrupt IS
  GENERIC (
    late_request : boolean := false;
    long_cycle : boolean := false
  );
END ENTITY;

ARCHITECTURE test OF tb_cpu_interrupt IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na : std_logic := '0';
  SIGNAL intreq : std_logic := '0';
  SIGNAL dr, dw, ext_rdata, acc : uv8;
  SIGNAL romc : uv5;
  SIGNAL phase : uint4;
  SIGNAL ext_addr : unsigned(13 DOWNTO 0);
  SIGNAL ext_rd, int_ack : std_logic;
  SIGNAL pc0, pc1 : uv16;
BEGIN
  clk <= NOT clk AFTER 5 ns;
  reset_na <= '1' AFTER 100 ns;

  PROCESS(all)
  BEGIN
    ext_rdata <= x"2B";
    CASE to_integer(ext_addr) IS
      WHEN 0 => ext_rdata <= x"1B";    -- EI
      WHEN 1 => ext_rdata <= x"75";    -- LIS 5
      WHEN 2 =>
        IF long_cycle THEN ext_rdata <= x"50"; -- LR 0,A
        ELSE ext_rdata <= x"76"; END IF;       -- LIS 6
      WHEN 3 =>
        IF long_cycle THEN ext_rdata <= x"30"; END IF; -- DS 0
      WHEN 4 =>
        IF long_cycle THEN ext_rdata <= x"40"; END IF; -- LR A,0
      WHEN 256 => ext_rdata <= x"79";  -- LIS 9
      WHEN 257 => ext_rdata <= x"1C";  -- POP
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
      intreq => intreq, acco => acc, visaro => OPEN, iozcso => OPEN
    );

  busif : ENTITY work.f8_busif
    PORT MAP (
      clk => clk, ce => '1', reset_na => reset_na,
      dw => dw, dr => dr, dv => OPEN, romc => romc,
      tick => '0', phase => phase,
      ext_addr => ext_addr, ext_rd => ext_rd, ext_wr => OPEN,
      ext_wdata => OPEN, ext_rdata => ext_rdata,
      ext_req => OPEN, ext_class => OPEN, ext_grant => '0',
      io_addr => OPEN, io_rd => OPEN, io_wr => OPEN,
      io_wdata => OPEN, io_rdata => x"00",
      int_vector => x"0100", int_ack => int_ack,
      pc0o => pc0, pc1o => pc1, dc0o => OPEN
    );

  PROCESS
    TYPE sequence_t IS ARRAY(natural RANGE <>) OF uv5;
    CONSTANT expected : sequence_t :=
      (ROMC_10, ROMC_1C, ROMC_0F, ROMC_13, ROMC_00);
    VARIABLE started, vector_seen, returned : boolean := false;
    VARIABLE step : natural := 0;
    VARIABLE previous_start : time := 0 ns;
    VARIABLE return_pc : natural := 2;
    VARIABLE start_time : time := 0 ns;
    VARIABLE cycle_time : time := 80 ns;
    VARIABLE expected_acc : natural := 5;
  BEGIN
    IF late_request THEN return_pc := 3; expected_acc := 6; END IF;
    IF long_cycle THEN return_pc := 4; cycle_time := 120 ns; END IF;
    WAIT UNTIL falling_edge(clk);
    IF reset_na = '1' THEN
      IF NOT late_request AND NOT long_cycle AND NOT started THEN
        intreq <= '1';
      ELSIF late_request AND pc0 = x"0002" AND romc = ROMC_00 AND phase = 4 THEN
        intreq <= '1';
      ELSIF long_cycle AND pc0 = x"0003" AND romc = ROMC_00 AND phase = 6 THEN
        intreq <= '1';
      END IF;
      IF int_ack = '1' THEN intreq <= '0'; END IF;

      IF ext_rd = '1' AND NOT started THEN
        ASSERT to_integer(ext_addr) /= return_pc
          REPORT "Interrupt must replace the next opcode fetch" SEVERITY failure;
      END IF;

      IF phase = 1 THEN
        IF romc = ROMC_10 THEN
          ASSERT NOT started REPORT "Unexpected second interrupt" SEVERITY failure;
          started := true;
          start_time := now;
        END IF;
        IF started AND step < expected'length THEN
          ASSERT romc = expected(step)
            REPORT "Incorrect interrupt ROMC sequence" SEVERITY failure;
          IF step > 0 THEN
            IF step = 1 THEN
              ASSERT now - previous_start = cycle_time
                REPORT "ROMC 10 must preserve the terminating cycle length" SEVERITY failure;
            ELSE
              ASSERT now - previous_start = 120 ns
                REPORT "Interrupt service state must use a long cycle" SEVERITY failure;
            END IF;
          END IF;
          previous_start := now;
          step := step + 1;
        END IF;
        IF started AND pc0 = x"0101" AND romc = ROMC_00 THEN
          ASSERT now - start_time = cycle_time + 440 ns
            REPORT "Incorrect interrupt entry duration" SEVERITY failure;
          ASSERT pc1 = to_unsigned(return_pc, 16)
            REPORT "Incorrect interrupt return address" SEVERITY failure;
          ASSERT acc = to_unsigned(expected_acc, 8)
            REPORT "Interrupted instruction did not finish" SEVERITY failure;
          vector_seen := true;
        END IF;
        IF vector_seen AND pc0 = to_unsigned(return_pc, 16) AND romc = ROMC_00 THEN
          returned := true;
        ELSIF returned AND pc0 = to_unsigned(return_pc + 2, 16) THEN
          IF long_cycle THEN
            ASSERT acc = x"04"
              REPORT "Interrupted long instruction did not finish" SEVERITY failure;
          ELSIF NOT late_request THEN
            ASSERT acc = x"06"
              REPORT "Return skipped the next instruction" SEVERITY failure;
          END IF;
          REPORT "CPU interrupt fetch replacement and return tests passed";
          std.env.stop;
        END IF;
      END IF;
    END IF;
    ASSERT now < 10 us REPORT "CPU interrupt test timed out" SEVERITY failure;
  END PROCESS;
END ARCHITECTURE;
