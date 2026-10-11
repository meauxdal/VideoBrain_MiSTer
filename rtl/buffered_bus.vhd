-- Reference: kevtris "Videobrain Unwrapped" V0.05, "Buffered Bus".
-- The UV201 does not see the CPU's full address space.  Its 13-bit graphics
-- pointer addresses an 8K bus containing only RES2, system RAM, and cartridge
-- ROM.  0800-0BFF is deliberately open during DMA because WACK is not asserted
-- for UV201 fetches; UV201 registers and the cartridge-mapped CPU window are
-- therefore not visible here.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY work;
USE work.base_pack.ALL;
USE work.uv202_pack.ALL;

ENTITY buffered_bus IS
  PORT (
    bb_addr  : IN  unsigned(12 DOWNTO 0);
    bb_rdata : OUT uv8;

    res2_sel   : OUT std_logic;
    res2_addr  : OUT unsigned(10 DOWNTO 0);
    res2_rdata : IN  uv8;

    ram_sel   : OUT std_logic;
    ram_addr  : OUT unsigned(9 DOWNTO 0);
    ram_rdata : IN  uv8;

    cart_sel   : OUT std_logic;
    cart_addr  : OUT unsigned(11 DOWNTO 0);
    cart_rdata : IN  uv8;

    open_bus : OUT std_logic
    );
END ENTITY buffered_bus;

ARCHITECTURE rtl OF buffered_bus IS
  SIGNAL res2_sel_l : std_logic;
  SIGNAL ram_sel_l  : std_logic;
  SIGNAL cart_sel_l : std_logic;
BEGIN

  res2_sel_l <= '1' WHEN bb_addr >= to_unsigned(BBUS_RES2_LO, 13) AND
                           bb_addr <= to_unsigned(BBUS_RES2_HI, 13)
                ELSE '0';

  ram_sel_l <= '1' WHEN bb_addr >= to_unsigned(BBUS_RAM_LO, 13) AND
                          bb_addr <= to_unsigned(BBUS_RAM_HI, 13)
               ELSE '0';

  cart_sel_l <= '1' WHEN bb_addr >= to_unsigned(BBUS_CART_LO, 13) AND
                           bb_addr <= to_unsigned(BBUS_CART_HI, 13)
                ELSE '0';

  res2_addr <= resize(bb_addr - to_unsigned(BBUS_RES2_LO, 13), res2_addr'length);
  ram_addr  <= resize(bb_addr - to_unsigned(BBUS_RAM_LO, 13), ram_addr'length);
  cart_addr <= resize(bb_addr - to_unsigned(BBUS_CART_LO, 13), cart_addr'length);

  PROCESS (res2_sel_l, ram_sel_l, cart_sel_l,
           res2_rdata, ram_rdata, cart_rdata) IS
  BEGIN
    IF res2_sel_l = '1' THEN
      bb_rdata <= res2_rdata;
    ELSIF ram_sel_l = '1' THEN
      bb_rdata <= ram_rdata;
    ELSIF cart_sel_l = '1' THEN
      bb_rdata <= cart_rdata;
    ELSE
      -- Real hardware is genuinely open here.  0xFF is a deterministic
      -- simulation/FPGA placeholder; nothing should rely on this value.
      bb_rdata <= (OTHERS => '1');
    END IF;
  END PROCESS;

  res2_sel <= res2_sel_l;
  ram_sel  <= ram_sel_l;
  cart_sel <= cart_sel_l;
  open_bus <= NOT (res2_sel_l OR ram_sel_l OR cart_sel_l);

END ARCHITECTURE rtl;
