LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.base_pack.ALL;
USE work.f8_pack.ALL;
USE work.uv202_pack.ALL;

ENTITY tb_cpu_bus_wait IS
  GENERIC (
    check_documented : boolean := true;
    trace_bus : boolean := false
  );
END ENTITY;

ARCHITECTURE test OF tb_cpu_bus_wait IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na, clock_reset_na : std_logic := '0';
  SIGNAL cpu_raw, cpu_ce, req, grant, stall, wack : std_logic;
  SIGNAL access_class : bus_access_t;
  SIGNAL dr, dw, rdata : uv8;
  SIGNAL romc : uv5;
  SIGNAL phase : uint4;
  SIGNAL addr : unsigned(13 DOWNTO 0);
  SIGNAL pc : uv16;
  TYPE bytes_t IS ARRAY(natural RANGE <>) OF uv8;
  -- Each LM/ST is followed by a RES1 NOP, so opcode fetches add no waits.
  CONSTANT program : bytes_t := (
    x"70", x"0B", x"2B", -- Initialize A and ISAR.
    x"2A", x"00", x"40", x"16", x"2B",
    x"2A", x"0C", x"00", x"16", x"2B",
    x"2A", x"10", x"00", x"16", x"2B",
    x"2A", x"20", x"00", x"16", x"2B",
    x"2A", x"08", x"00", x"16", x"2B",
    x"2A", x"0C", x"00", x"17", x"2B",
    x"2A", x"08", x"00", x"17", x"2B"
  );
  TYPE counts_t IS ARRAY(0 TO 6) OF natural;
