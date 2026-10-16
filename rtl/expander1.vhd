LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY work;
USE work.base_pack.ALL;
USE work.f8_pack.ALL;

ENTITY expander1 IS
  GENERIC (CLK_DIV_MCLK : positive := 1);
  PORT (
    clk      : IN std_logic;
    reset_na : IN std_logic;
    host_data_n  : IN std_logic;
    host_clock_n : IN std_logic;
    data_n       : OUT std_logic;
    clock_n      : OUT std_logic;
    interrupt_n  : OUT std_logic;
    record_data  : OUT std_logic;
    record_enable : OUT std_logic;
    dl_addr  : IN unsigned(15 DOWNTO 0);
    dl_data  : IN uv8;
    dl_wr    : IN std_logic;
    dl_index : IN uv8
    );
END ENTITY expander1;

ARCHITECTURE rtl OF expander1 IS
  TYPE rom_t IS ARRAY (0 TO 2047) OF uv8;
  SIGNAL rom : rom_t := (OTHERS => (OTHERS => '0'));
  SIGNAL loaded : std_logic := '0';
  SIGNAL cpu_reset_na : std_logic;
  SIGNAL divider : natural RANGE 0 TO 4 * CLK_DIV_MCLK - 1 := 0;
  SIGNAL ce : std_logic;
  SIGNAL port1_wr : std_logic;
  SIGNAL port1_ready : std_logic := '0';
  SIGNAL dr, dw : uv8;
  SIGNAL romc : uv5;
  SIGNAL tick : std_logic;
  SIGNAL phase : uint4;
  SIGNAL po_a_n, pi_a_n, po_b_n, pi_b_n : uv8;
  SIGNAL addr : unsigned(13 DOWNTO 0);
  SIGNAL rdata : uv8;
  SIGNAL io_addr, io_wdata, io_rdata : uv8;
  SIGNAL io_wr : std_logic;
  SIGNAL port4, port5 : uv8 := (OTHERS => '0');
  SIGNAL ce_phi, int_req, int_start, int_ack : std_logic;
  SIGNAL timer_rdata : uv8;
  SIGNAL int_vector : uv16;
BEGIN
  cpu_reset_na <= reset_na AND loaded;
  -- The board's 3.58 MHz crystal clocks the 3870's internal divide by two.
  ce <= '1' WHEN cpu_reset_na = '0' OR
                 divider = 4 * CLK_DIV_MCLK - 1 ELSE '0';

  PROCESS (clk, cpu_reset_na) IS
  BEGIN
    IF cpu_reset_na = '0' THEN
      divider <= 0;
      port4 <= (OTHERS => '0');
      port5 <= (OTHERS => '0');
      port1_ready <= '0';
    ELSIF rising_edge(clk) THEN
      IF ce = '1' THEN divider <= 0; ELSE divider <= divider + 1; END IF;
      IF port1_wr = '1' THEN port1_ready <= '1'; END IF;
      IF io_wr = '1' THEN
        CASE to_integer(io_addr) IS
          WHEN 4 => port4 <= io_wdata;
          WHEN 5 => port5 <= io_wdata;
          WHEN OTHERS => NULL;
        END CASE;
      END IF;
    END IF;
  END PROCESS;

  PROCESS (clk) IS
  BEGIN
    IF rising_edge(clk) THEN
      rdata <= rom(to_integer(addr(10 DOWNTO 0)));
      IF dl_wr = '1' AND dl_index = 3 THEN
        IF dl_addr <= x"07FF" THEN
          rom(to_integer(dl_addr(10 DOWNTO 0))) <= dl_data;
          IF dl_addr = x"0000" THEN loaded <= '0'; END IF;
          IF dl_addr = x"07FF" THEN loaded <= '1'; END IF;
        ELSE
          loaded <= '0';
        END IF;
      END IF;
    END IF;
  END PROCESS;

  -- Transfer Set 1, Image (33): P1.0=data, P1.7=clock, P1.1=host IRQ.
  pi_b_n <= po_b_n AND unsigned'(host_clock_n & "111111" & host_data_n);
  data_n <= po_b_n(0) WHEN port1_ready = '1' ELSE '1';
  clock_n <= po_b_n(7) WHEN port1_ready = '1' ELSE '1';
  interrupt_n <= po_b_n(1) WHEN port1_ready = '1' ELSE '1';
  -- U04.4 drives P0.2 from inverted P0.3; U04.2/12 feed R13/R14.
  pi_a_n <= po_a_n(7 DOWNTO 3) &
            (po_a_n(2) AND NOT po_a_n(3)) & po_a_n(1 DOWNTO 0);
  record_data <= NOT pi_a_n(2) WHEN port1_ready = '1' ELSE '0';
  -- P0.1 low releases U07.6, lighting the U08 remote-control optocoupler.
  record_enable <= NOT po_a_n(1) WHEN port1_ready = '1' ELSE '0';
  io_rdata <= port4 WHEN io_addr = 4 ELSE port5 WHEN io_addr = 5 ELSE timer_rdata;

  ce_phi <= ce WHEN phase MOD 2 = 1 ELSE '0';
  int_ack <= '1' WHEN ce = '1' AND romc = ROMC_13 AND phase = 6 ELSE '0';

  -- TODO: Connect EXT INT and parallel ports to the peripheral circuitry.
  u_timer : ENTITY work.f3870_timer
    PORT MAP (
      clk => clk, reset_na => cpu_reset_na, ce_phi => ce_phi,
      io_addr => io_addr, io_wr => io_wr, io_wdata => io_wdata,
      io_rdata => timer_rdata, ext_int => '1', int_req => int_req,
      int_vector => int_vector, int_start => int_start, int_ack => int_ack
      );

  u_cpu : ENTITY work.f8_cpu
    PORT MAP (
      dr => dr, dw => dw, dv => OPEN, romc => romc, tick => tick,
      phase => phase, po_a_n => po_a_n, pi_a_n => pi_a_n,
      po_b_n => po_b_n, pi_b_n => pi_b_n, port1_wr => port1_wr,
      clk => clk, ce => ce, reset_na => cpu_reset_na, intreq => int_req,
      acco => OPEN, visaro => OPEN, iozcso => OPEN
      );

  u_busif : ENTITY work.f8_busif
    PORT MAP (
      dw => dw, dr => dr, dv => OPEN, romc => romc, tick => tick,
      phase => phase, clk => clk, ce => ce, reset_na => cpu_reset_na,
      ext_addr => addr, ext_rd => OPEN, ext_wr => OPEN, ext_wdata => OPEN,
      ext_rdata => rdata, ext_req => OPEN, ext_class => OPEN,
      ext_grant => '1', io_addr => io_addr, io_rd => OPEN, io_wr => io_wr,
      io_wdata => io_wdata, io_rdata => io_rdata,
      int_vector => int_vector, int_ack => int_start,
      pc0o => OPEN, pc1o => OPEN, dc0o => OPEN
      );
END ARCHITECTURE rtl;
