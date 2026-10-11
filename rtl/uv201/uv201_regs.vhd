
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY work;
USE work.base_pack.ALL;
USE work.uv202_pack.ALL;

ENTITY uv201_regs IS
  PORT (
    clk      : IN  std_logic;
    reset_na : IN  std_logic;

    reg_addr  : IN  uv8;
    reg_we    : IN  std_logic;
    reg_wdata : IN  uv8;
    reg_rdata : OUT uv8;

    cur_field : IN  std_logic;
    cur_vpos  : IN  unsigned(8 DOWNTO 0);

    capture_stb : IN  std_logic;
    capture_x   : IN  uv8;
    capture_y   : IN  unsigned(8 DOWNTO 0);

    o_x_zm  : OUT std_logic;
    o_frz   : OUT std_logic;
    o_enb   : OUT std_logic;
    o_int   : OUT std_logic;
    o_kbd   : OUT std_logic;
    o_y_zm  : OUT std_logic;
    o_a_b   : OUT std_logic;

    y_int     : OUT uv8;
    o_yint_ho : OUT std_logic;

    final_mod  : OUT uv8;
    background : OUT uv8;

    obj_addr  : IN  uv8;
    obj_rdata : OUT uv8
    );
END ENTITY uv201_regs;

ARCHITECTURE rtl OF uv201_regs IS

  TYPE obj_ram_t IS ARRAY (0 TO 16#8F#) OF uv8;
  SIGNAL obj_ram : obj_ram_t := (OTHERS => (OTHERS => '0'));

  SIGNAL r_y_int : uv8 := (OTHERS => '0');
  SIGNAL r_fmod  : uv8 := (OTHERS => '0');
  SIGNAL r_bg    : uv8 := (OTHERS => '0');
  SIGNAL r_cmd   : uv8 := (OTHERS => '0');

  SIGNAL r_freeze_x : uv8 := (OTHERS => '0');
  SIGNAL r_freeze_y : unsigned(8 DOWNTO 0) := (OTHERS => '0');

  CONSTANT CMD_X_ZM_BIT    : natural := CMD_X_ZM;
  CONSTANT CMD_FRZ_BIT     : natural := CMD_FRZ;
  CONSTANT CMD_ENB_BIT     : natural := CMD_ENB;
  CONSTANT CMD_INT_BIT     : natural := CMD_INT;
  CONSTANT CMD_KBD_BIT     : natural := CMD_KBD;
  CONSTANT CMD_Y_ZM_BIT    : natural := CMD_Y_ZM;
  CONSTANT CMD_A_B_BIT     : natural := CMD_A_B;
  CONSTANT CMD_YINT_HO_BIT : natural := CMD_YINT_HO;

BEGIN

  PROCESS (clk, reset_na) IS
  BEGIN
    IF reset_na = '0' THEN
      r_y_int    <= (OTHERS => '0');
      r_fmod     <= (OTHERS => '0');
      r_bg       <= (OTHERS => '0');
      r_cmd      <= (OTHERS => '0');
      r_freeze_x <= (OTHERS => '0');
      r_freeze_y <= (OTHERS => '0');
      obj_ram    <= (OTHERS => (OTHERS => '0'));

    ELSIF rising_edge(clk) THEN

      IF reg_we = '1' THEN
        IF unsigned(reg_addr) = to_unsigned(REG_Y_INTERRUPT, 8) THEN
          r_y_int <= reg_wdata;
        ELSIF unsigned(reg_addr) = to_unsigned(REG_FINAL_MOD, 8) THEN
          r_fmod <= "000" & reg_wdata(4 DOWNTO 0);
        ELSIF unsigned(reg_addr) = to_unsigned(REG_BACKGROUND, 8) THEN
          r_bg <= "000" & reg_wdata(4 DOWNTO 0);
        ELSIF unsigned(reg_addr) = to_unsigned(REG_COMMAND, 8) THEN
          r_cmd <= reg_wdata;
        ELSIF unsigned(reg_addr) <= to_unsigned(16#8F#, 8) THEN
          obj_ram(to_integer(unsigned(reg_addr))) <= reg_wdata;
        END IF;
      END IF;

      -- US4232374A, F8/F9/FA: FRZ=1 captures X/Y on a negative interrupt edge.
      IF capture_stb = '1' AND r_cmd(CMD_FRZ_BIT) = '1' THEN
        r_freeze_x <= capture_x;
        r_freeze_y <= capture_y;
      END IF;

    END IF;
  END PROCESS;

  PROCESS (reg_addr, r_freeze_x, r_freeze_y, cur_field, cur_vpos, obj_ram) IS
  BEGIN
    IF unsigned(reg_addr) = to_unsigned(REG_X_FREEZE, 8) THEN
      reg_rdata <= r_freeze_x;

    ELSIF unsigned(reg_addr) = to_unsigned(REG_Y_FREEZE_LO, 8) THEN
      reg_rdata <= r_freeze_y(7 DOWNTO 0);

    ELSIF unsigned(reg_addr) = to_unsigned(REG_Y_FREEZE_HI, 8) THEN
      reg_rdata <= cur_field & unsigned'("00000") & cur_vpos(8) & r_freeze_y(8);

    ELSIF unsigned(reg_addr) = to_unsigned(REG_CURRENT_Y_LO, 8) THEN
      reg_rdata <= cur_vpos(7 DOWNTO 0);

    ELSIF unsigned(reg_addr) <= to_unsigned(16#8F#, 8) THEN
      reg_rdata <= obj_ram(to_integer(unsigned(reg_addr)));

    ELSE
      reg_rdata <= (OTHERS => '1');
    END IF;
  END PROCESS;

  obj_rdata <= obj_ram(to_integer(unsigned(obj_addr)))
                 WHEN unsigned(obj_addr) <= to_unsigned(16#8F#, 8)
                 ELSE (OTHERS => '1');

  o_x_zm    <= r_cmd(CMD_X_ZM_BIT);
  o_frz     <= r_cmd(CMD_FRZ_BIT);
  o_enb     <= r_cmd(CMD_ENB_BIT);
  o_int     <= r_cmd(CMD_INT_BIT);
  o_kbd     <= r_cmd(CMD_KBD_BIT);
  o_y_zm    <= r_cmd(CMD_Y_ZM_BIT);
  o_a_b     <= r_cmd(CMD_A_B_BIT);
  o_yint_ho <= r_cmd(CMD_YINT_HO_BIT);
  y_int     <= r_y_int;
  final_mod <= r_fmod;
  background <= r_bg;

END ARCHITECTURE rtl;
