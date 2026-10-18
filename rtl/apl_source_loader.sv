`timescale 1ns/1ps
module apl_source_loader #(
    parameter [7:0] KEY_FRAMES = 8,
    parameter [7:0] LINE_FRAMES = 64
)(
    input wire clk,
    input wire reset,
    input wire frame_tick,
    input wire download,
    input wire wr,
    input wire [24:0] addr,
    input wire [7:0] data,
    input wire available,
    input wire symbols,
    input wire [1:0] speed,
    input wire music_playback,
    input wire auto_repeat,
    input wire enabled,
    input wire cancel,
    output wire busy,
    output reg complete = 0,
    output reg error = 0,
    output reg [35:0] keys = 0
);

localparam IDLE = 0, RECEIVE = 1, WAIT_START = 2, READ_KEY = 3,
           SELECT_KEY = 4, HOLD_KEY = 5, RELEASE_KEY = 6, LINE_WAIT = 7,
           READ_HOLD = 8, SELECT_HOLD = 9, READ_GAP = 10, SELECT_GAP = 11;
localparam [7:0] MUSIC_REPLAY = 8'hfd, MUSIC_RECORD = 8'hfe;
reg [3:0] state = IDLE;
reg download_d = 0;
reg bad = 0;
reg [12:0] received = 0;
reg [15:0] length = 0, expected_crc = 0, crc = 16'hffff;
reg [11:0] position = 0;
reg [7:0] memory [0:4095];
reg [7:0] token;
reg [9:0] frames = 0;
reg [6:0] line_length = 0;
wire [9:0] line_frames = {2'd0, LINE_FRAMES} +
                         (line_length > 16 ? ({3'd0, line_length} - 10'd16) << 2 : 10'd0);
reg shifting = 0, shifted = 0, started = 0;
reg timed = 0;
reg playback = 0;
reg recording = 0;
reg [6:0] music_notes = 0;
reg [7:0] key_frames = KEY_FRAMES;
wire [7:0] control_frames = key_frames < 8 ? 8'd8 : key_frames;
reg [1:0] payload_phase = 0;
reg [7:0] event_key, hold_frames, gap_frames;

function automatic [15:0] crc_byte(input [15:0] old_crc, input [7:0] byte_value);
    reg [15:0] value;
    integer i;
    begin
        value = old_crc ^ {byte_value, 8'd0};
        for (i = 0; i < 8; i = i + 1)
            value = value[15] ? (value << 1) ^ 16'h1021 : value << 1;
        crc_byte = value;
    end
endfunction

function automatic valid_key(input [7:0] value);
    begin
        if (value[7]) valid_key = value == 8'h93 || value == 8'h9b;
        else valid_key = value[5:0] < 35 && value[5:0] != 11 &&
                         value[5:0] != 15 && value[5:0] != 19 &&
                         value[5:0] != 23 && value[5:0] != 27 && value[5:0] != 31;
    end
endfunction

function automatic music_note(input [7:0] value);
    begin
        case (value)
            1, 7, 11, 12, 19, 22, 24, 28, 33: music_note = 0;
            default: music_note = value < 36;
        endcase
    end
endfunction

assign busy = state != IDLE;

// Synchronous RAM read; READ_KEY allows its latency before selection.
always @(posedge clk) begin
    if (download && wr && addr >= 8 && addr < 4104)
        memory[addr[11:0] - 12'd8] <= data;
    token <= memory[position];
end

always @(posedge clk) begin
    download_d <= download;
    if (reset) begin
        state <= IDLE;
        error <= 0;
        keys <= 0;
        started <= 0;
        complete <= 0;
        line_length <= 0;
    end else if (download && !download_d) begin
        state <= RECEIVE;
        bad <= wr && (addr != 0 || data != "V");
        received <= wr ? 1 : 0;
        length <= 0;
        expected_crc <= 0;
        crc <= 16'hffff;
        error <= 0;
        keys <= 0;
        started <= 0;
        complete <= 0;
        timed <= 0;
        payload_phase <= 0;
        playback <= music_playback;
        recording <= 0;
        music_notes <= 0;
        line_length <= 0;
        // Latch speed per file; timed events retain their encoded durations.
        case (speed)
            1: key_frames <= 6;
            2: key_frames <= 10;
            default: key_frames <= KEY_FRAMES;
        endcase
    end else if (busy && ((!timed && state != RECEIVE && !available) ||
                         cancel || (started && !enabled))) begin
        state <= IDLE;
        keys <= 0;
        error <= !timed && !available;
    end else begin
        case (state)
            RECEIVE: begin
                if (!download) begin
                    if (bad || length == 0 || length > 4096 ||
                        {3'd0, received} != length + 16'd8 || crc != expected_crc ||
                        (timed ? payload_phase != 0 : !available)) begin
                        error <= 1;
                        state <= IDLE;
                    end else begin
                        position <= 0;
                        frames <= LINE_FRAMES;
                        state <= WAIT_START;
                    end
                end else if (wr) begin
                    if (addr != {12'd0, received} || received >= 4104) bad <= 1;
                    else begin
                        received <= received + 1'b1;
                        case (received)
                            0: if (data != "V") bad <= 1;
                            1: if (data != "B") bad <= 1;
                            2: if (data != "K") bad <= 1;
                            3: begin
                                timed <= data == "2";
                                if (data != "1" && data != "2") bad <= 1;
                            end
                            4: length[7:0] <= data;
                            5: length[15:8] <= data;
                            6: expected_crc[7:0] <= data;
                            7: expected_crc[15:8] <= data;
                            default: begin
                                crc <= crc_byte(crc, data);
                                if (timed) begin
                                    if ((payload_phase == 0 && data > 35 && data < MUSIC_REPLAY) ||
                                        (payload_phase == 1 && data == 0)) bad <= 1;
                                    payload_phase <= payload_phase == 2 ? 0 : payload_phase + 1'b1;
                                end else if (!valid_key(data)) bad <= 1;
                            end
                        endcase
                    end
                end
            end
            WAIT_START: if (enabled && frame_tick) begin
                if (frames > 1) frames <= frames - 1'b1;
                else begin
                    started <= 1;
                    shifted <= 0;
                    state <= READ_KEY;
                end
            end
            READ_KEY: state <= SELECT_KEY;
            SELECT_KEY: begin
                if (timed) begin
                    event_key <= token;
                    position <= position + 1'b1;
                    state <= READ_HOLD;
                end else if (!token[7] && token[6] != symbols) begin
                    if (shifted) begin
                        error <= 1;
                        state <= IDLE;
                    end else begin
                        keys <= 36'd1 << 11;
                        shifting <= 1;
                        shifted <= 1;
                        frames <= control_frames;
                        state <= HOLD_KEY;
                    end
                end else begin
                    keys <= 36'd1 << token[5:0];
                    shifting <= 0;
                    if (token != 8'h9b && line_length < 125) line_length <= line_length + 1'b1;
                    frames <= token == 8'h9b ? control_frames : key_frames;
                    state <= HOLD_KEY;
                end
            end
            READ_HOLD: state <= SELECT_HOLD;
            SELECT_HOLD: begin
                hold_frames <= token;
                position <= position + 1'b1;
                state <= READ_GAP;
            end
            READ_GAP: state <= SELECT_GAP;
            SELECT_GAP: begin
                gap_frames <= token;
                shifting <= 0;
                if (recording && music_notes == 79 && event_key != 11) begin
                    // Skip the remaining music up to the closing SHIFT/No-Record.
                    keys <= 0;
                    frames <= 0;
                    state <= RELEASE_KEY;
                end else begin
                    case (event_key)
                        MUSIC_REPLAY: keys <= playback ? 36'd0 : 36'd1 << 12;
                        MUSIC_RECORD: begin
                            keys <= 36'd1 << (playback ? 7 : 33);
                            recording <= !playback;
                            music_notes <= 0;
                        end
                        8'hff: keys <= 0;
                        default: keys <= 36'd1 << event_key[5:0];
                    endcase
                    if (recording && music_note(event_key)) music_notes <= music_notes + 1'b1;
                    if (event_key == 11 && music_notes != 0) recording <= 0;
                    frames <= hold_frames;
                    state <= HOLD_KEY;
                end
            end
            HOLD_KEY: if (frame_tick) begin
                if (frames > 1) frames <= frames - 1'b1;
                else begin
                    keys <= 0;
                    frames <= timed ? gap_frames :
                              (shifting || token == 8'h9b ? control_frames : key_frames);
                    state <= RELEASE_KEY;
                end
            end
            RELEASE_KEY: if (frame_tick || (timed && frames == 0)) begin
                if (frames > 1) frames <= frames - 1'b1;
                else if (shifting) state <= SELECT_KEY;
                else if (!timed && token == 8'h9b) begin
                    // Allow longer statements more time to parse before any next key.
                    frames <= line_frames;
                    line_length <= 0;
                    state <= LINE_WAIT;
                end else if ({4'd0, position} + 16'd1 == length) begin
                    if (auto_repeat) begin
                        position <= 0;
                        shifted <= 0;
                        line_length <= 0;
                        state <= READ_KEY;
                    end else begin
                        complete <= 1;
                        state <= IDLE;
                    end
                end
                else begin
                    position <= position + 1'b1;
                    shifted <= 0;
                    state <= READ_KEY;
                end
            end
            LINE_WAIT: if (frame_tick) begin
                if (frames > 1) frames <= frames - 1'b1;
                else if ({4'd0, position} + 16'd1 == length) begin
                    if (auto_repeat) begin
                        position <= 0;
                        shifted <= 0;
                        state <= READ_KEY;
                    end else begin
                        complete <= 1;
                        state <= IDLE;
                    end
                end
                else begin
                    position <= position + 1'b1;
                    shifted <= 0;
                    state <= READ_KEY;
                end
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule
