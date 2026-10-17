`timescale 1ns/1ps
module videobrain_tape #(
    parameter CLOCK_HZ = 14318180
)(
    input wire clk,
    input wire reset,
    input wire img_mounted,
    input wire img_readonly,
    input wire [63:0] img_size,
    input wire arm,
    input wire record_data,
    input wire record_enable,
    input wire playback_enable,
    output reg playback_data = 1,
    output wire busy,
    output wire writable,
    output reg armed = 0,
    output reg error = 0,
    output reg [31:0] sd_lba = 0,
    output reg sd_rd = 0,
    output reg sd_wr = 0,
    input wire sd_ack,
    input wire [8:0] sd_buff_addr,
    input wire [7:0] sd_buff_dout,
    output wire [7:0] sd_buff_din,
    input wire sd_buff_wr
);

localparam IDLE = 0, RECORD = 1, FLUSH = 2, PLAY = 3;
localparam HEADER = 0, INVALIDATE = 1, WRITE_DATA = 2, COMMIT = 3, READ_DATA = 4;
localparam [31:0] MAGIC = 32'h31544256; // VBT1
reg [1:0] mode = IDLE, io_state = 0;
reg [2:0] operation = HEADER;
reg mounted = 0, readonly = 1, recognized = 0, valid = 0;
reg mount_pending = 0;
reg [31:0] capacity = 0, length = 0;
reg [31:0] header_magic = 0, header_clock = 0, header_length = 0;
reg [31:0] produced = 0, transferred = 0, consumed = 0;
reg [9:0] io_base = 0;
reg [30:0] elapsed = 1, remaining = 0;
reg level = 1, playing = 0;
reg record_d = 0, playback_d = 0, arm_d = 0;

// Four KiB absorbs SD service latency without changing the tape clock.
wire [31:0] play_sample;
wire [31:0] sd_sample;
reg [1:0] sd_byte;
reg [7:0] header_byte;
wire [9:0] core_index = capture ? produced[9:0] : consumed[9:0];
wire [9:0] buffer_index = io_base + {3'd0, sd_buff_addr[8:2]};
wire capture = mode == RECORD && !reset && !img_mounted && !error &&
               (!record_enable || record_data != level || &elapsed);
wire capture_room = produced < capacity && produced - transferred < 1024;
wire [31:0] capture_sample = {level, elapsed};
wire [31:0] write_length = operation == COMMIT ? produced : 32'hffffffff;
assign busy = mode != IDLE || io_state != 0 || mount_pending;
assign writable = mounted && recognized && !readonly && !busy;
assign sd_buff_din = operation == WRITE_DATA ? sd_sample[sd_byte*8 +: 8] : header_byte;

// Each byte bank has one core port and one SD port.
genvar b;
generate
    for (b = 0; b < 4; b = b + 1) begin : buffer_bank
        reg [7:0] samples[1024];
        reg [7:0] core_q, sd_q;
        assign play_sample[b*8 +: 8] = core_q;
        assign sd_sample[b*8 +: 8] = sd_q;

        always @(posedge clk) begin
            core_q <= samples[core_index];
            if (capture && capture_room)
                samples[core_index] <= capture_sample[b*8 +: 8];
        end
        always @(posedge clk) begin
            sd_q <= samples[buffer_index];
            if (sd_buff_wr && operation == READ_DATA && io_state != 0 &&
                sd_buff_addr[1:0] == b)
                samples[buffer_index] <= sd_buff_dout;
        end
    end
endgenerate

always @(posedge clk) begin
    sd_byte <= sd_buff_addr[1:0];
    case (sd_buff_addr[8:2])
        0: header_byte <= MAGIC[sd_buff_addr[1:0]*8 +: 8];
        1: header_byte <= 8'(CLOCK_HZ >> (sd_buff_addr[1:0] * 8));
        2: header_byte <= write_length[sd_buff_addr[1:0]*8 +: 8];
        default: header_byte <= 0;
    endcase
end

task request(input [2:0] op, input [31:0] lba, input [9:0] base);
begin
    operation <= op;
    sd_lba <= lba;
    io_base <= base;
    sd_rd <= op == HEADER || op == READ_DATA;
    sd_wr <= op != HEADER && op != READ_DATA;
    io_state <= 1;
end
endtask

always @(posedge clk) begin
    record_d <= record_enable;
    playback_d <= playback_enable;
    arm_d <= arm;

    if (sd_buff_wr && operation == HEADER && io_state != 0) begin
        case (sd_buff_addr[8:2])
            0: header_magic[sd_buff_addr[1:0]*8 +: 8] <= sd_buff_dout;
            1: header_clock[sd_buff_addr[1:0]*8 +: 8] <= sd_buff_dout;
            2: header_length[sd_buff_addr[1:0]*8 +: 8] <= sd_buff_dout;
            default: ;
        endcase
    end

    // A request stays asserted until ACK rises; buffers stay stable until it falls.
    if (io_state == 1 && sd_ack) begin
        sd_rd <= 0;
        sd_wr <= 0;
        io_state <= 2;
    end
    if (io_state == 2 && !sd_ack) begin
        io_state <= 0;
        case (operation)
            HEADER: if (!mount_pending && mounted) begin
                recognized <= header_magic == MAGIC && header_clock == CLOCK_HZ;
                valid <= header_magic == MAGIC && header_clock == CLOCK_HZ &&
                         header_length <= capacity;
                length <= header_length;
                error <= header_magic != MAGIC || header_clock != CLOCK_HZ ||
                         header_length > capacity;
            end
            WRITE_DATA, READ_DATA: transferred <= transferred + 128;
            COMMIT: if (mode == FLUSH && !reset && !error) begin
                length <= produced;
                valid <= 1;
                mode <= IDLE;
            end
            default: ;
        endcase
    end

    if (io_state == 0) begin
        if (mount_pending) begin
            mount_pending <= 0;
            header_magic <= 0;
            header_clock <= 0;
            header_length <= 0;
            request(HEADER, 0, 0);
        end else if (mode == RECORD || mode == FLUSH) begin
            if (!error && produced > transferred &&
                (produced - transferred >= 128 || mode == FLUSH))
                request(WRITE_DATA, 1 + (transferred >> 7), transferred[9:0]);
            else if (mode == FLUSH && !error && transferred >= produced)
                request(COMMIT, 0, 0);
        end else if (mode == PLAY && transferred < length &&
                     transferred - consumed <= 896)
            request(READ_DATA, 1 + (transferred >> 7), transferred[9:0]);
    end

    if (arm && !arm_d && writable) begin
        armed <= !armed;
        error <= 0;
    end

    if (record_enable && !record_d) begin
        armed <= 0;
        if (armed && writable && !playback_enable) begin
            mode <= RECORD;
            produced <= 0;
            transferred <= 0;
            elapsed <= 1;
            level <= record_data;
            valid <= 0;
            error <= 0;
            request(INVALIDATE, 0, 0);
        end else error <= 1;
    end
    if (mode == RECORD) begin
        if (capture) begin
            if (capture_room) begin
                produced <= produced + 1'b1;
                elapsed <= 1;
                level <= record_data;
                if (!record_enable) mode <= FLUSH;
            end else begin
                error <= 1;
                mode <= IDLE;
            end
        end else elapsed <= elapsed + 1'b1;
    end

    if (playback_enable && !playback_d) begin
        armed <= 0;
        if (!busy && valid && length != 0 && !record_enable) begin
            mode <= PLAY;
            transferred <= 0;
            consumed <= 0;
            remaining <= 0;
            playing <= 0;
            error <= 0;
        end else error <= 1;
    end
    if (mode == PLAY) begin
        if (!playback_enable) begin
            mode <= IDLE;
            playback_data <= 1;
        end else if (!playing) begin
            if (transferred >= 1024 || transferred >= length) playing <= 1;
        end else if (remaining != 0) remaining <= remaining - 1'b1;
        else if (consumed < length) begin
            if (consumed < transferred && play_sample[30:0] >= 2) begin
                playback_data <= play_sample[31];
                remaining <= play_sample[30:0] - 1'b1;
                consumed <= consumed + 1'b1;
            end else begin
                error <= 1;
                mode <= IDLE;
                playback_data <= 1;
            end
        end else playback_data <= 1;
    end

    // Finish any outstanding SD handshake after a machine reset or media change.
    if (reset || img_mounted) begin
        mode <= IDLE;
        armed <= 0;
        playback_data <= 1;
    end
    if (img_mounted) begin
        mounted <= img_size >= 1024 && img_size[63:32] == 0;
        readonly <= img_readonly;
        recognized <= 0;
        valid <= 0;
        capacity <= (({9'd0, img_size[31:9]} - 1'b1) << 7);
        mount_pending <= img_size >= 1024 && img_size[63:32] == 0;
        error <= img_size != 0 && (img_size < 1024 || img_size[63:32] != 0);
    end
end
endmodule
