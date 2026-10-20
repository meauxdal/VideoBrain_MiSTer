LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;
USE work.base_pack.ALL;
USE work.uv202_pack.ALL;

ENTITY tb_cpu_audio IS
  GENERIC (delay_count : positive := 46);
END ENTITY;

ARCHITECTURE test OF tb_cpu_audio IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na : std_logic := '0';
  SIGNAL clock_reset_na : std_logic := '0';
  SIGNAL cpu_ce : std_logic;
  SIGNAL dr, dw, ext_rdata, port_a_n, port_b_n : uv8;
  SIGNAL port_b_wr : std_logic;
  SIGNAL romc : uv5;
  SIGNAL phase : uint4;
  SIGNAL ext_addr : unsigned(13 DOWNTO 0);
  SIGNAL audio_code : std_logic_vector(1 DOWNTO 0);
  SIGNAL audio_stb : std_logic;
  TYPE program_t IS ARRAY(natural RANGE <>) OF uv8;
  CONSTANT program : program_t := (
    x"60", x"68",                       -- LISU 0; LISL 0
    x"1A", x"70", x"50",                 -- DI; LIS 0; LR 0,A
    x"40", x"23", x"03", x"50", x"B0", -- LR A,0; XI 3; LR 0,A; OUTS 0
    x"20", x"10", x"B1", x"70", x"B1", -- LI $10; OUTS 1; LIS 0; OUTS 1
    x"20", to_unsigned(delay_count, 8), x"51", -- LI count; LR 1,A
    x"31", x"94", x"FE",               -- DS 1; BF 4,delay
    x"90", x"EF"                       -- BR loop
  );
  -- F8 clocks: DS=6, BF taken=14/not taken=12, remaining loop=84.
  CONSTANT half_clocks : positive := 20 * delay_count + 82;
  CONSTANT min_ticks : natural := integer(floor(
    real(half_clocks) * real(MCLK_HZ) / 2_000_000.0));
BEGIN
  clk <= NOT clk AFTER 5 ns;
  -- Let the CPU observe reset on an enabled edge.
  clock_reset_na <= '1' AFTER 20 ns;
  reset_na <= '1' AFTER 100 ns;

  ext_rdata <= program(to_integer(ext_addr)) WHEN ext_addr < program'length ELSE x"2B";

  clockgen : ENTITY work.uv202_clkgen
    PORT MAP (
      clk => clk, reset_na => clock_reset_na, mclk_ena => OPEN,
      brclk_ena => OPEN, cpu_ena => cpu_ce, brclk_phase => OPEN
    );

  cpu : ENTITY work.f8_cpu
    PORT MAP (
      clk => clk, ce => cpu_ce, reset_na => reset_na,
      dr => dr, dw => dw, dv => OPEN, romc => romc,
      tick => OPEN, phase => phase,
      po_a_n => port_a_n, pi_a_n => x"FF",
      po_b_n => port_b_n, pi_b_n => x"FF", port1_wr => port_b_wr,
      intreq => '0', acco => OPEN, visaro => OPEN, iozcso => OPEN
    );

  busif : ENTITY work.f8_busif
    PORT MAP (
      clk => clk, ce => cpu_ce, reset_na => reset_na,
      dw => dw, dr => dr, dv => OPEN, romc => romc,
      tick => '0', phase => phase,
      ext_addr => ext_addr, ext_rd => OPEN, ext_wr => OPEN,
      ext_wdata => OPEN, ext_rdata => ext_rdata,
      ext_req => OPEN, ext_class => OPEN, ext_grant => '0',
      io_addr => OPEN, io_rd => OPEN, io_wr => OPEN,
      io_wdata => OPEN, io_rdata => x"00",
      int_vector => x"0100", int_ack => OPEN,
      pc0o => OPEN, pc1o => OPEN, dc0o => OPEN
    );

  io : ENTITY work.videobrain_io
    PORT MAP (
      clk => clk, reset_na => reset_na,
      port_a_n => port_a_n, port_b_n => port_b_n, port_b_wr => port_b_wr,
      port_b_in_n => OPEN, kbd_matrix => (OTHERS => '0'),
      joy_fire => (OTHERS => '0'), uv_kbd => '1',
      key_latch => OPEN, joy_enable => OPEN,
      accessory_p5 => OPEN, accessory_p1 => OPEN,
      audio_code => audio_code, audio_stb => audio_stb
    );

  PROCESS
    VARIABLE ticks, enables, last_tick, last_enable : natural := 0;
    VARIABLE edges : natural := 0;
    VARIABLE previous_code : std_logic_vector(1 DOWNTO 0) := "11";
    VARIABLE width, shortest : natural := natural'high;
    VARIABLE longest : natural := 0;
  BEGIN
    WAIT UNTIL rising_edge(clk);
    IF reset_na = '1' THEN
      ticks := ticks + 1;
      IF cpu_ce = '1' THEN enables := enables + 1; END IF;
      WAIT FOR 1 ns;
      IF audio_stb = '1' THEN
        ASSERT audio_code = NOT previous_code
          REPORT "DAC codes must alternate 0 and 3" SEVERITY failure;
        previous_code := audio_code;
        IF edges > 0 THEN
          ASSERT enables - last_enable = 2 * half_clocks
            REPORT "CPU loop differs from published F8 instruction timing: " &
              integer'image(enables - last_enable) & " half clocks, expected " &
              integer'image(2 * half_clocks) SEVERITY failure;
          width := ticks - last_tick;
          ASSERT width = min_ticks OR width = min_ticks + 1
            REPORT "DAC transition timing exceeds clock-enable quantization" SEVERITY failure;
          shortest := minimum(shortest, width);
          longest := maximum(longest, width);
        END IF;
        last_tick := ticks;
        last_enable := enables;
        edges := edges + 1;
        IF edges = 65 THEN
          REPORT "CPU-to-DAC passed: delay=" & integer'image(delay_count) &
            ", half-period CPU clocks=" & integer'image(half_clocks) &
            ", MCLK interval=" & integer'image(shortest) & ".." & integer'image(longest);
          std.env.stop;
        END IF;
      END IF;
    END IF;
    ASSERT now < 20 ms REPORT "CPU audio test timed out" SEVERITY failure;
  END PROCESS;
END ARCHITECTURE;
