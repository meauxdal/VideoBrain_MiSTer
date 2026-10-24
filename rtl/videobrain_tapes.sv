`timescale 1ns/1ps
module videobrain_tapes (
    input wire clk,
    input wire reset,
    input wire [1:0] img_mounted,
    input wire img_readonly,
    input wire [63:0] img_size,
    input wire [1:0] rewind,
    input wire record_data,
    input wire record_enable,
    input wire playback_enable,
    output wire playback_data,
    output wire [1:0] busy,
    output wire [1:0] error,
    output wire [1:0] rewound,
    output wire [1:0] ended,
    output wire [31:0] sd_lba[2],
    output wire [1:0] sd_rd,
    output wire [1:0] sd_wr,
    input wire [1:0] sd_ack,
    input wire [8:0] sd_buff_addr,
    input wire [7:0] sd_buff_dout,
    output wire [7:0] sd_buff_din[2],
    input wire sd_buff_wr
);
genvar deck;
generate
    for (deck = 0; deck < 2; deck = deck + 1) begin : tape_deck
        wire data_out;
        if (deck == 0) assign playback_data = data_out;
        videobrain_tape #(.RECORDING(deck == 1), .PLAYBACK(deck == 0)) tape (
            .clk(clk), .reset(reset),
            .img_mounted(img_mounted[deck]),
            .img_readonly(deck == 0 || img_readonly), .img_size(img_size),
            .rewind(rewind[deck]), .record_data(record_data),
            .record_enable(record_enable), .playback_enable(playback_enable),
            .playback_data(data_out), .busy(busy[deck]), .writable(),
            .error(error[deck]), .rewound(rewound[deck]), .ended(ended[deck]),
            .sd_lba(sd_lba[deck]), .sd_rd(sd_rd[deck]), .sd_wr(sd_wr[deck]),
            .sd_ack(sd_ack[deck]), .sd_buff_addr(sd_buff_addr),
            .sd_buff_dout(sd_buff_dout), .sd_buff_din(sd_buff_din[deck]),
            .sd_buff_wr(sd_buff_wr && sd_ack[deck])
        );
    end
endgenerate
endmodule
