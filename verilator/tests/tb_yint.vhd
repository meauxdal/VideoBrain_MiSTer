LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.env.ALL;

ENTITY tb_yint IS
END ENTITY;

ARCHITECTURE test OF tb_yint IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na, enable, freeze, irq : std_logic := '0';
  SIGNAL current_y : unsigned(8 DOWNTO 0) := to_unsigned(261, 9);
  SIGNAL y_int : unsigned(7 DOWNTO 0) := x"06";
BEGIN
  clk <= NOT clk AFTER 5 ns;
  dut : ENTITY work.uv201_yint
    PORT MAP (clk => clk, reset_na => reset_na, cur_vpos => current_y,
              y_int => y_int, yint_ho => '1', cmd_int => enable,
              cmd_frz => freeze, irq_level => irq);

  PROCESS
  BEGIN
    WAIT FOR 20 ns;
    reset_na <= '1';
    enable <= '1';
    WAIT FOR 20 ns;
    ASSERT irq = '0' REPORT "IRQ before Y262" SEVERITY failure;
    current_y <= to_unsigned(262, 9);
    WAIT FOR 20 ns;
    ASSERT irq = '1' REPORT "Missing IRQ during final HBLANK" SEVERITY failure;
    WAIT FOR 20 ns;
    ASSERT irq = '1' REPORT "IRQ must hold while Y matches" SEVERITY failure;
    current_y <= to_unsigned(0, 9);
    WAIT FOR 20 ns;
    ASSERT irq = '0' REPORT "IRQ survived Y reset" SEVERITY failure;
    current_y <= to_unsigned(262, 9);
    freeze <= '1';
    WAIT FOR 20 ns;
    ASSERT irq = '0' REPORT "IRQ during joystick capture" SEVERITY failure;
    freeze <= '0';
    WAIT FOR 20 ns;
    ASSERT irq = '1' REPORT "Missing IRQ on unfreeze" SEVERITY failure;
    enable <= '0';
    WAIT FOR 20 ns;
    ASSERT irq = '0' REPORT "IRQ while disabled" SEVERITY failure;
    REPORT "Y interrupt test passed";
    stop;
    WAIT;
  END PROCESS;
END ARCHITECTURE;
