-- Isolate each CPU access before sweeping reset/oscillator alignment. Unlike
-- tb_cpu_bus_wait, no preceding buffered access can bias UV201 entry phase.
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.textio.ALL;
USE work.base_pack.ALL;
USE work.f8_pack.ALL;
USE work.uv202_pack.ALL;

ENTITY tb_uv201_wait IS
  GENERIC (write_test : boolean := false; gap_csv : string := "";
           check_capture_phase : boolean := true; dma_mode : boolean := false);
END ENTITY;
ARCHITECTURE test OF tb_uv201_wait IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na, clock_reset_na : std_logic := '0';
  SIGNAL raw, ce, req, grant, stall, wack, br_ce : std_logic;
  SIGNAL dma_request : std_logic;
  SIGNAL br_phase : uv2;
  SIGNAL access_class : bus_access_t;
  SIGNAL dr, dw, rdata : uv8;
  SIGNAL romc : uv5;
  SIGNAL phase : uint4;
  SIGNAL addr : unsigned(13 DOWNTO 0);
  SIGNAL pc : uv16;
  SIGNAL acc, write_data : uv8;
  SIGNAL write_stb, transfer_complete : std_logic := '0';
  TYPE bytes_t IS ARRAY(natural RANGE <>) OF uv8;
  CONSTANT program : bytes_t := (x"70",x"0B",x"75",x"2A",x"08",x"FB",x"16",x"2B");
