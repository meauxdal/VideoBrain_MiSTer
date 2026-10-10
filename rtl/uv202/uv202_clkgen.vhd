-- VideoBrain UV202 - clock generator
-- Reference: kevtris "Videobrain Unwrapped" V0.05, sections:
--   "Conventions in this document" (MCLK/CPUCLK/BRCLK definitions)
--   UV202 pin 4/5 (Xin/Xout), pin 7 (CPUCLK), pin 33 (BRCLK), pin 34 (COLCLK)
--
-- Real hardware: UV202 is clocked from a 14.318181MHz crystal (Xin/Xout).
-- Internally it divides by 4 to make BRCLK (3.579545MHz, also mirrored out
-- as COLCLK for the NTSC encoder) and attempts to divide by 7 to make a
-- 2.045MHz CPUCLK - but that /7 output stops one cycle too late and glitches
-- the CPU during wait states, so real consoles ignore it and instead run the
-- F8 CPU from a *separate* 4MHz oscillator through a JK flip-flop (/2),
-- giving a clean external 2.0MHz CPUCLK with no relation to UV202's internal
-- dividers.
--

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY work;
USE work.base_pack.ALL;
USE work.uv202_pack.ALL;

ENTITY uv202_clkgen IS
  GENERIC (
    CLK_DIV_MCLK : positive := 1;

    -- Retained for the existing entity interface. CPU timing is now generated
    -- from MCLK_HZ and CPU_HALF_HZ below rather than this integer divisor.
    CPU_CLK_DIV  : positive := 7
    );
  PORT (
    clk        : IN  std_logic;
    reset_na   : IN  std_logic;

    mclk_ena   : OUT std_logic;

    brclk_ena  : OUT std_logic;

    cpu_ena    : OUT std_logic;

    -- 2-bit BRCLK sub-phase counter, free-running, used by uv201_fetcher
    -- for the modulo-4 UV201-register-read stretch behavior documented
    -- under "UV201 register reads".
    brclk_phase : OUT uv2
    );
END ENTITY uv202_clkgen;

ARCHITECTURE rtl OF uv202_clkgen IS

  SIGNAL mclk_div_cnt : natural RANGE 0 TO CLK_DIV_MCLK-1 := 0;
  SIGNAL mclk_ena_l   : std_logic;

  SIGNAL brclk_div_cnt : natural RANGE 0 TO BRCLK_DIV-1 := 0;
  SIGNAL brclk_ena_l   : std_logic;
  SIGNAL brclk_phase_l : uv2 := (OTHERS => '0');

  CONSTANT CPU_HALF_HZ : natural := 4_000_000;
  SIGNAL cpu_phase_acc : natural RANGE 0 TO MCLK_HZ-1 := 0;
  SIGNAL cpu_ena_l     : std_logic;

BEGIN


  gen_mclk_passthru : IF CLK_DIV_MCLK = 1 GENERATE
    mclk_ena_l <= '1';
  END GENERATE;

  gen_mclk_divide : IF CLK_DIV_MCLK > 1 GENERATE
    PROCESS(clk, reset_na) IS
    BEGIN
      IF reset_na = '0' THEN
        mclk_div_cnt <= 0;
        mclk_ena_l   <= '0';
      ELSIF rising_edge(clk) THEN
        IF mclk_div_cnt = CLK_DIV_MCLK-1 THEN
          mclk_div_cnt <= 0;
          mclk_ena_l   <= '1';
        ELSE
          mclk_div_cnt <= mclk_div_cnt + 1;
          mclk_ena_l   <= '0';
        END IF;
      END IF;
    END PROCESS;
  END GENERATE;

  mclk_ena <= mclk_ena_l;

  -- Stage 2: mclk_ena -> brclk_ena (divide by 4), plus free-running 2-bit
  -- phase counter (kept ALWAYS running, independent of HBLANK, so
  -- uv201_fetcher can read it directly - the real chip's "modulo 4 counter
  -- that continuously runs" per the doc).

  PROCESS(clk, reset_na) IS
  BEGIN
    IF reset_na = '0' THEN
      brclk_div_cnt <= 0;
      brclk_ena_l   <= '0';
      brclk_phase_l <= (OTHERS => '0');
    ELSIF rising_edge(clk) THEN
      brclk_ena_l <= '0';
      IF mclk_ena_l = '1' THEN
        IF brclk_div_cnt = BRCLK_DIV-1 THEN
          brclk_div_cnt <= 0;
          brclk_ena_l   <= '1';
          brclk_phase_l <= brclk_phase_l + 1;
        ELSE
          brclk_div_cnt <= brclk_div_cnt + 1;
        END IF;
      END IF;
    END IF;
  END PROCESS;

  brclk_ena   <= brclk_ena_l;
  brclk_phase <= brclk_phase_l;

  -- Stage 3: mclk_ena -> cpu_ena. The real CPU clock is an independent
  -- 4MHz oscillator divided by two, so its 4MHz half-cycle rate cannot be
  -- represented by an integer MCLK divisor. Use a phase accumulator to emit
  -- half-cycle enables at exactly 4.0MHz on average. The resulting intervals
  -- alternate between 3 and 4 MCLK ticks, as required by 14.318181/4.0.

  PROCESS(clk, reset_na) IS
    VARIABLE phase_v : natural;
  BEGIN
    IF reset_na = '0' THEN
      cpu_phase_acc <= 0;
      cpu_ena_l     <= '0';
    ELSIF rising_edge(clk) THEN
      cpu_ena_l <= '0';
      IF mclk_ena_l = '1' THEN
        phase_v := cpu_phase_acc + CPU_HALF_HZ;
        IF phase_v >= MCLK_HZ THEN
          cpu_phase_acc <= phase_v - MCLK_HZ;
          cpu_ena_l     <= '1';
        ELSE
          cpu_phase_acc <= phase_v;
        END IF;
      END IF;
    END IF;
  END PROCESS;

  cpu_ena <= cpu_ena_l;

END ARCHITECTURE rtl;
