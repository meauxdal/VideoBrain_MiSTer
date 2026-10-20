`timescale 1ns/1ps
module tape_sd_model #(
    parameter BYTES = 16384,
    parameter DELAY = 40
)(
    input wire clk,
    input wire [31:0] sd_lba,
    input wire sd_rd, sd_wr,
    output reg sd_ack = 0,
    output reg [13:0] sd_buff_addr = 0,
    output reg [7:0] sd_buff_dout = 0,
    input wire [7:0] sd_buff_din,
    output reg sd_buff_wr = 0
);
reg [7:0] media[BYTES];
integer writes = 0;
reg writing;
integer base;
initial begin
    for (integer i = 0; i < BYTES; i = i + 1) media[i] = 0;
    {media[3],media[2],media[1],media[0]} = 32'h31544256;
    {media[7],media[6],media[5],media[4]} = 32'd14318180;
    forever begin
        @(posedge clk);
        if (sd_rd || sd_wr) begin
            if (sd_rd && sd_wr) $fatal(1,"Concurrent read/write");
            if (sd_lba >= BYTES/512) $fatal(1,"SD access outside image");
            writing = sd_wr;
            base = int'(sd_lba) * 512;
            repeat(DELAY) @(negedge clk);
            sd_ack = 1;
            for (integer i = 0; i < 512; i = i + 1) begin
                @(negedge clk);
                sd_buff_addr = 14'(i);
                sd_buff_dout = media[base+i];
                sd_buff_wr = !writing;
                @(negedge clk);
                if (writing) media[base+i] = sd_buff_din;
            end
            sd_buff_wr = 0;
            @(negedge clk);
            sd_ack = 0;
            if (writing) writes = writes + 1;
        end
    end
end
function [31:0] word_at(input integer offset);
    word_at = {media[offset+3],media[offset+2],media[offset+1],media[offset]};
endfunction
endmodule
