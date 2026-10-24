LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.base_pack.ALL;
USE work.f8_pack.ALL;

ENTITY tb_cpu_irq_chain IS
END ENTITY;

ARCHITECTURE test OF tb_cpu_irq_chain IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na, intreq : std_logic := '0';
  SIGNAL dr, dw, ext_rdata : uv8;
  SIGNAL status : uv5;
  SIGNAL romc : uv5;
  SIGNAL phase : uint4;
  SIGNAL ext_addr : unsigned(13 DOWNTO 0);
  SIGNAL int_ack : std_logic;
  SIGNAL pc0, pc1 : uv16;
  TYPE bytes_t IS ARRAY(natural RANGE <>) OF uv8;
  CONSTANT setup : bytes_t := (
    x"20", x"17", x"59", -- J = saved status, interrupts enabled
    x"20", x"15", x"04", x"20", x"88", x"05", -- K = $1588
    x"20", x"10", x"0B", -- ISAR = $10
    x"2A", x"0F", x"DE", x"1D", x"29", x"43", x"AA"
  );
  FUNCTION bootstrap RETURN bytes_t IS
    VARIABLE data : bytes_t(0 TO 127) := (OTHERS => x"2B");
    VARIABLE pos : natural := 2;
  BEGIN
    data(0) := x"70"; data(1) := x"68";
    FOR bank IN 0 TO 7 LOOP
      data(pos) := to_unsigned(16#60# + bank, 8); pos := pos + 1;
      FOR reg IN 0 TO 7 LOOP
        data(pos) := x"5D"; pos := pos + 1;
      END LOOP;
    END LOOP;
    FOR i IN setup'range LOOP
      data(pos) := setup(i); pos := pos + 1;
    END LOOP;
    RETURN data(0 TO pos - 1);
  END FUNCTION;
  CONSTANT boot : bytes_t := bootstrap;
  CONSTANT bios_read : bytes_t := (x"1A", x"16", x"B1", x"1D", x"0C");
  CONSTANT cart_call : bytes_t := (x"28", x"40", x"BC", x"70");
  CONSTANT bios_save : bytes_t := (
    x"1A", x"0A", x"67", x"6D", x"5E", x"4C", x"1F", x"0B",
    x"4D", x"04", x"4C", x"05", x"0A", x"67", x"6C", x"5D",
    x"4C", x"0B", x"1D", x"1C"
  );
  TYPE instruction_t IS RECORD
    pc : natural;
    first_romc : uv5;
    clocks : positive;
    enabled : boolean;
  END RECORD;
  TYPE instructions_t IS ARRAY(natural RANGE <>) OF instruction_t;
  -- Fairchild F3850, Table 3, printed pp. 3-22..3-24; S=4, L=6 clocks.
  -- PC is the counter after fetching the opcode, before any operand fetch.
  CONSTANT instructions : instructions_t := (
    (16#43AB#, ROMC_1C, 8, true),   -- DI
    (16#43AC#, ROMC_02, 10, false), -- LM
    (16#43AD#, ROMC_1C, 8, false),  -- OUTS 1
    (16#43AE#, ROMC_1C, 8, false),  -- LR W,J
    (16#43AF#, ROMC_12, 16, true),  -- PK
    (16#1589#, ROMC_03, 26, true),  -- PI $40BC
    (16#40BD#, ROMC_1C, 8, true),   -- DI
    (16#40BE#, ROMC_00, 4, false),
    (16#40BF#, ROMC_00, 4, false),
    (16#40C0#, ROMC_00, 4, false),
    (16#40C1#, ROMC_00, 4, false),
    (16#40C2#, ROMC_00, 4, false),
    (16#40C3#, ROMC_00, 4, false),
    (16#40C4#, ROMC_00, 4, false),
    (16#40C5#, ROMC_00, 4, false),
    (16#40C6#, ROMC_00, 4, false),
    (16#40C7#, ROMC_00, 4, false),
    (16#40C8#, ROMC_00, 4, false),
    (16#40C9#, ROMC_00, 4, false),
    (16#40CA#, ROMC_00, 4, false),
    (16#40CB#, ROMC_00, 4, false),
    (16#40CC#, ROMC_00, 4, false),
    (16#40CD#, ROMC_00, 4, false),
    (16#40CE#, ROMC_00, 4, false),
    (16#40CF#, ROMC_1C, 8, false),  -- LR W,J
    (16#40D0#, ROMC_04, 8, true)    -- POP
  );
BEGIN
  clk <= NOT clk AFTER 5 ns;
  PROCESS(all)
    VARIABLE address : natural;
  BEGIN
    address := to_integer(ext_addr);
    ext_rdata <= x"2B";
    IF address < boot'length THEN ext_rdata <= boot(address);
    ELSIF address >= 16#03AA# AND address < 16#03AA# + bios_read'length THEN
      ext_rdata <= bios_read(address - 16#03AA#);
    ELSIF address >= 16#1588# AND address < 16#1588# + cart_call'length THEN
      ext_rdata <= cart_call(address - 16#1588#);
    ELSIF address >= 16#00BC# AND address < 16#00BC# + bios_save'length THEN
      ext_rdata <= bios_save(address - 16#00BC#);
    ELSIF address = 16#0FDE# THEN ext_rdata <= x"00";
    END IF;
  END PROCESS;

  cpu : ENTITY work.f8_cpu
    PORT MAP (
      clk => clk, ce => '1', reset_na => reset_na,
      dr => dr, dw => dw, dv => OPEN, romc => romc,
      tick => OPEN, phase => phase,
      po_a_n => OPEN, pi_a_n => x"FF",
      po_b_n => OPEN, pi_b_n => x"FF", port1_wr => OPEN,
      intreq => intreq, acco => OPEN, visaro => OPEN, iozcso => status
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
      int_vector => x"0200", int_ack => int_ack,
      pc0o => pc0, pc1o => pc1, dc0o => OPEN
    );

  PROCESS
    VARIABLE elapsed, expected_start, step : natural;
    VARIABLE found_start, requested, accepted, acknowledged : boolean;
  BEGIN
    -- Request in every half-clock position from LM entry to the first
    -- interruptible instruction. The expected entry never depends on RTL.
    FOR offset IN 0 TO 319 LOOP
      reset_na <= '0';
      intreq <= '0';
      FOR i IN 1 TO 8 LOOP WAIT UNTIL falling_edge(clk); END LOOP;
      reset_na <= '1';
      elapsed := 0; expected_start := 0; step := 0;
      found_start := false; requested := false;
      accepted := false; acknowledged := false;
      FOR tick IN 0 TO 4095 LOOP
        WAIT UNTIL falling_edge(clk);
        IF NOT found_start AND phase = 1 AND pc0 = x"43AB" THEN
          found_start := true;
        END IF;
        IF found_start THEN
          IF elapsed = 16 + offset THEN
            intreq <= '1'; requested := true;
          END IF;
          -- Let combinational ROMC reflect the new request.
          WAIT FOR 1 ns;
          IF step < instructions'length AND elapsed = expected_start THEN
            ASSERT phase = 1 AND pc0 = instructions(step).pc AND
                   romc = instructions(step).first_romc
              REPORT "ROM chain instruction/timing mismatch at step " &
                integer'image(step) & ", request offset " & integer'image(offset)
              SEVERITY failure;
            ASSERT (status(4) = '1') = instructions(step).enabled
              REPORT "Incorrect interrupt control flag at step " & integer'image(step)
              SEVERITY failure;
            expected_start := expected_start + 2 * instructions(step).clocks;
            step := step + 1;
          END IF;
          IF romc = ROMC_10 AND phase = 1 THEN
            ASSERT NOT accepted AND requested AND elapsed = 336 AND pc0 = x"158C"
              REPORT "Interrupt did not replace the first permitted fetch"
              SEVERITY failure;
            accepted := true;
          END IF;
          IF int_ack = '1' THEN
            -- Event G follows all vector-delivery clocks: S + 3L from
            -- acceptance to completion, then the registered ack is visible.
            ASSERT accepted AND elapsed = 379
              REPORT "Incorrect interrupt acknowledgement timing" SEVERITY failure;
            ASSERT pc0 = x"0200" AND pc1 = x"158C"
              REPORT "Incorrect vector or saved return PC at acknowledgement"
              SEVERITY failure;
            acknowledged := true;
            EXIT;
          END IF;
          elapsed := elapsed + 1;
        END IF;
      END LOOP;
      ASSERT acknowledged AND step = instructions'length
        REPORT "ROM chain test timed out" SEVERITY failure;
    END LOOP;
    REPORT "ROM IRQ chain passed: 320 request phases, entry at 168 CPU clocks";
    REPORT "LM-entry request to ack: 181.5 clocks = 90.75 us at 2 MHz, without bus waits";
    std.env.stop;
  END PROCESS;
END ARCHITECTURE;
