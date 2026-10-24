LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.base_pack.ALL;

ENTITY tb_f3853_timer IS
  GENERIC (divider : positive := 31);
END ENTITY;

ARCHITECTURE test OF tb_f3853_timer IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na, ce, io_wr, ext_int, int_ack : std_logic := '0';
  SIGNAL address, data : uv8 := x"00";
  SIGNAL request : std_logic;
  SIGNAL vector : uv16;
BEGIN
  clk <= NOT clk AFTER 5 ns;
  dut : ENTITY work.f3853 GENERIC MAP (PRESCALE => divider)
    PORT MAP (clk => clk, reset_na => reset_na, ce => ce,
      io_addr => address, io_rd => '0', io_wr => io_wr, io_wdata => data,
      io_rdata => OPEN, io_sel => OPEN, ext_int => ext_int,
      int_req => request, int_vector => vector, int_ack => int_ack);

  PROCESS
    TYPE bytes_t IS ARRAY(natural RANGE <>) OF uv8;
    -- Mostek 1978 3870/F8 Data Book, printed p.170, Table 2.
    -- Index is the published timer count; value is the byte to load.
    CONSTANT seeds : bytes_t := (
      x"7F",x"BF",x"5F",x"2F",x"97",x"CB",x"E5",x"72",x"39",x"1C",
      x"0E",x"87",x"43",x"A1",x"D0",x"E8",x"F4",x"7A",x"3D",x"1E",
      x"0F",x"07",x"03",x"01",x"00",x"80",x"C0",x"60",x"B0",x"D8",
      x"EC",x"F6",x"7B",x"BD",x"5E",x"AF",x"D7",x"6B",x"35",x"1A",
      x"0D",x"06",x"83",x"41",x"A0",x"50",x"A8",x"54",x"AA",x"55",
      x"2A",x"15",x"8A",x"C5",x"E2",x"F1",x"F8",x"7C",x"3E",x"9F",
      x"CF",x"E7",x"73",x"B9",x"5C",x"AE",x"57",x"2B",x"95",x"CA",
      x"65",x"32",x"99",x"CC",x"66",x"B3",x"59",x"2C",x"16",x"0B",
      x"05",x"02",x"81",x"40",x"20",x"10",x"08",x"84",x"C2",x"61",
      x"30",x"98",x"4C",x"26",x"13",x"89",x"44",x"22",x"11",x"88",
      x"C4",x"62",x"B1",x"58",x"AC",x"56",x"AB",x"D5",x"6A",x"B5",
      x"5A",x"AD",x"D6",x"EB",x"75",x"BA",x"DD",x"6E",x"B7",x"5B",
      x"2D",x"96",x"4B",x"A5",x"D2",x"E9",x"74",x"3A",x"9D",x"CE",
      x"67",x"33",x"19",x"8C",x"C6",x"63",x"31",x"18",x"0C",x"86",
      x"C3",x"E1",x"70",x"38",x"9C",x"4E",x"27",x"93",x"C9",x"E4",
      x"F2",x"79",x"BC",x"DE",x"EF",x"77",x"BB",x"5D",x"2E",x"17",
      x"8B",x"45",x"A2",x"51",x"28",x"14",x"0A",x"85",x"42",x"21",
      x"90",x"48",x"24",x"12",x"09",x"04",x"82",x"C1",x"E0",x"F0",
      x"78",x"3C",x"9E",x"4F",x"A7",x"D3",x"69",x"34",x"9A",x"4D",
      x"A6",x"53",x"29",x"94",x"4A",x"25",x"92",x"49",x"A4",x"52",
      x"A9",x"D4",x"EA",x"F5",x"FA",x"7D",x"BE",x"DF",x"6F",x"37",
      x"1B",x"8D",x"46",x"23",x"91",x"C8",x"64",x"B2",x"D9",x"6C",
      x"B6",x"DB",x"6D",x"36",x"9B",x"CD",x"E6",x"F3",x"F9",x"FC",
      x"7E",x"3F",x"1F",x"8F",x"47",x"A3",x"D1",x"68",x"B4",x"DA",
      x"ED",x"76",x"3B",x"1D",x"8E",x"C7",x"E3",x"71",x"B8",x"DC",
      x"EE",x"F7",x"FB",x"FD",x"FE"
    );

    PROCEDURE tick(enable : std_logic := '0') IS
    BEGIN
      ce <= enable;
      WAIT UNTIL rising_edge(clk);
      WAIT FOR 1 ns;
    END PROCEDURE;

    PROCEDURE write_port(a, d : uv8; enable : std_logic := '0') IS
    BEGIN
      address <= a; data <= d; io_wr <= '1';
      tick(enable);
      io_wr <= '0';
      tick;
    END PROCEDURE;

    PROCEDURE acknowledge IS
    BEGIN
      int_ack <= '1'; tick;
      int_ack <= '0'; tick;
      ASSERT request = '0' REPORT "Timer acknowledge did not clear IRQ" SEVERITY failure;
    END PROCEDURE;

    PROCEDURE wait_expiry(clocks : positive; context_v : string) IS
    BEGIN
      FOR i IN 1 TO clocks LOOP
        -- Disabled enables must not advance the prescaler or shift register.
        IF i MOD 7 = 0 THEN
          tick;
          ASSERT request = '0' REPORT context_v & ": advanced without ce" SEVERITY failure;
        END IF;
        tick('1');
        IF i < clocks THEN
          ASSERT request = '0' REPORT context_v & ": early timeout at " & integer'image(i) SEVERITY failure;
        ELSE
          ASSERT request = '1' REPORT context_v & ": missing timeout" SEVERITY failure;
        END IF;
      END LOOP;
      ce <= '0';
    END PROCEDURE;
  BEGIN
    tick; reset_na <= '1'; tick;
    write_port(x"0C", x"12"); write_port(x"0D", x"B4");
    write_port(x"0E", x"03");
    ASSERT vector = x"1234" REPORT "Timer vector bit 7 must be clear" SEVERITY failure;
    ASSERT seeds'length = 255 SEVERITY failure;
    FOR count IN seeds'range LOOP
      -- F3852/F3853 Fig.6: first timer clock two input periods after load.
      -- Subsequent timer clocks are divided by 31 (or the test divider).
      write_port(x"0F", seeds(count), '1');
      ASSERT request = '0' REPORT "Reload did not clear timer IRQ" SEVERITY failure;
      wait_expiry(2 + count*divider, "seed index=" & integer'image(count));
      acknowledge;
      wait_expiry(255*divider, "repeat index=" & integer'image(count));
      acknowledge;
    END LOOP;

    -- Timeout while masked survives control writes and an external interrupt.
    write_port(x"0E", x"00"); write_port(x"0F", x"7F");
    tick('1'); tick('1'); tick;
    ASSERT request = '0' REPORT "Masked timer exposed an IRQ" SEVERITY failure;
    write_port(x"0E", x"01");
    ASSERT vector = x"12B4" REPORT "External vector bit 7 must be set" SEVERITY failure;
    ext_int <= '1'; tick; ext_int <= '0'; tick;
    ASSERT request = '1' REPORT "External request lost behind masked timer" SEVERITY failure;
    acknowledge;
    write_port(x"0E", x"03");
    ASSERT request = '1' REPORT "Masked timer expiry was discarded" SEVERITY failure;
    acknowledge;

    -- Disabling and re-enabling must not discard an unacknowledged timer IRQ.
    write_port(x"0F", x"7F"); tick('1'); tick('1'); tick;
    write_port(x"0E", x"00");
    ASSERT request = '0' REPORT "Timer IRQ not masked" SEVERITY failure;
    write_port(x"0E", x"03");
    ASSERT request = '1' REPORT "Timer control write cleared pending timeout" SEVERITY failure;
    write_port(x"0F", x"FF", '1');
    ASSERT request = '0' REPORT "Stopping timer retained pending IRQ" SEVERITY failure;
    FOR i IN 1 TO 256*divider LOOP
      tick('1');
      ASSERT request = '0' REPORT "FF failed to stop timer" SEVERITY failure;
    END LOOP;

    -- Reload wins when it coincides with the old timer's expiry clock.
    write_port(x"0F", x"7F"); tick('1');
    write_port(x"0F", x"C8", '1');
    ASSERT request = '0' REPORT "Old timeout overrode reload" SEVERITY failure;
    wait_expiry(2 + 215*divider, "C8 reload");
    acknowledge;

    -- Fig.4's clear input wins over a timeout on the acknowledge edge.
    write_port(x"0F", x"7F"); tick('1');
    int_ack <= '1'; tick('1'); int_ack <= '0'; tick;
    ASSERT request = '0' REPORT "Acknowledge/expiry collision retained IRQ" SEVERITY failure;
    wait_expiry(255*divider, "repeat after acknowledge/expiry");
    acknowledge;

    -- A coincident load still starts a fresh interval, including its delay,
    -- when acknowledge and the old expiry occur on that same edge.
    write_port(x"0F", x"7F"); tick('1');
    int_ack <= '1'; write_port(x"0F", x"C8", '1'); int_ack <= '0';
    ASSERT request = '0' REPORT "Acknowledge/expiry/reload retained IRQ" SEVERITY failure;
    wait_expiry(2 + 215*divider, "C8 acknowledge/expiry/reload");
    acknowledge;

    -- Timer reload clears only timer state, not a pending external request.
    write_port(x"0E", x"01");
    ext_int <= '1'; tick; ext_int <= '0'; tick;
    write_port(x"0F", x"FF");
    ASSERT request = '1' REPORT "Timer load cleared external request" SEVERITY failure;
    write_port(x"0E", x"01");
    ASSERT request = '0' REPORT "Control write failed to rearm external IRQ" SEVERITY failure;
    reset_na <= '0'; tick; reset_na <= '1'; tick;
    ASSERT request = '0' REPORT "Reset retained IRQ" SEVERITY failure;
    REPORT "3853 timer: 255 seed delays/repeats, masking, reload, stop and IRQ isolation passed; divider=" & integer'image(divider);
    std.env.stop;
    WAIT;
  END PROCESS;
END ARCHITECTURE;