BEGIN
  clk <= NOT clk AFTER 5 ns;
  dma_request <= '1' WHEN dma_mode AND reset_na='1' ELSE '0';
  -- Poison data until completion: delaying the request without also delaying
  -- the CPU's read-data consumption must fail this test.
  rdata <= x"A5" WHEN addr=16#08FB# AND transfer_complete='1' ELSE
           x"DE" WHEN addr=16#08FB# ELSE
           x"50" WHEN addr=5 AND write_test ELSE
           x"17" WHEN addr=6 AND write_test ELSE
           program(to_integer(addr)) WHEN addr<program'length ELSE x"00";
  PROCESS(clk,reset_na)
  BEGIN
    IF reset_na='0' THEN transfer_complete<='0';
    ELSIF rising_edge(clk) THEN
      IF grant='1' THEN transfer_complete<='1'; END IF;
    END IF;
  END PROCESS;
  timing : ENTITY work.uv202_top PORT MAP (
    clk=>clk, reset_na=>clock_reset_na, progressive=>'0',
    cpu_req=>req, cpu_class=>access_class, cpu_grant=>grant,
    cpu_wack=>wack, cpu_stall=>stall, umireq0=>dma_request, umireq1=>'0',
    dmareq0=>OPEN, dmareq1=>OPEN, busy=>OPEN, mclk_ena=>OPEN,
    brclk_ena=>br_ce, brclk_phase=>br_phase, cpu_ena_raw=>raw, cpu_ce=>ce,
    hblank=>OPEN, vblank=>OPEN, burst=>OPEN, csync=>OPEN,
    scanline=>OPEN, field=>OPEN, hpos=>OPEN, vpos=>OPEN,
    line_start=>OPEN, hblank_falling=>OPEN, hblank_rising=>OPEN);
  cpu : ENTITY work.f8_cpu PORT MAP (
    clk=>clk, ce=>ce, reset_na=>reset_na, dr=>dr, dw=>dw, dv=>OPEN,
    romc=>romc, tick=>OPEN, phase=>phase, po_a_n=>OPEN, pi_a_n=>x"FF",
    po_b_n=>OPEN, pi_b_n=>x"FF", port1_wr=>OPEN, intreq=>'0',
    acco=>acc, visaro=>OPEN, iozcso=>OPEN);
  busif : ENTITY work.f8_busif PORT MAP (
    clk=>clk, ce=>ce, reset_na=>reset_na, dw=>dw, dr=>dr, dv=>OPEN,
    romc=>romc, tick=>'0', phase=>phase, ext_addr=>addr, ext_rd=>OPEN,
    ext_wr=>write_stb, ext_wdata=>write_data, ext_rdata=>rdata, ext_req=>req,
    ext_class=>access_class, ext_grant=>grant, io_addr=>OPEN,
    io_rd=>OPEN, io_wr=>OPEN, io_wdata=>OPEN, io_rdata=>x"00",
    int_vector=>x"0000", int_ack=>OPEN, pc0o=>pc, pc1o=>OPEN, dc0o=>OPEN);
  PROCESS
    FILE capture : text;
    VARIABLE row : line;
    TYPE naturals_t IS ARRAY(0 TO 1) OF natural;
    VARIABLE last_edge, halt_edge, gap, gap_phase : naturals_t;
    VARIABLE active, start_active, raw_count, start_raw : natural;
    VARIABLE request_tick, admit_tick, grant_tick, admit_phase : natural;
    VARIABLE previous_req, previous_wack, previous_grant : std_logic;
    VARIABLE pending, halted, complete : boolean;
    VARIABLE got_gap : boolean_vector(0 TO 1);
    VARIABLE shortest : natural := natural'high;
    VARIABLE longest : natural := 0;
    VARIABLE writes : natural;
    VARIABLE phases : boolean_vector(0 TO 3) := (OTHERS=>false);
  BEGIN
    IF gap_csv/="" THEN
      file_open(capture,gap_csv,write_mode);
      write(row,string'("offset,write_test,admit_phase,request_mclk,admit_mclk,grant_mclk,fall_gap_mclk,rise_gap_mclk,fall_phase_before_gap,rise_phase_before_gap,lost_half_clocks"));
      writeline(capture,row);
    END IF;
    FOR offset IN 0 TO 255 LOOP
      reset_na<='0'; clock_reset_na<='0';
      FOR i IN 1 TO 32 LOOP WAIT UNTIL falling_edge(clk); END LOOP;
      clock_reset_na<='1';
      FOR i IN 1 TO 8+offset LOOP WAIT UNTIL falling_edge(clk); END LOOP;
      reset_na<='1';
      last_edge:=(OTHERS=>0); halt_edge:=(OTHERS=>0);
      gap:=(OTHERS=>0); gap_phase:=(OTHERS=>0); got_gap:=(OTHERS=>false);
      active:=0; raw_count:=0; start_active:=0; start_raw:=0;
      request_tick:=0; admit_tick:=0; grant_tick:=0; admit_phase:=0;
      previous_req:='0'; previous_wack:='0'; previous_grant:='0';
      pending:=false; halted:=false; complete:=false;
      writes:=0;
      FOR tick IN 0 TO 4095 LOOP
        WAIT UNTIL rising_edge(clk);
        IF raw='1' THEN raw_count:=raw_count+1; END IF;
        IF req='1' AND previous_req='0' THEN
          request_tick:=tick; halt_edge:=last_edge; halted:=true;
        END IF;
        IF wack='1' AND previous_wack='0' THEN
          admit_tick:=tick;
          -- uv202_top supplies brclk_phase + 1 to the arbiter. The
          -- registered WACK is observed before the next BRCLK transition.
          admit_phase:=(to_integer(br_phase)+1) MOD 4;
          phases(admit_phase):=true;
        END IF;
        IF grant='1' AND previous_grant='0' THEN grant_tick:=tick; END IF;
        IF write_stb='1' THEN
          ASSERT write_test AND addr=16#0850# AND write_data=x"05"
            REPORT "Late write lost its address or data" SEVERITY failure;
          writes:=writes+1;
        END IF;
        IF ce='1' THEN
          IF halted AND stall='0' AND NOT got_gap(phase MOD 2) THEN
            gap(phase MOD 2):=tick-halt_edge(phase MOD 2);
            got_gap(phase MOD 2):=true;
          END IF;
          last_edge(phase MOD 2):=tick;
          IF NOT halted THEN gap_phase(phase MOD 2):=phase; END IF;
          active:=active+1;
          IF phase=1 THEN
            IF pending AND pc=x"0008" AND romc=ROMC_00 THEN
              ASSERT active-start_active=20
                REPORT "Isolated LM/ST active cycle count changed" SEVERITY failure;
              ASSERT got_gap(0) AND got_gap(1)
                REPORT "Missing one clock polarity gap" SEVERITY failure;
              ASSERT grant_tick-admit_tick=4*(8-admit_phase) OR
                     (dma_mode AND grant_tick-admit_tick=4*(7-admit_phase))
                REPORT "UV201 setup/body phase accounting mismatch" SEVERITY failure;
              IF write_test THEN
                IF check_capture_phase THEN
                  ASSERT gap_phase(1)=7
                    REPORT "Write pause must follow fourth PHI falling edge" SEVERITY failure;
                END IF;
                ASSERT writes=1 AND acc=x"05"
                  REPORT "Write changed CPU state or transfer count" SEVERITY failure;
              ELSE
                IF check_capture_phase THEN
                  ASSERT gap_phase(1)=5
                    REPORT "Read pause must follow third PHI falling edge" SEVERITY failure;
                END IF;
                ASSERT acc=x"A5" AND writes=0
                  REPORT "UV201 read consumed pre-grant data" SEVERITY failure;
              END IF;
              shortest:=minimum(shortest,gap(1)); longest:=maximum(longest,gap(1));
              IF gap_csv/="" THEN
                write(row,offset); write(row,string'(","));
                write(row,boolean'image(write_test)); write(row,string'(","));
                write(row,admit_phase); write(row,string'(","));
                write(row,request_tick); write(row,string'(","));
                write(row,admit_tick); write(row,string'(","));
                write(row,grant_tick); write(row,string'(","));
                write(row,gap(1)); write(row,string'(","));
                write(row,gap(0)); write(row,string'(","));
                write(row,gap_phase(1)); write(row,string'(","));
                write(row,gap_phase(0)); write(row,string'(","));
                write(row,raw_count-start_raw-20); writeline(capture,row);
              END IF;
              complete:=true; EXIT;
            END IF;
            IF (romc=ROMC_02 OR romc=ROMC_05) AND pc=x"0007" THEN
              ASSERT NOT pending REPORT "More than one buffered access" SEVERITY failure;
              pending:=true; start_active:=active; start_raw:=raw_count;
            END IF;
          END IF;
        END IF;
        previous_req:=req; previous_wack:=wack; previous_grant:=grant;
      END LOOP;
      ASSERT complete REPORT "Isolated UV201 test timed out" SEVERITY failure;
    END LOOP;
    FOR p IN 0 TO 3 LOOP
      ASSERT phases(p) REPORT "Sweep failed to cover all admission phases" SEVERITY failure;
    END LOOP;
    REPORT "Isolated UV201 write=" & boolean'image(write_test) &
      ", DMA=" & boolean'image(dma_mode) &
      ": 256 offsets, all admission phases, same-polarity gap MCLK=" &
      integer'image(shortest) & ".." & integer'image(longest);
    IF gap_csv/="" THEN file_close(capture); END IF;
    std.env.stop;
    WAIT;
  END PROCESS;
END ARCHITECTURE;
