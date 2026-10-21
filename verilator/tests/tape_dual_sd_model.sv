`timescale 1ns/1ps
module tape_dual_sd_model #(
    parameter BYTES = 16384,
    parameter DELAY = 40
)(
    input wire clk,
    input wire [31:0] sd_lba[2],
    input wire [1:0] sd_rd, sd_wr,
    output reg [1:0] sd_ack = 0,
    output reg [8:0] sd_buff_addr = 0,
    output reg [7:0] sd_buff_dout = 0,
    input wire [7:0] sd_buff_din[2],
    output reg sd_buff_wr = 0
);
reg [7:0] media[2][BYTES];
integer writes[2] = '{0, 0};
integer requests = 0;
integer selected = 0, next_deck = 0, base;
reg writing;
initial begin
    for (integer d = 0; d < 2; d = d + 1) begin
        for (integer i = 0; i < BYTES; i = i + 1) media[d][i] = 0;
        {media[d][3],media[d][2],media[d][1],media[d][0]} = 32'h31544256;
        {media[d][7],media[d][6],media[d][5],media[d][4]} = 32'd14318180;
    end
    forever begin
        @(posedge clk);
        if (|(sd_rd | sd_wr)) begin
            selected = (sd_rd[next_deck] || sd_wr[next_deck]) ? next_deck : 1-next_deck;
            next_deck = 1-selected;
            if (sd_rd[selected] && sd_wr[selected]) $fatal(1,"Concurrent SD read/write");
            if (sd_lba[selected] >= BYTES/512) $fatal(1,"SD access outside image");
            writing = sd_wr[selected];
            base = int'(sd_lba[selected]) * 512;
            requests = requests + 1;
            repeat(DELAY + (requests * 137) % (DELAY + 1)) @(negedge clk);
            sd_ack[selected] = 1;
            for (integer i = 0; i < 512; i = i + 1) begin
                @(negedge clk);
                sd_buff_addr = 9'(i);
                sd_buff_dout = media[selected][base+i];
                sd_buff_wr = !writing;
                @(negedge clk);
                if (writing) media[selected][base+i] = sd_buff_din[selected];
            end
            sd_buff_wr = 0;
            @(negedge clk);
            sd_ack = 0;
            if (writing) writes[selected] = writes[selected] + 1;
        end
    end
end
function [31:0] word_at(input integer deck, input integer offset);
    word_at = {media[deck][offset+3],media[deck][offset+2],media[deck][offset+1],media[deck][offset]};
endfunction
endmodule
