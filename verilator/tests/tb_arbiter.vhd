LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.base_pack.ALL;
USE work.uv202_pack.ALL;

ENTITY tb_arbiter IS
  GENERIC (dma_test : boolean := false);
END ENTITY;

ARCHITECTURE test OF tb_arbiter IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na : std_logic := '0';
  SIGNAL cpu_req, cpu_grant, cpu_wack, cpu_stall : std_logic := '0';
  SIGNAL umireq0, umireq1, dmareq0, dmareq1 : std_logic := '0';
  SIGNAL cpu_class : bus_access_t := ACC_RAM_RD;
  SIGNAL bus_phase : uv2 := "01";
BEGIN
  -- One simulation clock is one BRCLK.
  clk <= NOT clk AFTER 5 ns;
  PROCESS(clk)
  BEGIN
    IF rising_edge(clk) THEN
      IF reset_na = '0' THEN bus_phase <= "01";
      ELSE bus_phase <= bus_phase + 1; END IF;
    END IF;
  END PROCESS;

  dut : ENTITY work.uv202_arbiter
    PORT MAP (
      clk => clk, reset_na => reset_na, brclk_ena => '1',
      bus_phase => bus_phase,
      cpu_req => cpu_req, cpu_class => cpu_class,
      cpu_grant => cpu_grant, cpu_wack => cpu_wack, cpu_stall => cpu_stall,
      umireq0 => umireq0, umireq1 => umireq1,
      dmareq0 => dmareq0, dmareq1 => dmareq1, busy => OPEN
    );

  PROCESS
    VARIABLE elapsed, measured : natural;
    VARIABLE previous_grant : time;
    PROCEDURE restart IS
    BEGIN
      reset_na <= '0'; cpu_req <= '0'; umireq0 <= '0'; umireq1 <= '0';
      WAIT UNTIL falling_edge(clk);
      WAIT UNTIL falling_edge(clk);
      reset_na <= '1';
    END PROCEDURE;
    PROCEDURE cpu_access(kind : bus_access_t; start_phase, duration : natural) IS
    BEGIN
      cpu_class <= kind;
      LOOP
        WAIT UNTIL falling_edge(clk);
        EXIT WHEN to_integer(bus_phase) = start_phase;
      END LOOP;
      cpu_req <= '1';
      WAIT UNTIL falling_edge(clk);
      ASSERT cpu_wack = '1' AND cpu_stall = '1'
        REPORT "CPU transfer did not start" SEVERITY failure;
      elapsed := 0;
      WHILE cpu_grant = '0' LOOP
        WAIT UNTIL falling_edge(clk);
        elapsed := elapsed + 1;
        ASSERT elapsed < 16 REPORT "CPU transfer timed out" SEVERITY failure;
      END LOOP;
      REPORT "CPU access phase=" & integer'image(start_phase) &
        " BRCLKs=" & integer'image(elapsed);
      ASSERT elapsed = duration
        REPORT "Bus duration differs from measured hardware" SEVERITY failure;
      ASSERT cpu_wack = '0' AND cpu_stall = '0'
        REPORT "CPU was not released at completion" SEVERITY failure;
      cpu_req <= '0';
      WAIT UNTIL falling_edge(clk);
    END PROCEDURE;
  BEGIN
    restart;
    IF NOT dma_test THEN
      FOR p IN 0 TO 3 LOOP
        cpu_access(ACC_RAM_RD, p, 4);
        cpu_access(ACC_RAM_WR, p, 4);
        cpu_access(ACC_CART_RD, p, 4);
        cpu_access(ACC_RES2, p, 4);
        -- Hardware: one setup BRCLK and a 4..7 BRCLK UV201 body.
        cpu_access(ACC_UV201_RD, p, 8 - p);
        cpu_access(ACC_UV201_WR, p, 8 - p);
      END LOOP;
    ELSE
      umireq0 <= '1';
      previous_grant := 0 ns;
      FOR byte_index IN 0 TO 3 LOOP
        LOOP
          WAIT UNTIL falling_edge(clk);
          EXIT WHEN dmareq0 = '1';
          ASSERT now < 2 us REPORT "DMA timed out" SEVERITY failure;
        END LOOP;
        IF byte_index > 0 THEN
          measured := (now - previous_grant) / 10 ns;
          REPORT "DMA burst spacing BRCLKs=" & integer'image(measured);
          ASSERT measured = 3
            REPORT "DMA burst must not repeat the setup penalty" SEVERITY failure;
        END IF;
        previous_grant := now;
      END LOOP;
      umireq0 <= '0';
      FOR i IN 1 TO 8 LOOP
        WAIT UNTIL falling_edge(clk);
        ASSERT dmareq0 = '0' REPORT "Unexpected DMA after request ended" SEVERITY failure;
      END LOOP;

      restart;
      umireq0 <= '1'; umireq1 <= '1';
      FOR byte_index IN 0 TO 5 LOOP
        LOOP
          WAIT UNTIL falling_edge(clk);
          EXIT WHEN dmareq0 = '1' OR dmareq1 = '1';
          ASSERT now < 20 us REPORT "Dual DMA timed out" SEVERITY failure;
        END LOOP;
        ASSERT (dmareq0 = '1') = (byte_index MOD 2 = 0)
          REPORT "DMA channels must alternate" SEVERITY failure;
        IF byte_index > 0 THEN
          ASSERT now - previous_grant = 30 ns
            REPORT "Switching DMA channels added a setup penalty" SEVERITY failure;
        END IF;
        previous_grant := now;
      END LOOP;

      FOR arrival IN 0 TO 2 LOOP
        restart;
        cpu_class <= ACC_RAM_RD;
        umireq0 <= '1';
        -- Start of the first DMA body follows idle selection and setup.
        WAIT UNTIL falling_edge(clk);
        WAIT UNTIL falling_edge(clk);
        FOR i IN 1 TO arrival LOOP WAIT UNTIL falling_edge(clk); END LOOP;
        cpu_req <= '1';
        previous_grant := now;
        LOOP
          WAIT UNTIL falling_edge(clk);
          IF dmareq0 = '1' THEN umireq0 <= '0'; END IF;
          EXIT WHEN cpu_grant = '1';
          ASSERT now < 20 us REPORT "CPU handoff timed out" SEVERITY failure;
        END LOOP;
        measured := (now - previous_grant) / 10 ns;
        REPORT "CPU during DMA arrival=" & integer'image(arrival) &
          " BRCLKs=" & integer'image(measured);
        IF arrival < 2 THEN
          ASSERT measured = 6 - arrival
            REPORT "CPU handoff failed to overlap DMA setup" SEVERITY failure;
        ELSE
          ASSERT measured = 5
            REPORT "Late CPU request must retain setup" SEVERITY failure;
        END IF;
        FOR i IN 1 TO 4 LOOP
          WAIT UNTIL falling_edge(clk);
          ASSERT cpu_grant = '1' AND cpu_stall = '0'
            REPORT "CPU completion handshake was not held" SEVERITY failure;
        END LOOP;
        cpu_req <= '0';
        WAIT UNTIL falling_edge(clk);
        ASSERT cpu_grant = '0' REPORT "CPU completion did not clear" SEVERITY failure;
      END LOOP;

      restart;
      cpu_req <= '1'; umireq0 <= '1';
      LOOP
        WAIT UNTIL falling_edge(clk);
        ASSERT dmareq0 = '0' REPORT "Simultaneous DMA beat CPU priority" SEVERITY failure;
        EXIT WHEN cpu_grant = '1';
      END LOOP;
      previous_grant := now;
      cpu_req <= '0';
      LOOP
        WAIT UNTIL falling_edge(clk);
        EXIT WHEN dmareq0 = '1';
        ASSERT now < 20 us REPORT "DMA after CPU timed out" SEVERITY failure;
      END LOOP;
      ASSERT now - previous_grant = 40 ns
        REPORT "CPU-to-DMA must have one setup and three body cycles" SEVERITY failure;
    END IF;
    REPORT "Arbiter hardware timing tests passed";
    std.env.stop;
  END PROCESS;
END ARCHITECTURE;
