LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.env.ALL;
USE work.base_pack.ALL;

ENTITY tb_audio_io IS END ENTITY;

ARCHITECTURE test OF tb_audio_io IS
  SIGNAL clk : std_logic := '0';
  SIGNAL reset_na : std_logic := '0';
  SIGNAL port_a_n, port_b_n : uv8 := (OTHERS => '0');
  SIGNAL port_b_wr : std_logic := '0';
  SIGNAL code : std_logic_vector(1 DOWNTO 0);
  SIGNAL stb : std_logic;
BEGIN
  clk <= NOT clk AFTER 5 ns;

  dut : ENTITY work.videobrain_io
    PORT MAP (
      clk => clk, reset_na => reset_na,
      port_a_n => port_a_n, port_b_n => port_b_n,
      port_b_wr => port_b_wr, port_b_in_n => OPEN,
      kbd_matrix => (OTHERS => '0'), joy_fire => "0000", uv_kbd => '1',
      key_latch => OPEN, joy_enable => OPEN,
      accessory_p5 => OPEN, accessory_p1 => OPEN,
      audio_code => code, audio_stb => stb
    );

  PROCESS
    PROCEDURE step IS
    BEGIN
      WAIT UNTIL rising_edge(clk);
      WAIT FOR 1 ns;
    END PROCEDURE;

    PROCEDURE write_clock(level : std_logic) IS
    BEGIN
      WAIT UNTIL falling_edge(clk);
      port_b_n(4) <= level;
      port_b_wr <= '1';
      step;
    END PROCEDURE;

    VARIABLE held : std_logic_vector(1 DOWNTO 0) := "00";
  BEGIN
    step;
    reset_na <= '1';
    step;
    FOR value IN 0 TO 3 LOOP
      -- Physical I/O-01 is U16A, the greater DAC weight; I/O-00 is U16B.
      port_a_n <= to_unsigned(value, 8);
      write_clock('0');
      ASSERT stb = '0' AND code = held
        REPORT "DAC changed on falling physical I/O-14" SEVERITY failure;
      write_clock('1');
      held := std_logic_vector(to_unsigned(value, 2));
      ASSERT stb = '1' AND code = held
        REPORT "DAC did not latch physical I/O-01/00 on rising I/O-14"
        SEVERITY failure;

      port_a_n <= to_unsigned(3 - value, 8);
      port_b_wr <= '0';
      step;
      ASSERT stb = '0' AND code = held
        REPORT "DAC followed data without a clock edge" SEVERITY failure;
      write_clock('1');
      ASSERT stb = '0' AND code = held
        REPORT "Repeated high clock write retriggered DAC" SEVERITY failure;
    END LOOP;
    reset_na <= '0';
    step;
    ASSERT stb = '0' AND code = "00"
      REPORT "Audio interface reset failed" SEVERITY failure;
    REPORT "Audio physical pin, edge and hold tests passed";
    stop;
  END PROCESS;
END ARCHITECTURE;
