
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY work;
USE work.base_pack.ALL;
USE work.uv202_pack.ALL;

ENTITY uv202_arbiter IS
  PORT (
    clk        : IN  std_logic;
    reset_na   : IN  std_logic;
    brclk_ena  : IN  std_logic;
    bus_phase  : IN  uv2;

    cpu_req    : IN  std_logic;
    cpu_class  : IN  bus_access_t;
    cpu_grant  : OUT std_logic;
    cpu_wack   : OUT std_logic;
    cpu_stall  : OUT std_logic;

    umireq0    : IN  std_logic;
    umireq1    : IN  std_logic;
    dmareq0    : OUT std_logic;
    dmareq1    : OUT std_logic;

    busy       : OUT std_logic
    );
END ENTITY uv202_arbiter;

ARCHITECTURE rtl OF uv202_arbiter IS

  TYPE state_t IS (ST_IDLE, ST_SETUP, ST_BODY, ST_CPU_ACK, ST_DMA_NEXT);
  TYPE grant_kind_t IS (GK_NONE, GK_CPU, GK_DMA0, GK_DMA1);

  SIGNAL state      : state_t := ST_IDLE;
  SIGNAL grant_kind : grant_kind_t := GK_NONE;
  SIGNAL body_len   : natural RANGE 0 TO 15 := 0;
  SIGNAL body_cnt   : natural RANGE 0 TO 15 := 0;
  SIGNAL dma_rr     : std_logic := '0';
  SIGNAL cpu_pending : std_logic := '0';

  SIGNAL cpu_wack_l  : std_logic := '0';
  SIGNAL cpu_grant_l : std_logic := '0';
  SIGNAL dmareq0_l   : std_logic := '0';
  SIGNAL dmareq1_l   : std_logic := '0';

  FUNCTION cpu_body_len(c : bus_access_t; p : uv2) RETURN natural IS
  BEGIN
    IF c = ACC_UV201_RD OR c = ACC_UV201_WR THEN
      -- UV201 adds 1..4 BRCLKs, aligned to its modulo-four bus phase.
      RETURN WAIT_CPU_RDWR + 4 - to_integer(p);
    ELSE
      RETURN WAIT_CPU_RDWR;
    END IF;
  END FUNCTION;

  FUNCTION dma_kind(r0, r1, rr : std_logic) RETURN grant_kind_t IS
  BEGIN
    IF r0 = '1' AND (r1 = '0' OR rr = '0') THEN RETURN GK_DMA0;
    ELSIF r1 = '1' THEN RETURN GK_DMA1;
    ELSE RETURN GK_NONE; END IF;
  END FUNCTION;

BEGIN

  PROCESS(clk, reset_na) IS
    VARIABLE next_dma : grant_kind_t;
  BEGIN
    IF reset_na = '0' THEN
      state <= ST_IDLE;
      grant_kind <= GK_NONE;
      body_len <= 0;
      body_cnt <= 0;
      dma_rr <= '0';
      cpu_pending <= '0';
      cpu_wack_l <= '0';
      cpu_grant_l <= '0';
      dmareq0_l <= '0';
      dmareq1_l <= '0';

    ELSIF rising_edge(clk) THEN
      dmareq0_l <= '0';
      dmareq1_l <= '0';
      next_dma := dma_kind(umireq0, umireq1, dma_rr);

      IF state = ST_CPU_ACK THEN
        IF cpu_req = '0' THEN
          cpu_grant_l <= '0';
          grant_kind <= next_dma;
          IF next_dma /= GK_NONE THEN
            body_len <= WAIT_DMA_BODY;
            body_cnt <= 0;
            cpu_pending <= '0';
            IF brclk_ena = '1' THEN state <= ST_BODY;
            ELSE state <= ST_SETUP; END IF;
            IF umireq0 = '1' AND umireq1 = '1' THEN dma_rr <= NOT dma_rr; END IF;
          ELSE
            state <= ST_IDLE;
          END IF;
        END IF;

      ELSIF brclk_ena = '1' THEN
        CASE state IS
          WHEN ST_IDLE =>
            cpu_wack_l <= '0';
            cpu_grant_l <= '0';

            IF cpu_req = '1' THEN
              grant_kind <= GK_CPU;
              cpu_wack_l <= '1';
              body_len <= cpu_body_len(cpu_class, bus_phase);
              state <= ST_SETUP;

            ELSIF next_dma /= GK_NONE THEN
              grant_kind <= next_dma;
              body_len <= WAIT_DMA_BODY;
              cpu_pending <= '0';
              IF umireq0 = '1' AND umireq1 = '1' THEN dma_rr <= NOT dma_rr; END IF;
              state <= ST_SETUP;

            ELSE
              grant_kind <= GK_NONE;
            END IF;

          WHEN ST_SETUP =>
            body_cnt <= 0;
            state <= ST_BODY;

          WHEN ST_BODY =>
            IF body_cnt = body_len - 1 THEN
              CASE grant_kind IS
                WHEN GK_CPU =>
                  cpu_grant_l <= '1';
                  cpu_wack_l <= '0';
                  state <= ST_CPU_ACK;
                WHEN GK_DMA0 | GK_DMA1 =>
                  IF grant_kind = GK_DMA0 THEN dmareq0_l <= '1';
                  ELSE dmareq1_l <= '1'; END IF;
                  IF cpu_req = '1' THEN
                    grant_kind <= GK_CPU;
                    cpu_wack_l <= '1';
                    body_len <= cpu_body_len(cpu_class, bus_phase);
                    body_cnt <= 0;
                    -- Only a request present before the last DMA cycle overlaps setup.
                    IF cpu_pending = '1' THEN state <= ST_BODY;
                    ELSE state <= ST_SETUP; END IF;
                  ELSE
                    grant_kind <= GK_NONE;
                    state <= ST_DMA_NEXT;
                  END IF;
                WHEN OTHERS =>
                  grant_kind <= GK_NONE;
                  state <= ST_IDLE;
              END CASE;
            ELSE
              body_cnt <= body_cnt + 1;
              IF grant_kind /= GK_CPU AND body_cnt = body_len - 2 THEN
                cpu_pending <= cpu_req;
              END IF;
            END IF;

          WHEN ST_DMA_NEXT =>
            IF cpu_req = '1' THEN
              grant_kind <= GK_CPU;
              cpu_wack_l <= '1';
              body_len <= cpu_body_len(cpu_class, bus_phase);
              state <= ST_SETUP;
            ELSIF next_dma /= GK_NONE THEN
              grant_kind <= next_dma;
              body_len <= WAIT_DMA_BODY;
              body_cnt <= 1;
              cpu_pending <= '0';
              IF umireq0 = '1' AND umireq1 = '1' THEN dma_rr <= NOT dma_rr; END IF;
              state <= ST_BODY;
            ELSE
              state <= ST_IDLE;
            END IF;

          WHEN OTHERS =>
            NULL;
        END CASE;
      END IF;
    END IF;
  END PROCESS;

  cpu_grant <= cpu_grant_l;
  cpu_wack  <= cpu_wack_l;
  cpu_stall <= '0' WHEN state = ST_CPU_ACK ELSE cpu_req;
  dmareq0   <= dmareq0_l;
  dmareq1   <= dmareq1_l;
  busy      <= to_std_logic(state /= ST_IDLE);

END ARCHITECTURE rtl;
