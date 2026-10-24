-- Reference: MAME machine/f3853.cpp.
-- Timer/IRQ details: Mostek 1978 3870/F8 Data Book, pp.169-172;
-- F3852/F3853 timer block diagram, Fig.6 (first clock after two Phi periods).
-- Memory addressing and priority daisy chaining are omitted (single SMI).

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY work;
USE work.base_pack.ALL;

ENTITY f3853 IS
  GENERIC (
    PRESCALE : positive := 31
    );
  PORT (
    clk      : IN std_logic;
    reset_na : IN std_logic;
    ce       : IN std_logic;

    io_addr  : IN  uv8;
    io_rd    : IN  std_logic;
    io_wr    : IN  std_logic;
    io_wdata : IN  uv8;
    io_rdata : OUT uv8;
    io_sel   : OUT std_logic;

    ext_int  : IN std_logic;

    int_req    : OUT std_logic;
    int_vector : OUT uv16;
    int_ack    : IN  std_logic
    );
END ENTITY f3853;

ARCHITECTURE rtl OF f3853 IS

  SIGNAL vec : uv16 := (OTHERS => '0');

  SIGNAL ext_enable   : std_logic := '0';
  SIGNAL timer_enable : std_logic := '0';

  SIGNAL ext_request   : std_logic := '0';
  SIGNAL timer_pending : std_logic := '0';
  SIGNAL ext_int_l : std_logic := '0';

  SIGNAL timer_val   : uv8 := x"FF";
  SIGNAL timer_run   : std_logic := '0';
  SIGNAL prescale_ct : natural RANGE 0 TO PRESCALE - 1 := 0;
  SIGNAL load_delay : natural RANGE 0 TO 2 := 0;

  SIGNAL sel : std_logic;

BEGIN

  sel    <= '1' WHEN io_addr(7 DOWNTO 2) = "000011" ELSE '0';
  io_sel <= sel;

  io_rdata <= vec(15 DOWNTO 8) WHEN sel = '1' AND io_addr(1 DOWNTO 0) = "00" ELSE
              vec(7 DOWNTO 0)  WHEN sel = '1' AND io_addr(1 DOWNTO 0) = "01" ELSE
              (OTHERS => '0');

  int_req <= ext_request OR (timer_pending AND timer_enable);

  int_vector <= vec OR x"0080"  WHEN ext_enable = '1' ELSE
                vec AND x"FF7F";

  PROCESS (clk, reset_na) IS
    VARIABLE new_ext : std_logic;
    VARIABLE advance_timer : boolean;
    VARIABLE next_timer : uv8;
  BEGIN
    IF reset_na = '0' THEN
      vec          <= (OTHERS => '0');
      ext_enable   <= '0';
      timer_enable <= '0';
      ext_request  <= '0';
      timer_pending <= '0';
      ext_int_l    <= '0';
      timer_val    <= x"FF";
      timer_run    <= '0';
      prescale_ct  <= 0;
      load_delay   <= 0;

    ELSIF rising_edge(clk) THEN

      new_ext := ext_int;
      IF ext_int_l = '0' AND new_ext = '1' AND ext_enable = '1' THEN
        ext_request <= '1';
      END IF;
      ext_int_l <= new_ext;

      advance_timer := false;
      IF ce = '1' AND timer_run = '1' THEN
        IF load_delay /= 0 THEN
          load_delay <= load_delay - 1;
          advance_timer := load_delay = 1;
        ELSIF prescale_ct = PRESCALE - 1 THEN
          prescale_ct <= 0;
          advance_timer := true;
        ELSE
          prescale_ct <= prescale_ct + 1;
        END IF;
      END IF;
      IF advance_timer THEN
        next_timer := timer_val(6 DOWNTO 0) &
                      NOT (timer_val(7) XOR timer_val(5) XOR timer_val(4) XOR timer_val(3));
        timer_val <= next_timer;
        IF next_timer = x"FE" THEN
          -- Timeouts latch even while external interrupts (or none) are selected.
          timer_pending <= '1';
        END IF;
      END IF;

      IF int_ack = '1' THEN
        IF timer_enable = '1' THEN
          timer_pending <= '0';
        ELSE
          ext_request <= '0';
        END IF;
      END IF;

      -- Loads take priority over an old timeout/prescaler tick on the same edge.
      IF io_wr = '1' AND sel = '1' THEN
        CASE to_integer(io_addr(1 DOWNTO 0)) IS
          WHEN 0 => vec(15 DOWNTO 8) <= io_wdata;
          WHEN 1 => vec(7 DOWNTO 0)  <= io_wdata;
          WHEN 2 =>
            -- MK3853 data book, p. 172: control writes clear external requests.
            ext_request  <= '0';
            ext_enable   <= to_std_logic(io_wdata(1 DOWNTO 0) = "01");
            timer_enable <= to_std_logic(io_wdata(1 DOWNTO 0) = "11");
          WHEN OTHERS =>
            timer_pending <= '0';
            timer_val   <= io_wdata;
            timer_run   <= to_std_logic(io_wdata /= x"FF");
            prescale_ct <= 0;
            load_delay  <= 2;
        END CASE;
      END IF;

    END IF;
  END PROCESS;

END ARCHITECTURE rtl;
