LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY uv202_cpu_gate IS
  PORT (
    clk, reset_na : IN std_logic;
    cpu_raw, cpu_sample : IN std_logic;
    cpu_req, cpu_wack : IN std_logic;
    cpu_ce, cpu_stall : OUT std_logic
  );
END ENTITY;

ARCHITECTURE rtl OF uv202_cpu_gate IS
  SIGNAL ready : std_logic := '1';
  SIGNAL stopped : std_logic := '0';
  SIGNAL previous_req : std_logic := '0';
BEGIN
  -- Board U31A samples /WACK on oscillator rising edges. U30B toggles
  -- XTLY on falling edges only when U31A.Q AND U30A./Q is high (U40A).
  PROCESS(clk, reset_na) IS
  BEGIN
    IF reset_na = '0' THEN
      ready <= '1';
      stopped <= '0';
      previous_req <= '0';
    ELSIF rising_edge(clk) THEN
      previous_req <= cpu_req;
      IF cpu_sample = '1' THEN ready <= NOT cpu_wack; END IF;
      -- U30A: J=1, K=0, clock=/request, /CLR=U31A.Q AND /reset.
      IF ready = '0' OR (cpu_sample = '1' AND cpu_wack = '1') THEN
        stopped <= '0';
      ELSIF cpu_req = '1' AND previous_req = '0' THEN
        stopped <= '1';
      END IF;
    END IF;
  END PROCESS;

  -- Include a request arriving on the current MCLK before a CPU edge.
  cpu_stall <= NOT ready OR stopped OR (cpu_req AND NOT previous_req);
  cpu_ce <= cpu_raw AND ready AND NOT stopped AND NOT (cpu_req AND NOT previous_req);
END ARCHITECTURE;
