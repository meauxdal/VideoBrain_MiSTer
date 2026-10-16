-- MK3870 data book, timer and interrupt control (pages 7-13).
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY work;
USE work.base_pack.ALL;

ENTITY f3870_timer IS
  PORT (
    clk      : IN std_logic;
    reset_na : IN std_logic;
    ce_phi   : IN std_logic;
    io_addr  : IN uv8;
    io_wr    : IN std_logic;
    io_wdata : IN uv8;
    io_rdata : OUT uv8;
    ext_int  : IN std_logic;
    int_req    : OUT std_logic;
    int_vector : OUT uv16;
    int_start  : IN std_logic;
    int_ack    : IN std_logic
    );
END ENTITY f3870_timer;

ARCHITECTURE rtl OF f3870_timer IS
  TYPE prescales_t IS ARRAY (0 TO 7) OF positive RANGE 1 TO 200;
  CONSTANT PRESCALES : prescales_t := (1, 2, 5, 10, 20, 40, 100, 200);
  SIGNAL control : uv8 := x"00";
  SIGNAL counter, modulo_n : uv8 := x"00";
  SIGNAL prescale_ct : natural RANGE 0 TO 199 := 0;
  SIGNAL timer_pending, ext_pending : std_logic := '0';
  SIGNAL ext_l : std_logic := '1';
  SIGNAL selected_timer : std_logic := '1';
BEGIN
  io_rdata <= unsigned'(ext_int & "0000000") WHEN io_addr = 6 ELSE
              counter WHEN io_addr = 7 ELSE x"00";
  int_req <= (timer_pending AND control(1)) OR ext_pending;
  int_vector <= x"0020" WHEN selected_timer = '1' ELSE x"00A0";

  PROCESS (clk, reset_na) IS
    VARIABLE count_v, leading_v, trailing_v : boolean;
    VARIABLE divisor_v : positive RANGE 1 TO 200;
  BEGIN
    IF reset_na = '0' THEN
      control <= x"00";
      counter <= x"00";
      modulo_n <= x"00";
      prescale_ct <= 0;
      timer_pending <= '0';
      ext_pending <= '0';
      ext_l <= '1';
      selected_timer <= '1';
    ELSIF rising_edge(clk) THEN
      leading_v := ext_l /= ext_int AND ext_int = control(2);
      trailing_v := ext_l /= ext_int AND ext_int /= control(2);
      ext_l <= ext_int;

      IF control(0) = '1' AND
         ((control(4) = '0' AND leading_v) OR
          (control(4) = '1' AND trailing_v)) THEN
        ext_pending <= '1';
      END IF;

      count_v := FALSE;
      divisor_v := PRESCALES(to_integer(control(7 DOWNTO 5)));
      IF control(3) = '0' OR
         (control(4) = '1' AND ext_int /= control(2)) THEN
        prescale_ct <= 0;
      ELSIF control(7 DOWNTO 5) = 0 THEN
        IF control(4) = '0' THEN count_v := leading_v; END IF;
      ELSIF ce_phi = '1' THEN
        IF prescale_ct >= divisor_v - 1 THEN
          prescale_ct <= 0;
          count_v := TRUE;
        ELSE
          prescale_ct <= prescale_ct + 1;
        END IF;
      END IF;

      IF count_v THEN
        IF counter = 1 THEN
          counter <= modulo_n;
          timer_pending <= '1';
        ELSE
          counter <= counter - 1;
        END IF;
      END IF;

      -- Hold the selected vector from ROMC 0F through ROMC 13.
      IF int_start = '1' THEN
        selected_timer <= timer_pending AND control(1);
      END IF;
      IF int_ack = '1' THEN
        IF selected_timer = '1' THEN
          timer_pending <= '0';
        ELSE
          ext_pending <= '0';
        END IF;
      END IF;

      IF io_wr = '1' THEN
        CASE to_integer(io_addr) IS
          WHEN 6 =>
            control <= io_wdata;
            IF io_wdata(0) = '0' THEN ext_pending <= '0'; END IF;
            IF io_wdata(3) = '0' THEN prescale_ct <= 0; END IF;
          WHEN 7 =>
            counter <= io_wdata;
            modulo_n <= io_wdata;
            prescale_ct <= 0;
            timer_pending <= '0';
          WHEN OTHERS => NULL;
        END CASE;
      END IF;
    END IF;
  END PROCESS;
END ARCHITECTURE rtl;
