LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.base_pack.ALL;
USE work.uv201_pack.ALL;
USE work.uv202_pack.ALL;

ENTITY tb_fetcher_bus IS
  GENERIC (copy_mode : boolean := false; backpressure : boolean := false);
END ENTITY;

ARCHITECTURE test OF tb_fetcher_bus IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na, line_start, brclk_ena : std_logic := '0';
  SIGNAL bus_phase : uv2;
  SIGNAL obj_addr, obj_data, bb_data : uv8;
  SIGNAL bb_addr : unsigned(12 DOWNTO 0);
  SIGNAL umireq, dmareq, fifo_wr, busy : std_logic := '0';
  SIGNAL writable : std_logic := '1';
  SIGNAL entry : uv201_fifo_entry_t;
  SIGNAL cpu_req, cpu_grant : std_logic := '0';
  SIGNAL cpu_completed : natural := 0;
BEGIN
  clk <= NOT clk AFTER 5 ns;

  clocks : ENTITY work.uv202_clkgen
    PORT MAP (clk => clk, reset_na => reset_na, mclk_ena => OPEN,
      brclk_ena => brclk_ena, brclk_phase => bus_phase, cpu_ena => OPEN);

  arbiter : ENTITY work.uv202_arbiter
    PORT MAP (clk => clk, reset_na => reset_na, brclk_ena => brclk_ena,
      bus_phase => bus_phase + 1, cpu_req => cpu_req, cpu_class => ACC_RAM_RD,
      cpu_grant => cpu_grant, cpu_wack => OPEN, cpu_stall => OPEN,
      umireq0 => umireq, umireq1 => '0', dmareq0 => dmareq,
      dmareq1 => OPEN, busy => OPEN);

  fetcher : ENTITY work.uv201_fetcher
    PORT MAP (clk => clk, reset_na => reset_na, brclk_ena => brclk_ena,
      line_start => line_start, fifo_clear => '0', vpos => to_unsigned(20, 9),
      video_en => '1', list_a => '1', x_zoom => '0', y_zoom => '0',
      obj_addr => obj_addr, obj_rdata => obj_data, bb_addr => bb_addr,
      bb_rdata => bb_data, umireq => umireq, dmareq => dmareq,
      fifo_writable => writable, fifo_wr_en => fifo_wr, fifo_wr_entry => entry,
      busy => busy);

  bb_data <= bb_addr(7 DOWNTO 0);
  PROCESS(all)
  BEGIN
    obj_data <= x"00";
    CASE to_integer(obj_addr) IS
      WHEN REG_Y_LO_A => obj_data <= x"14";
      WHEN REG_Y_LO_A + 1 TO REG_Y_LO_A + 15 => obj_data <= x"FF";
      WHEN REG_DY => obj_data <= x"01";
      WHEN REG_RP_LO => obj_data <= x"F8";
      WHEN REG_RP_HI_COLOR => obj_data <= x"1F";
      WHEN REG_DX_INT_XCOPY =>
        IF copy_mode THEN obj_data <= x"8C";
        ELSE obj_data <= x"0C"; END IF;
      WHEN OTHERS => NULL;
    END CASE;
  END PROCESS;

  PROCESS
  BEGIN
    WAIT FOR 100 ns;
    reset_na <= '1';
    WAIT UNTIL falling_edge(clk);
    line_start <= '1';
    WAIT UNTIL falling_edge(clk);
    line_start <= '0';
    WAIT;
  END PROCESS;

  PROCESS
  BEGIN
    IF backpressure THEN
      WAIT UNTIL dmareq = '1';
      FOR i IN 1 TO 3 LOOP
        WAIT FOR 83 ns;
        cpu_req <= '1';
        WAIT UNTIL cpu_grant = '1';
        WAIT UNTIL falling_edge(clk);
        cpu_req <= '0';
        cpu_completed <= i;
      END LOOP;
    END IF;
    WAIT;
  END PROCESS;

  PROCESS
    VARIABLE bytes, grants, offset, pause_ticks : natural := 0;
    VARIABLE started, paused : boolean := false;
    VARIABLE previous_dma : time := 0 ns;
  BEGIN
    WAIT UNTIL rising_edge(clk);
    IF reset_na = '1' THEN
      IF busy = '1' THEN started := true; END IF;
      IF dmareq = '1' THEN
        IF grants > 0 AND NOT backpressure THEN
          ASSERT now - previous_dma = 120 ns
            REPORT "Integrated DMA burst did not sustain three BRCLKs per byte" SEVERITY failure;
        END IF;
        previous_dma := now;
        ASSERT grants < 12 REPORT "Extra DMA grant" SEVERITY failure;
        offset := grants;
        IF copy_mode THEN offset := 0; END IF;
        ASSERT to_integer(bb_addr) = (16#1FF8# + offset) MOD 8192
          REPORT "DMA used the wrong byte address" SEVERITY failure;
        grants := grants + 1;
      END IF;
      IF brclk_ena = '1' AND fifo_wr = '1' THEN
        offset := bytes;
        IF copy_mode THEN offset := 0; END IF;
        ASSERT entry.is_gap = '0' AND
          to_integer(entry.payload) = (16#F8# + offset) MOD 256
          REPORT "FIFO byte was lost, duplicated or reordered" SEVERITY failure;
        bytes := bytes + 1;
      END IF;
      IF backpressure AND bytes = 3 AND NOT paused THEN
        paused := true;
        pause_ticks := 32;
        writable <= '0';
      ELSIF pause_ticks > 0 THEN
        pause_ticks := pause_ticks - 1;
        IF pause_ticks = 0 THEN writable <= '1'; END IF;
      END IF;
      IF started AND busy = '0' THEN
        ASSERT bytes = 12 AND grants = 12
          REPORT "Incomplete DMA object" SEVERITY failure;
        ASSERT NOT backpressure OR cpu_completed = 3
          REPORT "CPU contention did not complete" SEVERITY failure;
        REPORT "Fetcher/bus byte ordering, wrap and flow control passed";
        std.env.stop;
      END IF;
    END IF;
    ASSERT now < 10 us REPORT "Fetcher/bus test timed out" SEVERITY failure;
  END PROCESS;
END ARCHITECTURE;
