-- Sean Riddle vbdiag.bin executable bytes ($000-$022), SHA256
-- db263679a219f0b8bb3051a478c08de81e4a79ad96e726d3592b2646c27eda83.
-- Compare physical IO16 transition boundaries with the paired capture.
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.base_pack.ALL;
USE work.f8_pack.ALL;
ENTITY tb_sean_diag IS END ENTITY;
ARCHITECTURE test OF tb_sean_diag IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na : std_logic := '0';
  SIGNAL dr, dw, rdata, pins : uv8;
  SIGNAL romc : uv5;
  SIGNAL phase : uint4;
  SIGNAL addr : unsigned(13 DOWNTO 0);
  SIGNAL wr : std_logic;
  TYPE bytes_t IS ARRAY(natural RANGE <>) OF uv8;
  CONSTANT program : bytes_t := (
    x"1A",x"20",x"40",x"B1",x"20",x"40",x"55",x"20",x"FF",x"56",
    x"2B",x"36",x"94",x"FD",x"35",x"94",x"F7",x"70",x"B1",x"20",
    x"40",x"55",x"20",x"FF",x"56",x"2B",x"36",x"94",x"FD",x"35",
    x"94",x"F7",x"29",x"40",x"00");
BEGIN
  clk <= NOT clk AFTER 5 ns;
  reset_na <= '1' AFTER 100 ns;
  rdata <= program(to_integer(addr)) WHEN addr < program'length ELSE x"FF";
  cpu : ENTITY work.f8_cpu PORT MAP (
    clk=>clk, ce=>'1', reset_na=>reset_na, dr=>dr, dw=>dw, dv=>OPEN,
    romc=>romc, tick=>OPEN, phase=>phase, po_a_n=>OPEN, pi_a_n=>x"FF",
    po_b_n=>pins, pi_b_n=>x"FF", port1_wr=>wr, intreq=>'0',
    acco=>OPEN, visaro=>OPEN, iozcso=>OPEN);
  busif : ENTITY work.f8_busif PORT MAP (
    clk=>clk, ce=>'1', reset_na=>reset_na, dw=>dw, dr=>dr, dv=>OPEN,
    romc=>romc, tick=>'0', phase=>phase, ext_addr=>addr, ext_rd=>OPEN,
    ext_wr=>OPEN, ext_wdata=>OPEN, ext_rdata=>rdata, ext_req=>OPEN,
    ext_class=>OPEN, ext_grant=>'0', io_addr=>OPEN, io_rd=>OPEN,
    io_wr=>OPEN, io_wdata=>OPEN, io_rdata=>x"00", int_vector=>x"0000",
    int_ack=>OPEN, pc0o=>OPEN, pc1o=>OPEN, dc0o=>OPEN);
  PROCESS
    VARIABLE ticks, edges, previous, pair : natural := 0;
  BEGIN
    WAIT UNTIL rising_edge(clk); WAIT FOR 1 ns;
    IF reset_na='1' THEN
      ticks:=ticks+1;
      IF wr='1' THEN
        IF edges>0 THEN
          REPORT "Diagnostic IO16 level=" & std_logic'image(pins(6)) &
            ", interval PHI periods=" & real'image(real(ticks-previous)/2.0);
          IF edges MOD 2=1 THEN pair:=ticks-previous;
          ELSE
            -- Manual instruction totals give the complete two-level loop.
            ASSERT pair+ticks-previous=2*787540
              REPORT "Diagnostic full loop differs from published timing" SEVERITY failure;
          END IF;
        END IF;
        previous:=ticks; edges:=edges+1;
        IF edges=5 THEN std.env.stop; END IF;
      END IF;
    END IF;
    ASSERT now<40 ms REPORT "Diagnostic timed out" SEVERITY failure;
  END PROCESS;
END ARCHITECTURE;
