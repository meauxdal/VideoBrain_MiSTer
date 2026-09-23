LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.base_pack.ALL;

ENTITY tb_cpu_clock IS
END ENTITY;

ARCHITECTURE test OF tb_cpu_clock IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na : std_logic := '0';
  SIGNAL cpu_ena : std_logic;
  SIGNAL phase : uint4;
BEGIN
  clk <= NOT clk AFTER 5 ns;
  reset_na <= '1' AFTER 100 ns;

  clocks : ENTITY work.uv202_clkgen
    PORT MAP (
      clk => clk, reset_na => reset_na,
      mclk_ena => OPEN, brclk_ena => OPEN, brclk_phase => OPEN,
      cpu_ena => cpu_ena
    );

  cpu : ENTITY work.f8_cpu
    PORT MAP (
      clk => clk, reset_na => reset_na, ce => cpu_ena,
      dr => x"70", dw => OPEN, dv => OPEN,
      romc => OPEN, tick => OPEN, phase => phase,
      po_a_n => OPEN, pi_a_n => x"FF",
      po_b_n => OPEN, pi_b_n => x"FF",
      intreq => '0', acco => OPEN, visaro => OPEN, iozcso => OPEN
    );

  PROCESS
    VARIABLE previous_cycle : time := 0 ns;
    VARIABLE checked : natural := 0;
  BEGIN
    WAIT UNTIL rising_edge(clk);
    -- LIS 0 repeats after reset; each short cycle is four CPU clocks.
    IF now > 2 us AND cpu_ena = '1' AND phase = 0 THEN
      IF previous_cycle /= 0 ns THEN
        ASSERT now - previous_cycle = 280 ns
          REPORT "F8 short cycle must take 28 master clocks" SEVERITY failure;
        checked := checked + 1;
      END IF;
      previous_cycle := now;
      IF checked = 8 THEN
        REPORT "CPU clock test passed";
        std.env.stop;
      END IF;
    END IF;
    ASSERT now < 10 us REPORT "CPU clock test timed out" SEVERITY failure;
  END PROCESS;
END ARCHITECTURE;
