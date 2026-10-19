LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.base_pack.ALL;
USE work.uv202_pack.ALL;

ENTITY tb_cpu_gate IS
  GENERIC (legacy_gate : boolean := false);
END ENTITY;

ARCHITECTURE test OF tb_cpu_gate IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na : std_logic := '0';
  SIGNAL raw, sample, ce, stall : std_logic;
  SIGNAL req, wack : std_logic := '0';
  SIGNAL osc, xtly : std_logic := '0';
  SIGNAL u31_q, u30a_q : std_logic := '1';
  SIGNAL clear_na, request_na, toggle_enable : std_logic;
  SIGNAL legacy_grant : std_logic := '0';
  SIGNAL top_req : std_logic := '0';
  SIGNAL top_wack, top_grant, top_stall, top_ce, brclk : std_logic;
  SIGNAL checked, differences, early_restarts : natural := 0;
BEGIN
  clk <= NOT clk AFTER 5 ns;
  clocks : ENTITY work.uv202_clkgen
    PORT MAP (
      clk => clk, reset_na => reset_na, mclk_ena => OPEN,
      brclk_ena => OPEN, brclk_phase => OPEN,
      cpu_ena => raw, cpu_sample => sample
    );
  gate : ENTITY work.uv202_cpu_gate
    PORT MAP (
      clk => clk, reset_na => reset_na, cpu_raw => raw, cpu_sample => sample,
      cpu_req => req, cpu_wack => wack, cpu_ce => ce, cpu_stall => stall
    );
  board : ENTITY work.uv202_top
    PORT MAP (
      clk => clk, reset_na => reset_na, progressive => '0',
      cpu_req => top_req, cpu_class => ACC_RAM_RD, cpu_grant => top_grant,
      cpu_wack => top_wack, cpu_stall => top_stall,
      umireq0 => '0', umireq1 => '0', dmareq0 => OPEN, dmareq1 => OPEN,
      mclk_ena => OPEN, brclk_ena => brclk, brclk_phase => OPEN,
      cpu_ena_raw => OPEN, cpu_ce => top_ce,
      hblank => OPEN, vblank => OPEN, burst => OPEN, csync => OPEN,
      scanline => OPEN, field => OPEN, hpos => OPEN, vpos => OPEN,
      line_start => OPEN, hblank_falling => OPEN, hblank_rising => OPEN,
      busy => OPEN
    );

  -- Independent event-driven board model, videobrain.xlsx U28D/U30/U31A/U40.
  PROCESS(clk, reset_na) IS
  BEGIN
    IF reset_na = '0' THEN osc <= '0';
    ELSIF rising_edge(clk) THEN
      IF sample = '1' THEN osc <= '1'; END IF;
      IF raw = '1' THEN osc <= '0'; END IF;
    END IF;
  END PROCESS;
  PROCESS(osc, reset_na) IS
  BEGIN
    IF reset_na = '0' THEN u31_q <= '1';
    ELSIF rising_edge(osc) THEN u31_q <= NOT wack; END IF;
  END PROCESS;
  clear_na <= u31_q AND reset_na;
  request_na <= NOT req;
  PROCESS(request_na, clear_na) IS
  BEGIN
    IF clear_na = '0' THEN u30a_q <= '0';
    ELSIF falling_edge(request_na) THEN u30a_q <= '1'; END IF;
  END PROCESS;
  toggle_enable <= u31_q AND NOT u30a_q;
  PROCESS(wack, req, reset_na) IS
  BEGIN
    IF reset_na = '0' OR req = '0' THEN legacy_grant <= '0';
    ELSIF falling_edge(wack) THEN legacy_grant <= '1'; END IF;
  END PROCESS;
  PROCESS(osc, reset_na) IS
  BEGIN
    IF reset_na = '0' THEN xtly <= '0';
    ELSIF falling_edge(osc) AND toggle_enable = '1' THEN xtly <= NOT xtly; END IF;
  END PROCESS;

  PROCESS
    VARIABLE old_xtly, actual : std_logic;
  BEGIN
    WAIT UNTIL rising_edge(clk);
    old_xtly := xtly;
    actual := ce;
    IF legacy_gate THEN actual := raw AND NOT (req AND NOT legacy_grant); END IF;
    WAIT FOR 1 ns;
    IF reset_na = '1' THEN
      checked <= checked + 1;
      IF (actual = '1') /= (xtly /= old_xtly) THEN
        IF actual = '1' AND u31_q = '0' AND wack = '0' THEN
          early_restarts <= early_restarts + 1;
        END IF;
        differences <= differences + 1;
        ASSERT legacy_gate
          REPORT "CPU edge differs from U30/U31 board circuit" SEVERITY failure;
      END IF;
    END IF;
  END PROCESS;

  PROCESS
    PROCEDURE ticks(n : natural) IS
    BEGIN
      FOR i IN 1 TO n LOOP WAIT UNTIL falling_edge(clk); END LOOP;
    END PROCEDURE;
    PROCEDURE reset IS
    BEGIN
      reset_na <= '0'; req <= '0'; wack <= '0'; ticks(8);
      reset_na <= '1'; ticks(16);
    END PROCEDURE;
  BEGIN
    -- Request must stop the CPU before WACK, even if the request is withdrawn.
    reset;
    req <= '1'; ticks(2); req <= '0'; ticks(12);
    ASSERT stall = '1' REPORT "Request latch lost before WACK" SEVERITY failure;
    wack <= '1'; ticks(8);
    ASSERT stall = '1' REPORT "WACK must hold the CPU after clearing U30A" SEVERITY failure;
    wack <= '0'; ticks(8);
    ASSERT stall = '0' REPORT "WACK release failed to restart CPU" SEVERITY failure;

    -- Sweep request, admission and release across oscillator sampling edges.
    FOR offset IN 0 TO 63 LOOP
      FOR service IN 1 TO 12 LOOP
        reset; ticks(offset);
        req <= '1'; ticks(8 + offset MOD 8);
        wack <= '1'; ticks(16 + service);
        wack <= '0'; ticks(1); req <= '0'; ticks(16);
      END LOOP;
    END LOOP;
    -- Reset while stopped, followed by another complete halt/restart.
    req <= '1'; ticks(8); wack <= '1'; ticks(8);
    reset;
    ASSERT stall = '0' REPORT "Reset left CPU stopped" SEVERITY failure;
    req <= '1'; ticks(8); wack <= '1'; ticks(16);
    req <= '0'; wack <= '0'; ticks(16);
    -- U41 and the UV202 cannot consume a new request on the same BRCLK.
    FOR offset IN 0 TO 15 LOOP
      reset; ticks(offset);
      ASSERT top_ce = raw REPORT "Idle top-level CPU clock changed" SEVERITY failure;
      top_req <= '1';
      WAIT UNTIL rising_edge(clk) AND brclk = '1'; WAIT FOR 1 ns;
      ASSERT top_wack = '0' AND top_stall = '1'
        REPORT "U41 sampling edge must stop CPU before UV202 admission" SEVERITY failure;
      WAIT UNTIL rising_edge(clk) AND brclk = '1'; WAIT FOR 1 ns;
      ASSERT top_wack = '1' REPORT "UV202 did not consume U41 request" SEVERITY failure;
      WAIT UNTIL falling_edge(top_wack);
      ASSERT top_grant = '1' REPORT "Bus completion lost grant" SEVERITY failure;
      top_req <= '0'; ticks(16);
      ASSERT top_stall = '0' REPORT "Top-level CPU did not resume" SEVERITY failure;
    END LOOP;
    IF legacy_gate THEN
      ASSERT differences > 0 REPORT "Legacy gate unexpectedly matches circuit" SEVERITY failure;
      ASSERT early_restarts > 0 REPORT "Late WACK release was not exercised" SEVERITY failure;
      REPORT "Legacy edge mismatches=" & integer'image(differences);
      REPORT "Legacy premature WACK restarts=" & integer'image(early_restarts);
    ELSE
      ASSERT differences = 0 SEVERITY failure;
      REPORT "Circuit edge regression passed; MCLK checks=" & integer'image(checked);
    END IF;
    REPORT "U41 request sampling passed at 16 offsets";
    std.env.stop;
  END PROCESS;
END ARCHITECTURE;
