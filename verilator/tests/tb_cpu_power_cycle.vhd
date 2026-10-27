LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.base_pack.ALL;
USE work.f8_pack.ALL;

ENTITY tb_cpu_power_cycle IS END ENTITY;

ARCHITECTURE test OF tb_cpu_power_cycle IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na : std_logic := '0';
  SIGNAL ce, port1_wr : std_logic;
  SIGNAL power_cycle : std_logic := '0';
  SIGNAL dr, dw, rom_data, port_a, port_b : uv8;
  SIGNAL romc : uv5;
  SIGNAL phase : uint4;
  SIGNAL addr : unsigned(13 DOWNTO 0);
  SIGNAL pc : uv16;
  TYPE program_t IS ARRAY(natural RANGE <>) OF uv8;
  SIGNAL program : program_t(0 TO 511) := (OTHERS => x"2B");
BEGIN
  clk <= NOT clk AFTER 5 ns;
  rom_data <= program(to_integer(addr)) WHEN addr < program'length ELSE x"2B";

  clockgen : ENTITY work.uv202_clkgen
    PORT MAP (clk => clk, reset_na => reset_na, mclk_ena => OPEN,
      brclk_ena => OPEN, cpu_ena => ce, cpu_sample => OPEN, brclk_phase => OPEN);
  cpu : ENTITY work.f8_cpu
    PORT MAP (clk => clk, ce => ce, reset_na => reset_na,
      power_cycle => power_cycle,
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
    VARIABLE image : program_t(0 TO 511);
    VARIABLE n : natural;

    PROCEDURE emit(value : natural) IS
    BEGIN
      image(n) := to_unsigned(value, 8);
      n := n + 1;
    END PROCEDURE;

    PROCEDURE output_byte(expected : natural) IS
    BEGIN
      LOOP
        WAIT UNTIL falling_edge(clk);
        EXIT WHEN port1_wr = '1';
      END LOOP;
      ASSERT port_b = NOT to_unsigned(expected, 8)
        REPORT "CPU power state mismatch, expected " & integer'image(expected)
        SEVERITY failure;
      WAIT UNTIL falling_edge(clk);
    END PROCEDURE;

    PROCEDURE check_state(cold : boolean) IS
    BEGIN
      reset_na <= '0';
      WAIT UNTIL falling_edge(clk);
      image := (OTHERS => x"2B"); n := 0;
      emit(16#B1#); -- OUTS 1: accumulator retained by MASTER CONTROL.
      emit(16#0A#); emit(16#B1#); -- LR A,IS; OUTS 1.
      FOR r IN 0 TO 63 LOOP
        emit(16#20#); emit(r); emit(16#0B#); -- LI r; LR IS,A.
        emit(16#4C#); emit(16#B1#); -- LR A,(IS); OUTS 1.
      END LOOP;
      emit(16#90#); emit(16#FF#);
      program <= image;
      IF cold THEN
        power_cycle <= '1';
        WAIT UNTIL falling_edge(clk);
        power_cycle <= '0';
        FOR i IN 0 TO 1023 LOOP WAIT UNTIL falling_edge(clk); END LOOP;
      ELSE
        FOR i IN 0 TO 7 LOOP WAIT UNTIL falling_edge(clk); END LOOP;
      END IF;
      reset_na <= '1';
      IF cold THEN output_byte(0); output_byte(0);
      ELSE output_byte(16#5A#); output_byte(16#26#); END IF;
      FOR r IN 0 TO 63 LOOP
        IF cold THEN output_byte(0); ELSE output_byte(r + 1); END IF;
      END LOOP;
    END PROCEDURE;
  BEGIN
    image := (OTHERS => x"2B"); n := 0;
    FOR r IN 0 TO 63 LOOP
      emit(16#20#); emit(r); emit(16#0B#);
      emit(16#20#); emit(r + 1); emit(16#5C#); -- LI value; LR (IS),A.
    END LOOP;
    emit(16#20#); emit(16#26#); emit(16#0B#);
    emit(16#20#); emit(16#5A#); emit(16#B1#);
    emit(16#90#); emit(16#FF#);
    program <= image;
    FOR i IN 0 TO 7 LOOP WAIT UNTIL falling_edge(clk); END LOOP;
    reset_na <= '1';
    output_byte(16#5A#);
    check_state(false);
    check_state(true);
    REPORT "CPU warm retention and power-cycle clearing passed for all 64 scratch registers";
    std.env.stop;
    WAIT;
  END PROCESS;
  PROCESS
  BEGIN
    WAIT FOR 10 ms;
    ASSERT false REPORT "CPU power-cycle test timed out" SEVERITY failure;
  END PROCESS;
END ARCHITECTURE;