BEGIN
  clk <= NOT clk AFTER 5 ns;
  rdata <= program(to_integer(addr)) WHEN addr < program'length ELSE x"00";

  uv202 : ENTITY work.uv202_top
    PORT MAP (
      clk => clk, reset_na => clock_reset_na, progressive => '0',
      cpu_req => req, cpu_class => access_class, cpu_grant => grant,
      cpu_wack => wack, cpu_stall => stall, umireq0 => '0', umireq1 => '0',
      dmareq0 => OPEN, dmareq1 => OPEN, busy => OPEN,
      mclk_ena => OPEN, brclk_ena => OPEN, brclk_phase => OPEN,
      cpu_ena_raw => cpu_raw, cpu_ce => cpu_ce,
      hblank => OPEN, vblank => OPEN, burst => OPEN, csync => OPEN,
      scanline => OPEN, field => OPEN, hpos => OPEN, vpos => OPEN,
      line_start => OPEN, hblank_falling => OPEN, hblank_rising => OPEN
    );
  cpu : ENTITY work.f8_cpu
    PORT MAP (
      clk => clk, ce => cpu_ce, reset_na => reset_na,
      dr => dr, dw => dw, dv => OPEN, romc => romc,
      tick => OPEN, phase => phase,
      po_a_n => OPEN, pi_a_n => x"FF", po_b_n => OPEN, pi_b_n => x"FF",
      port1_wr => OPEN, intreq => '0', acco => OPEN, visaro => OPEN, iozcso => OPEN
    );
  busif : ENTITY work.f8_busif
    PORT MAP (
      clk => clk, ce => cpu_ce, reset_na => reset_na,
      dw => dw, dr => dr, dv => OPEN, romc => romc, tick => '0', phase => phase,
      ext_addr => addr, ext_rd => OPEN, ext_wr => OPEN,
      ext_wdata => OPEN, ext_rdata => rdata,
      ext_req => req, ext_class => access_class, ext_grant => grant,
      io_addr => OPEN, io_rd => OPEN, io_wr => OPEN, io_wdata => OPEN, io_rdata => x"00",
      int_vector => x"0000", int_ack => OPEN, pc0o => pc, pc1o => OPEN, dc0o => OPEN
    );
  PROCESS
    VARIABLE raw_count, active_count, start_raw, start_active : natural;
    VARIABLE next_pc, case_index, extra : natural;
    VARIABLE pending : boolean;
    VARIABLE previous_req, previous_wack, previous_grant : std_logic;
    VARIABLE last_fall, last_fall_raw, halt_fall, halt_raw, gap_extra : natural;
    VARIABLE halted, resumed : boolean;
    VARIABLE shortest : counts_t := (OTHERS => natural'high);
    VARIABLE longest : counts_t := (OTHERS => 0);
  BEGIN
    FOR offset IN 0 TO 127 LOOP
      reset_na <= '0'; clock_reset_na <= '0';
      FOR i IN 1 TO 32 LOOP WAIT UNTIL falling_edge(clk); END LOOP;
      clock_reset_na <= '1';
      FOR i IN 1 TO 8 + offset LOOP WAIT UNTIL falling_edge(clk); END LOOP;
      reset_na <= '1';
      raw_count := 0; active_count := 0; case_index := 0; pending := false;
      previous_req := '0'; previous_wack := '0'; previous_grant := '0';
      last_fall := 0; last_fall_raw := 0; halt_fall := 0; halt_raw := 0;
      gap_extra := 0; halted := false; resumed := false;
      FOR tick IN 0 TO 8191 LOOP
        WAIT UNTIL rising_edge(clk);
        IF cpu_raw = '1' THEN raw_count := raw_count + 1; END IF;
        IF trace_bus AND offset = 0 AND
           (req /= previous_req OR wack /= previous_wack OR grant /= previous_grant) THEN
          REPORT "bus tick=" & integer'image(tick) &
            " case=" & integer'image(case_index) & " phase=" & integer'image(phase) &
            " req=" & std_logic'image(req) & " wack=" & std_logic'image(wack) &
            " grant=" & std_logic'image(grant) & " stall=" & std_logic'image(stall);
        END IF;
        IF req = '1' AND previous_req = '0' THEN
          halt_fall := last_fall; halt_raw := last_fall_raw;
          halted := true; resumed := false;
        END IF;
        IF halted AND cpu_ce = '1' AND NOT resumed THEN
          IF trace_bus AND offset = 0 THEN
            REPORT "CPU resumes: tick=" & integer'image(tick) & " phase=" & integer'image(phase);
          END IF;
          resumed := true;
        END IF;
        -- One polarity of the emulated CPU clock, one edge per two enables.
        IF cpu_ce = '1' AND phase MOD 2 = 1 THEN
          IF halted AND stall = '0' THEN
            gap_extra := raw_count - halt_raw - 2;
            IF trace_bus AND offset = 0 THEN
              REPORT "clock gap: last edge=" & integer'image(halt_fall) &
                ", first edge=" & integer'image(tick) & ", MCLK=" & integer'image(tick - halt_fall) &
                ", lost half clocks=" & integer'image(gap_extra) &
                ", sunk CPU clocks=" & real'image(
                  real(tick - halt_fall) * 2_000_000.0 / real(MCLK_HZ) - 1.0);
            END IF;
            halted := false;
          END IF;
          last_fall := tick; last_fall_raw := raw_count;
        END IF;
        previous_req := req; previous_wack := wack; previous_grant := grant;
        IF cpu_ce = '1' THEN
          active_count := active_count + 1;
          IF phase = 1 THEN
            IF pending AND to_integer(pc) = next_pc AND romc = ROMC_00 THEN
              -- Fairchild F3850 Table 3: LM/ST = L + S = 10 CPU clocks.
              ASSERT active_count - start_active = 20
                REPORT "Unexpected active LM/ST duration" SEVERITY failure;
              extra := raw_count - start_raw - 20;
              IF case_index /= 0 THEN
                ASSERT NOT halted AND extra = gap_extra
                  REPORT "Instruction overhead and clock-edge gap disagree" SEVERITY failure;
              END IF;
              shortest(case_index) := minimum(shortest(case_index), extra);
              longest(case_index) := maximum(longest(case_index), extra);
              case_index := case_index + 1; pending := false;
              EXIT WHEN case_index = 7;
            END IF;
            IF romc = ROMC_02 OR romc = ROMC_05 THEN
              ASSERT NOT pending REPORT "Overlapping memory operations" SEVERITY failure;
              ASSERT to_integer(pc) = 7 + 5 * case_index
                REPORT "Incorrect instruction stream" SEVERITY failure;
              start_raw := raw_count; start_active := active_count;
              next_pc := to_integer(pc) + 1; pending := true;
            END IF;
          END IF;
        END IF;
      END LOOP;
      ASSERT case_index = 7 REPORT "Bus wait test timed out" SEVERITY failure;
    END LOOP;
    FOR i IN 0 TO 6 LOOP
      REPORT "case " & integer'image(i) & ": extra CPU half clocks=" &
        integer'image(shortest(i)) & ".." & integer'image(longest(i));
    END LOOP;
    ASSERT shortest(0) = 0 AND longest(0) = 0
      REPORT "RES1 control must add no CPU halt" SEVERITY failure;
    -- Videobrain Unwrapped, Wait States: RAM/cart sunk cost = 4 CPU clocks,
    -- approximately +/- half a CPU clock. UV201: 4.5..7 CPU clocks.
    IF check_documented THEN
      FOR i IN 1 TO 6 LOOP
        IF i = 4 OR i = 6 THEN
          ASSERT shortest(i) >= 8 AND longest(i) <= 15
            REPORT "UV201 CPU halt differs from documented sunk cost" SEVERITY failure;
        ELSIF i /= 3 THEN
          ASSERT shortest(i) >= 7 AND longest(i) <= 9
            REPORT "RAM/cart CPU halt differs from documented sunk cost" SEVERITY failure;
        END IF;
      END LOOP;
    END IF;
    REPORT "128 reset offsets; cases: RES1 read, RAM read, cart read, RES2 read, UV201 read, RAM write, UV201 write";
    std.env.stop;
  END PROCESS;
END ARCHITECTURE;
