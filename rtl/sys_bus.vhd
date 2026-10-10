
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY work;
USE work.base_pack.ALL;
USE work.uv202_pack.ALL;

ENTITY sys_bus IS
  PORT (
    clk      : IN  std_logic;
    reset_na : IN  std_logic;

    ext_addr  : IN  unsigned(13 DOWNTO 0);
    ext_rd    : IN  std_logic;
    ext_wr    : IN  std_logic;
    ext_wdata : IN  uv8;
    ext_rdata : OUT uv8;

    bb_addr  : IN  unsigned(12 DOWNTO 0);
    bb_rdata : OUT uv8;

    uv_cur_field   : IN std_logic;
    uv_cur_vpos    : IN unsigned(8 DOWNTO 0);
    uv_capture_stb : IN std_logic;
    uv_capture_x   : IN uv8;
    uv_capture_y   : IN unsigned(8 DOWNTO 0);

    uv_o_x_zm   : OUT std_logic;
    uv_o_frz    : OUT std_logic;
    uv_o_enb    : OUT std_logic;
    uv_o_int    : OUT std_logic;
    uv_o_kbd    : OUT std_logic;
    uv_o_y_zm   : OUT std_logic;
    uv_o_a_b    : OUT std_logic;
    uv_o_yint_ho: OUT std_logic;
    uv_y_int    : OUT uv8;
    uv_final_mod : OUT uv8;
    uv_background: OUT uv8;

    uv_obj_addr  : IN  uv8;
    uv_obj_rdata : OUT uv8;

    dl_addr  : IN unsigned(15 DOWNTO 0);
    dl_data  : IN uv8;
    dl_wr    : IN std_logic;
    dl_index : IN uv8;

    unknown_cart_profile : IN uv8
    );
END ENTITY sys_bus;

