--------------------------------------------------------------------------------
-- VideoBrain UV201 - Y interrupt comparator
--------------------------------------------------------------------------------
-- US4232374A: equality asserts the interrupt while INT=1 and FRZ=0.
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY work;
USE work.base_pack.ALL;

ENTITY uv201_yint IS
  PORT (
    clk      : IN  std_logic;
    reset_na : IN  std_logic;

    cur_vpos       : IN unsigned(8 DOWNTO 0);

    y_int     : IN uv8;
    yint_ho   : IN std_logic;
    cmd_int   : IN std_logic;
    cmd_frz   : IN std_logic;

    irq_level : OUT std_logic
    );
END ENTITY uv201_yint;

ARCHITECTURE rtl OF uv201_yint IS
  SIGNAL irq_l : std_logic := '0';
BEGIN

  PROCESS (clk, reset_na) IS
    VARIABLE target_y : unsigned(8 DOWNTO 0);
  BEGIN
    IF reset_na = '0' THEN
      irq_l <= '0';

    ELSIF rising_edge(clk) THEN
      irq_l <= '0';

      target_y := unsigned(yint_ho & y_int);
      IF cmd_int = '1' AND cmd_frz = '0' AND cur_vpos = target_y THEN
        irq_l <= '1';
      END IF;
    END IF;
  END PROCESS;

  irq_level <= irq_l;

END ARCHITECTURE rtl;
