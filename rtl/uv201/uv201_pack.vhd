
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY work;
USE work.base_pack.ALL;

PACKAGE uv201_pack IS

  -- Payload is a gap pixel count or eight sprite pixels, selected by is_gap.
  -- Colour combines intensity (0820-082F) and hue (0810-081F), before XOR.
  TYPE uv201_fifo_entry_t IS RECORD
    is_gap  : std_logic;
    payload : uv8;
    color   : std_logic_vector(4 DOWNTO 0);
  END RECORD;

  CONSTANT UV201_FIFO_ENTRY_ZERO : uv201_fifo_entry_t := (
    is_gap  => '0',
    payload => (OTHERS => '0'),
    color   => (OTHERS => '0')
    );

  CONSTANT UV201_FIFO_DEPTH : natural := 10;

END PACKAGE uv201_pack;

PACKAGE BODY uv201_pack IS
END PACKAGE BODY uv201_pack;