ARCHITECTURE rtl OF sys_bus IS

  FUNCTION crc32_byte(crc : uv32; data : uv8) RETURN uv32 IS
    VARIABLE c : uv32 := crc XOR resize(data, 32);
  BEGIN
    FOR i IN 0 TO 7 LOOP
      IF c(0) = '1' THEN
        c := shift_right(c, 1) XOR x"EDB88320";
      ELSE
        c := shift_right(c, 1);
      END IF;
    END LOOP;
    RETURN c;
  END FUNCTION;

  FUNCTION is_standard_cart(crc : uv32; size : unsigned) RETURN boolean IS
    VARIABLE hash : uv32 := NOT crc;
  BEGIN
    IF size = to_unsigned(16#0800#, size'length) THEN
      RETURN hash = CART_CRC_MUSICTEACHER1 OR
             hash = CART_CRC_WORDWISE1 OR
             hash = CART_CRC_WORDWISE2 OR
             hash = CART_CRC_VIDEOARTIST OR
             hash = CART_CRC_PINBALL OR
             hash = CART_CRC_BLACKJACK;
    ELSIF size = to_unsigned(16#1000#, size'length) THEN
      RETURN hash = CART_CRC_MATHTUTOR1 OR
             hash = CART_CRC_LEMONADE OR
             hash = CART_CRC_GLADIATOR OR
             hash = CART_CRC_TENNIS OR
             hash = CART_CRC_CHECKERS OR
             hash = CART_CRC_VICE_VERSA OR
             hash = CART_CRC_FINANCIER OR
             hash = CART_CRC_DEMONSTRATION;
    END IF;
    RETURN false;
  END FUNCTION;

  SIGNAL a_eff : unsigned(13 DOWNTO 0);

  TYPE rom_t IS ARRAY (0 TO 2047) OF uv8;
  SIGNAL res1_rom : rom_t := (OTHERS => (OTHERS => '0'));
  SIGNAL res2_rom : rom_t := (OTHERS => (OTHERS => '0'));

  -- APL uses seven 2K chips; the final 2K of its image is padding.
  TYPE cart_t IS ARRAY (0 TO 16383) OF uv8;
  SIGNAL cart_rom : cart_t := (OTHERS => (OTHERS => '0'));

  TYPE cart_ram_t IS ARRAY (0 TO 1023) OF uv8;
  SIGNAL cart_ram : cart_ram_t := (OTHERS => (OTHERS => '0'));
  SIGNAL cart_ram_a  : unsigned(9 DOWNTO 0);
  SIGNAL cart_ram_we : std_logic;
  SIGNAL cart_ram_rd : std_logic;

  TYPE ram_t IS ARRAY (0 TO 1023) OF uv8;
  SIGNAL sys_ram : ram_t := (OTHERS => (OTHERS => '0'));

  SIGNAL uv_reg_addr  : uv8;
  SIGNAL uv_reg_we    : std_logic;
  SIGNAL uv_reg_wdata : uv8;
  SIGNAL uv_reg_rdata : uv8;

  SIGNAL rdata_l : uv8;

  SIGNAL bb_res2_sel   : std_logic;
  SIGNAL bb_res2_addr  : unsigned(10 DOWNTO 0);
  SIGNAL bb_res2_rdata : uv8;
  SIGNAL bb_ram_sel    : std_logic;
  SIGNAL bb_ram_addr   : unsigned(9 DOWNTO 0);
  SIGNAL bb_ram_rdata  : uv8;
  SIGNAL bb_cart_sel   : std_logic;
  SIGNAL bb_cart_addr  : unsigned(11 DOWNTO 0);
  SIGNAL bb_cart_rdata : uv8;
  SIGNAL bb_open_bus   : std_logic;

  SIGNAL dl_res1, dl_res2, dl_cart : std_logic;
  SIGNAL cs1, cs2, exp : std_logic;
  SIGNAL cart_dl_prev : std_logic := '0';
  SIGNAL cart_crc     : uv32 := (OTHERS => '1');
  SIGNAL cart_size    : unsigned(16 DOWNTO 0) := (OTHERS => '0');
  SIGNAL cart_auto_type : uv8 := to_unsigned(CART_UNRECOGNIZED, 8);
  SIGNAL cart_effective_type : uv8;

  -- Set when a cartridge download writes above 17FF. A 2K image never does,
  -- and its upper half must mirror the lower rather than read as zero.
  SIGNAL cart_big : std_logic := '0';
  SIGNAL cart_a   : unsigned(11 DOWNTO 0);
  SIGNAL cart_cpu_a : unsigned(13 DOWNTO 0);
  SIGNAL cart_bank : natural RANGE 0 TO 2 := 0;
  SIGNAL cart_exp_rom : std_logic;

BEGIN

  a_eff <= cpu_addr_fold(ext_addr);
  cart_effective_type <= cart_auto_type
                         WHEN cart_auto_type /= to_unsigned(CART_UNRECOGNIZED, 8)
                         ELSE unknown_cart_profile;


  u_uv201_regs : ENTITY work.uv201_regs
    PORT MAP (
      clk         => clk,
      reset_na    => reset_na,
      reg_addr    => uv_reg_addr,
      reg_we      => uv_reg_we,
      reg_wdata   => uv_reg_wdata,
      reg_rdata   => uv_reg_rdata,
      cur_field   => uv_cur_field,
      cur_vpos    => uv_cur_vpos,
      capture_stb => uv_capture_stb,
      capture_x   => uv_capture_x,
      capture_y   => uv_capture_y,
      o_x_zm      => uv_o_x_zm,
      o_frz       => uv_o_frz,
      o_enb       => uv_o_enb,
      o_int       => uv_o_int,
      o_kbd       => uv_o_kbd,
      o_y_zm      => uv_o_y_zm,
      o_a_b       => uv_o_a_b,
      o_yint_ho   => uv_o_yint_ho,
      y_int       => uv_y_int,
      final_mod   => uv_final_mod,
      background  => uv_background,
      obj_addr    => uv_obj_addr,
      obj_rdata   => uv_obj_rdata
      );

  uv_reg_addr  <= a_eff(7 DOWNTO 0);
  uv_reg_we    <= ext_wr WHEN (a_eff >= to_unsigned(ADDR_UV201_LO, 14) AND
                                a_eff <= to_unsigned(ADDR_UV201_HI, 14))
                  ELSE '0';
  uv_reg_wdata <= ext_wdata;


  PROCESS (clk, reset_na) IS
  BEGIN
    IF reset_na = '0' THEN
      NULL;  -- RAM contents undefined on real hardware after reset too
              -- (see doc: signature-byte-guarded clear routine runs at
              -- boot); not resetting the array avoids a large synth-time
              -- reset fan-out for no behavioral benefit.
    ELSIF rising_edge(clk) THEN
      IF ext_wr = '1' AND a_eff >= to_unsigned(ADDR_RAM_LO, 14)
                       AND a_eff <= to_unsigned(ADDR_RAM_HI, 14) THEN
        sys_ram(to_integer(a_eff - to_unsigned(ADDR_RAM_LO, 14))) <= ext_wdata;
      END IF;
    END IF;
  END PROCESS;

  -- read mux (registered).  Cyclone V M10K/MLAB have no async read port, so
  -- this is the template Quartus needs to infer block RAM for
  -- res1_rom/res2_rom/cart_rom/sys_ram instead of packing them into logic.
  -- Adds 1 clk of read latency on rdata_l/ext_rdata - covered by the
  -- existing arbiter wait states, but worth re-checking against
  -- WAIT_CPU_RDWR in uv202_pack if timing looks off in sim.

  PROCESS (clk) IS
  BEGIN
    IF rising_edge(clk) THEN
      IF a_eff <= to_unsigned(ADDR_RES1_HI, 14) THEN
        rdata_l <= res1_rom(to_integer(a_eff));

      ELSIF a_eff <= to_unsigned(ADDR_UV201_HI, 14) THEN
        rdata_l <= uv_reg_rdata;

      ELSIF a_eff <= to_unsigned(ADDR_RAM_HI, 14) THEN
        rdata_l <= sys_ram(to_integer(a_eff - to_unsigned(ADDR_RAM_LO, 14)));

      ELSIF a_eff <= to_unsigned(ADDR_CART2_HI, 14) THEN
        IF cart_ram_rd = '1' THEN
          rdata_l <= cart_ram(to_integer(cart_ram_a));
        ELSE
          rdata_l <= cart_rom(to_integer(cart_cpu_a));
        END IF;

      ELSIF a_eff <= to_unsigned(ADDR_RES2_HI, 14) THEN
        rdata_l <= res2_rom(to_integer(a_eff - to_unsigned(ADDR_RES2_LO, 14)));

      ELSIF a_eff >= to_unsigned(ADDR_EXP_LO, 14) THEN
        IF cart_ram_rd = '1' THEN
          rdata_l <= cart_ram(to_integer(cart_ram_a));
        ELSIF cart_exp_rom = '1' THEN
          rdata_l <= cart_rom(to_integer(cart_cpu_a));
        ELSE
          rdata_l <= (OTHERS => '1');
        END IF;

      ELSE
        rdata_l <= (OTHERS => '1');
      END IF;
    END IF;
  END PROCESS;

  ext_rdata <= rdata_l;


  -- One process per array: a single process selecting between them defeats
  -- GHDL's RAM inference and the netlist balloons into unrolled muxes.
  dl_res1 <= dl_wr WHEN dl_index = to_unsigned(0, 8) ELSE '0';
  dl_res2 <= dl_wr WHEN dl_index = to_unsigned(1, 8) ELSE '0';
  dl_cart <= dl_wr WHEN dl_index = to_unsigned(2, 8) ELSE '0';

  PROCESS (clk) IS
  BEGIN
    IF rising_edge(clk) THEN
      IF dl_res1 = '1' THEN
        res1_rom(to_integer(dl_addr(10 DOWNTO 0))) <= dl_data;
      END IF;
    END IF;
  END PROCESS;

  PROCESS (clk) IS
  BEGIN
    IF rising_edge(clk) THEN
      IF dl_index = to_unsigned(2, 8) THEN
        cart_dl_prev <= '1';
        IF dl_wr = '1' THEN
          IF dl_addr = to_unsigned(0, 16) THEN
            cart_crc <= crc32_byte((OTHERS => '1'), dl_data);
            cart_size <= to_unsigned(1, cart_size'length);
            cart_auto_type <= to_unsigned(CART_UNRECOGNIZED, 8);
          ELSE
            cart_crc <= crc32_byte(cart_crc, dl_data);
            cart_size <= cart_size + 1;
          END IF;
        END IF;
      ELSIF cart_dl_prev = '1' THEN
        cart_dl_prev <= '0';
        IF cart_size = to_unsigned(16#0800#, cart_size'length) AND
           (NOT cart_crc) = CART_CRC_TIMESHARE THEN
          cart_auto_type <= to_unsigned(CART_TIMESHARE, 8);
        ELSIF cart_size = to_unsigned(16#1000#, cart_size'length) AND
              (NOT cart_crc) = CART_CRC_MONEYMINDER THEN
          cart_auto_type <= to_unsigned(CART_MONEYMINDER, 8);
        ELSIF cart_size = to_unsigned(16#4000#, cart_size'length) AND
              (NOT cart_crc) = CART_CRC_COMPLANG THEN
          cart_auto_type <= to_unsigned(CART_COMPLANG, 8);
        ELSIF cart_size = to_unsigned(16#2000#, cart_size'length) AND
              (NOT cart_crc) = CART_CRC_INFOMAN THEN
          cart_auto_type <= to_unsigned(CART_INFOMAN, 8);
        ELSIF is_standard_cart(cart_crc, cart_size) THEN
          cart_auto_type <= to_unsigned(CART_STD, 8);
        END IF;
      ELSE
        cart_dl_prev <= '0';
      END IF;
    END IF;
  END PROCESS;

  PROCESS (clk) IS
  BEGIN
    IF rising_edge(clk) THEN
      IF dl_res2 = '1' THEN
        res2_rom(to_integer(dl_addr(10 DOWNTO 0))) <= dl_data;
      END IF;
    END IF;
  END PROCESS;

  PROCESS (clk) IS
  BEGIN
    IF rising_edge(clk) THEN
      IF dl_cart = '1' THEN
        cart_rom(to_integer(dl_addr(13 DOWNTO 0))) <= dl_data;
      END IF;
    END IF;
  END PROCESS;

  PROCESS (clk) IS
  BEGIN
    IF rising_edge(clk) THEN
      IF dl_cart = '1' THEN
        IF dl_addr(11) = '1' THEN
          cart_big <= '1';
        ELSIF dl_addr = x"0000" THEN
          cart_big <= '0';
        END IF;
      END IF;
    END IF;
  END PROCESS;

  cart_ram_we <= ext_wr AND cart_ram_rd;

  PROCESS (clk) IS
  BEGIN
    IF rising_edge(clk) THEN
      IF cart_ram_we = '1' THEN
        cart_ram(to_integer(cart_ram_a)) <= ext_wdata;
      END IF;
    END IF;
  END PROCESS;


  u_buffered_bus : ENTITY work.buffered_bus
    PORT MAP (
      bb_addr     => bb_addr,
      bb_rdata    => bb_rdata,
      res2_sel    => bb_res2_sel,
      res2_addr   => bb_res2_addr,
      res2_rdata  => bb_res2_rdata,
      ram_sel     => bb_ram_sel,
      ram_addr    => bb_ram_addr,
      ram_rdata   => bb_ram_rdata,
      cart_sel    => bb_cart_sel,
      cart_addr   => bb_cart_addr,
      cart_rdata  => bb_cart_rdata,
      open_bus    => bb_open_bus
      );

  PROCESS (clk) IS
  BEGIN
    IF rising_edge(clk) THEN
      bb_res2_rdata <= res2_rom(to_integer(bb_res2_addr));
      bb_ram_rdata  <= sys_ram(to_integer(bb_ram_addr));
      IF (cart_effective_type = CART_COMPLANG AND bb_cart_addr >= x"C00") OR
         (cart_effective_type = CART_INFOMAN AND bb_cart_addr(11) = '1') OR
         (cart_effective_type = CART_TIMESHARE AND bb_cart_addr(11) = '1') THEN
        bb_cart_rdata <= cart_ram(to_integer(bb_cart_addr(9 DOWNTO 0)));
      ELSE
        bb_cart_rdata <= cart_rom(to_integer(bb_cart_addr AND
                                             (cart_big & "11111111111")));
      END IF;
    END IF;
  END PROCESS;

  -- /CS1 is 1000-17FF and /CS2 is 1800-1FFF; the expansion window at
  -- 3000-3FFF has no chip select and only some mappers answer there.
  cs1 <= to_std_logic(a_eff >= to_unsigned(16#1000#, 14) AND
                      a_eff <= to_unsigned(16#17FF#, 14));
  cs2 <= to_std_logic(a_eff >= to_unsigned(16#1800#, 14) AND
                      a_eff <= to_unsigned(16#1FFF#, 14));
  exp <= to_std_logic(a_eff >= to_unsigned(ADDR_EXP_LO, 14));

  cart_a <= resize(a_eff(11 DOWNTO 0), 12) AND (cart_big & "11111111111");
  PROCESS (a_eff, cart_a, cart_effective_type, cs1, exp, cart_bank) IS
    VARIABLE chip : natural RANGE 0 TO 6;
  BEGIN
    cart_cpu_a <= resize(cart_a, 14);
    IF cart_effective_type = CART_TIMESHARE OR cart_effective_type = CART_INFOMAN THEN
      IF cs1 = '1' THEN
        cart_cpu_a <= resize(a_eff(10 DOWNTO 0), 14);
      ELSIF exp = '1' AND cart_effective_type = CART_INFOMAN THEN
        cart_cpu_a <= '0' & '1' & a_eff(11 DOWNTO 0);
      END IF;
    ELSIF cart_effective_type = CART_COMPLANG AND exp = '1' THEN
      -- C/D, E/G, E/F are the three hardware bank pairs.
      CASE cart_bank IS
        WHEN 0 => chip := 2 + to_integer(a_eff(11 DOWNTO 11));
        WHEN 1 =>
          IF a_eff(11) = '0' THEN chip := 4; ELSE chip := 6; END IF;
        WHEN 2 => chip := 4 + to_integer(a_eff(11 DOWNTO 11));
      END CASE;
      cart_cpu_a <= to_unsigned(chip * 2048, 14) OR resize(a_eff(10 DOWNTO 0), 14);
    END IF;
  END PROCESS;

  PROCESS (clk) IS
    TYPE bank_lut_t IS ARRAY (0 TO 3, 0 TO 3) OF natural RANGE 0 TO 2;
    CONSTANT bank_lut : bank_lut_t := ((0, 1, 2, 0), (2, 1, 2, 1),
                                      (0, 2, 2, 0), (2, 2, 2, 2));
  BEGIN
    IF rising_edge(clk) THEN
      IF dl_cart = '1' AND dl_addr = x"0000" THEN
        cart_bank <= 0;
      -- APL's ROM bus conflict makes both data and address select the bank.
      ELSIF reset_na = '1' AND ext_wr = '1' AND cs1 = '1' AND
            cart_effective_type = CART_COMPLANG THEN
        cart_bank <= bank_lut(to_integer(ext_wdata(1 DOWNTO 0)),
                             to_integer(a_eff(1 DOWNTO 0)));
      END IF;
    END IF;
  END PROCESS;

  cart_exp_rom <= exp AND to_std_logic(cart_effective_type = CART_COMPLANG OR
                                      cart_effective_type = CART_INFOMAN);

  cart_ram_rd <= (cs2 AND to_std_logic(cart_effective_type = CART_TIMESHARE)) OR
                 (cs2 AND to_std_logic(cart_effective_type = CART_INFOMAN)) OR
                 (cs2 AND a_eff(10) AND to_std_logic(cart_effective_type = CART_COMPLANG)) OR
                 (exp AND a_eff(11) AND to_std_logic(cart_effective_type = CART_MONEYMINDER));
  cart_ram_a  <= a_eff(9 DOWNTO 0);

END ARCHITECTURE rtl;
