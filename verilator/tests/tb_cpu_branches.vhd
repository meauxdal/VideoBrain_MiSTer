LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.base_pack.ALL;
USE work.f8_pack.ALL;

ENTITY tb_cpu_branches IS
  GENERIC (
    check_br7 : boolean := true;
    check_bt : boolean := false
  );
END ENTITY;

ARCHITECTURE test OF tb_cpu_branches IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na : std_logic := '0';
  SIGNAL dr, dw, ext_rdata : uv8;
  SIGNAL romc : uv5;
  SIGNAL phase : uint4;
  SIGNAL ext_addr : unsigned(13 DOWNTO 0);
  SIGNAL pc0 : uv16;
  SIGNAL visar : uv6;
  SIGNAL flags : uv5;
  SIGNAL setup_value : natural := 0;
  SIGNAL displacement : integer := 0;
  SIGNAL branch_opcode : uv8 := x"90";
BEGIN
  clk <= NOT clk AFTER 5 ns;

  -- Each case sets ISAR or W through real instructions, then branches.
  PROCESS(all)
  BEGIN
    ext_rdata <= x"2B"; -- NOP outside the small test program
    CASE to_integer(ext_addr) IS
      WHEN 0 => ext_rdata <= x"20"; -- LI setup_value
      WHEN 1 => ext_rdata <= to_unsigned(setup_value, 8);
      WHEN 2 =>
        IF check_br7 THEN ext_rdata <= x"0B"; -- LR IS,A
        ELSE ext_rdata <= x"59"; END IF;      -- LR J,A
      WHEN 3 =>
        IF check_br7 THEN ext_rdata <= x"8F"; -- BR7 displacement
        ELSE ext_rdata <= x"1D"; END IF;      -- LR W,J
      WHEN 4 =>
        IF check_br7 THEN ext_rdata <= to_unsigned(displacement MOD 256, 8);
        ELSE ext_rdata <= branch_opcode; END IF; -- BT/BF mask,displacement
      WHEN 5 =>
        IF NOT check_br7 THEN
          ext_rdata <= to_unsigned(displacement MOD 256, 8);
        END IF;
      WHEN OTHERS => NULL;
    END CASE;
  END PROCESS;

  cpu : ENTITY work.f8_cpu
    PORT MAP (
      clk => clk, ce => '1', reset_na => reset_na,
      dr => dr, dw => dw, dv => OPEN, romc => romc,
      tick => OPEN, phase => phase,
      po_a_n => OPEN, pi_a_n => x"FF",
      po_b_n => OPEN, pi_b_n => x"FF", port1_wr => OPEN,
      intreq => '0', acco => OPEN, visaro => visar, iozcso => flags
    );

  busif : ENTITY work.f8_busif
    PORT MAP (
      clk => clk, ce => '1', reset_na => reset_na,
      dw => dw, dr => dr, dv => OPEN, romc => romc,
      tick => '0', phase => phase,
      ext_addr => ext_addr, ext_rd => OPEN, ext_wr => OPEN,
      ext_wdata => OPEN, ext_rdata => ext_rdata,
      ext_req => OPEN, ext_class => OPEN, ext_grant => '0',
      io_addr => OPEN, io_rd => OPEN, io_wr => OPEN,
      io_wdata => OPEN, io_rdata => x"00",
      int_vector => x"0000", int_ack => OPEN,
      pc0o => pc0, pc1o => OPEN, dc0o => OPEN
    );

  PROCESS
    TYPE offsets_t IS ARRAY(natural RANGE <>) OF integer;
    CONSTANT offsets : offsets_t := (-128, -1, 0, 1, 127);
    VARIABLE operand_address, target_address : natural;
    VARIABLE taken, selected_set : boolean;
    VARIABLE cycle_start : time;
    VARIABLE w : uv5;
    VARIABLE cases : natural := 0;

    PROCEDURE next_cycle IS
    BEGIN
      LOOP
        WAIT UNTIL falling_edge(clk);
        EXIT WHEN phase = 1;
      END LOOP;
    END PROCEDURE;
  BEGIN
    FOR mask IN 0 TO 15 LOOP
      EXIT WHEN check_br7 AND mask = 1;
      EXIT WHEN NOT check_br7 AND check_bt AND mask = 8;
      IF check_bt THEN branch_opcode <= to_unsigned(16#80# + mask, 8);
      ELSE branch_opcode <= to_unsigned(16#90# + mask, 8); END IF;
      FOR value IN 0 TO 63 LOOP
        EXIT WHEN NOT check_br7 AND value = 32;
        FOR offset_index IN offsets'range LOOP
          reset_na <= '0';
          setup_value <= value;
          displacement <= offsets(offset_index);
          WAIT FOR 100 ns;
          WAIT UNTIL falling_edge(clk);
          reset_na <= '1';

          IF check_br7 THEN
            operand_address := 4;
            taken := value MOD 8 /= 7;
          ELSE
            operand_address := 5;
            w := to_unsigned(value, 5);
            -- Include directly loaded Z=1,S=0 states; do not assume ALU flags.
            -- Check each selected flag independently; ICB is never selected.
            selected_set := false;
            FOR bit_index IN 0 TO 3 LOOP
              IF (mask / (2**bit_index)) MOD 2 = 1 AND w(bit_index) = '1' THEN
                selected_set := true;
              END IF;
            END LOOP;
            IF check_bt THEN
              taken := selected_set;
              ASSERT test_bt(to_unsigned(mask, 3), w) = taken
                REPORT "BT predicate failed: mask=" & integer'image(mask) &
                  " W=" & integer'image(value) SEVERITY failure;
            ELSE
              taken := NOT selected_set;
              ASSERT test_bf(to_unsigned(mask, 4), w) = taken
                REPORT "BF predicate failed: mask=" & integer'image(mask) &
                  " W=" & integer'image(value) SEVERITY failure;
            END IF;
          END IF;

          LOOP
            next_cycle;
            EXIT WHEN romc = ROMC_00 AND pc0 = operand_address - 1;
          END LOOP;
          next_cycle;
          IF NOT check_br7 THEN
            ASSERT romc = ROMC_1C
              REPORT "BT/BF must begin with an idle short cycle" SEVERITY failure;
            cycle_start := now;
            next_cycle;
            ASSERT now - cycle_start = 80 ns
              REPORT "BT/BF idle cycle must be short" SEVERITY failure;
          END IF;

          ASSERT pc0 = operand_address
            REPORT "Branch operand address is incorrect" SEVERITY failure;
          IF taken THEN
            ASSERT romc = ROMC_01
              REPORT "Taken branch must use ROMC 01" SEVERITY failure;
            target_address := (operand_address + offsets(offset_index)) MOD 65536;
          ELSE
            ASSERT romc = ROMC_03
              REPORT "Untaken branch must use ROMC 03" SEVERITY failure;
            target_address := operand_address + 1;
          END IF;
          cycle_start := now;
          next_cycle;
          IF taken THEN
            ASSERT now - cycle_start = 120 ns
              REPORT "Taken branch operand must use a long cycle" SEVERITY failure;
          ELSE
            ASSERT now - cycle_start = 80 ns
              REPORT "Untaken branch operand must use a short cycle" SEVERITY failure;
          END IF;
          ASSERT romc = ROMC_00 AND pc0 = target_address
            REPORT "Incorrect branch destination" SEVERITY failure;
          IF check_br7 THEN
            ASSERT visar = to_unsigned(value, 6)
              REPORT "BR7 changed ISAR" SEVERITY failure;
          ELSE
            ASSERT flags = w REPORT "BT/BF changed status flags" SEVERITY failure;
          END IF;
          cycle_start := now;
          next_cycle;
          ASSERT now - cycle_start = 80 ns
            REPORT "Opcode fetch following branch must remain short" SEVERITY failure;
          cases := cases + 1;
        END LOOP;
      END LOOP;
    END LOOP;
    REPORT "CPU branch tests passed: " & integer'image(cases) & " cases";
    std.env.stop;
    WAIT;
  END PROCESS;

  PROCESS
  BEGIN
    WAIT FOR 5 ms;
    ASSERT false REPORT "CPU branch tests timed out" SEVERITY failure;
    WAIT;
  END PROCESS;
END ARCHITECTURE;
