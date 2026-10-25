LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.base_pack.ALL;
USE work.f8_pack.ALL;

ENTITY tb_cpu_reset IS END ENTITY;

ARCHITECTURE test OF tb_cpu_reset IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na : std_logic := '0';
  SIGNAL ce, port1_wr : std_logic;
  SIGNAL dr, dw, rom_data, port_a, port_b : uv8;
  SIGNAL romc : uv5;
  SIGNAL phase : uint4;
  SIGNAL addr : unsigned(13 DOWNTO 0);
  SIGNAL pc : uv16;
  TYPE program_t IS ARRAY(natural RANGE <>) OF uv8;
  CONSTANT program : program_t := (
    x"20", x"55", x"B0", -- LI 55; OUTS 0
    x"20", x"A3", x"B1", -- LI A3; OUTS 1
    x"90", x"FF"         -- BR to itself (short and long cycles)
  );
BEGIN
  clk <= NOT clk AFTER 5 ns;
  rom_data <= program(to_integer(addr)) WHEN addr < program'length ELSE x"2B";

  clockgen : ENTITY work.uv202_clkgen
    PORT MAP (clk => clk, reset_na => reset_na, mclk_ena => OPEN,
      brclk_ena => OPEN, cpu_ena => ce, cpu_sample => OPEN, brclk_phase => OPEN);
  cpu : ENTITY work.f8_cpu
    PORT MAP (clk => clk, ce => ce, reset_na => reset_na,
      dr => dr, dw => dw, dv => OPEN, romc => romc, tick => OPEN, phase => phase,
      po_a_n => port_a, pi_a_n => port_a, po_b_n => port_b, pi_b_n => port_b,
      port1_wr => port1_wr, intreq => '0', acco => OPEN, visaro => OPEN, iozcso => OPEN);
  busif : ENTITY work.f8_busif
    PORT MAP (clk => clk, ce => ce, reset_na => reset_na,
      dw => dw, dr => dr, dv => OPEN, romc => romc, tick => '0', phase => phase,
      ext_addr => addr, ext_rd => OPEN, ext_wr => OPEN, ext_wdata => OPEN,
      ext_rdata => rom_data, ext_req => OPEN, ext_class => OPEN, ext_grant => '1',
      io_addr => OPEN, io_rd => OPEN, io_wr => OPEN, io_wdata => OPEN,
      io_rdata => x"00", int_vector => x"0000", int_ack => OPEN,
      pc0o => pc, pc1o => OPEN, dc0o => OPEN);

  PROCESS
    PROCEDURE reset_machine IS
    BEGIN
      reset_na <= '0';
      -- The actual clock generator disables ce throughout reset. Checking
      -- only inside IF ce used to leave the CPU running its old microcode.
      FOR i IN 1 TO 8 LOOP
        WAIT UNTIL falling_edge(clk);
        ASSERT ce = '0' REPORT "Clock enable active during reset" SEVERITY failure;
        ASSERT phase = 0 AND port_a = x"FF" AND port_b = x"FF" AND port1_wr = '0'
          REPORT "Reset with ce=0 did not reset CPU phase and output ports" SEVERITY failure;
      END LOOP;
      reset_na <= '1';
      LOOP
        WAIT UNTIL falling_edge(clk);
        EXIT WHEN romc = ROMC_00 AND phase = 1;
      END LOOP;
      ASSERT pc = 0 REPORT "CPU did not restart at BIOS entry" SEVERITY failure;
      LOOP
        WAIT UNTIL falling_edge(clk);
        EXIT WHEN port_a = x"AA" AND port_b = x"5C";
      END LOOP;
    END PROCEDURE;
  BEGIN
    reset_machine;
    FOR target_phase IN 0 TO 11 LOOP
      LOOP
        WAIT UNTIL falling_edge(clk);
        EXIT WHEN phase = target_phase AND ce = '0';
      END LOOP;
      reset_machine;
    END LOOP;
    REPORT "CPU reset with disabled clock passed at all 12 phases";
    std.env.stop;
    WAIT;
  END PROCESS;
  PROCESS
  BEGIN
    WAIT FOR 1 ms;
    ASSERT false REPORT "CPU reset test timed out" SEVERITY failure;
  END PROCESS;
END ARCHITECTURE;
