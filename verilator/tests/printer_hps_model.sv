`timescale 1ns/1ps
// Stock hps_io, driven with Main's poll/sector protocol. File writes follow ACK.
module printer_hps_model #(
    parameter BYTES = 32768
)(
    input wire clk,
    input wire [31:0] sd_lba[3],
    input wire [2:0] sd_rd, sd_wr,
    output wire [2:0] sd_ack,
    output wire [8:0] sd_buff_addr,
    output wire [7:0] sd_buff_dout,
    input wire [7:0] sd_buff_din[3],
    output wire sd_buff_wr
);
tri [45:0] hps_bus;
reg [15:0] tx = 0;
reg enable = 0, strobe = 0;
wire [13:0] address;
wire [5:0] blocks[3];
assign blocks = '{0,0,0};
assign hps_bus[31:16] = tx;
assign hps_bus[35:33] = {1'b0,enable,strobe};
assign hps_bus[45:38] = 0;
assign sd_buff_addr = address[8:0];
hps_io #(.CONF_STR("Test;"),.CONF_STR_BRAM(1),.VDNUM(3)) transport (
    .clk_sys(clk),.HPS_BUS(hps_bus),.sd_lba(sd_lba),.sd_blk_cnt(blocks),
    .sd_rd(sd_rd),.sd_wr(sd_wr),.sd_ack(sd_ack),.sd_buff_addr(address),
    .sd_buff_dout(sd_buff_dout),.sd_buff_din(sd_buff_din),.sd_buff_wr(sd_buff_wr),
    .status_in(128'd0),.status_set(1'b0),.status_menumask(16'd0),
    .info_req(1'b0),.info(8'd0),.ioctl_wait(1'b0),.ioctl_upload_req(1'b0),
    .EXT_BUS()
);
reg [7:0] media[3][BYTES], pending[512];
integer requests[3] = '{0,0,0};
integer writes[3] = '{0,0,0};
reg [15:0] flags, result, low_lba, high_lba;
integer selected, base;
reg writing;
task word_io(input [15:0] value, output [15:0] reply);
    @(negedge clk); tx=value; strobe=1;
    @(negedge clk); reply=hps_bus[15:0]; strobe=0;
    repeat(3) @(negedge clk);
endtask
task finish_io;
    repeat(4) @(negedge clk);
    enable=0;
    repeat(2) @(negedge clk);
endtask
initial begin
    for(integer d=0;d<3;d=d+1)
        for(integer j=0;j<BYTES;j=j+1) media[d][j]=0;
    repeat(10) @(negedge clk);
    enable=1;
    word_io('h14,result);
    word_io(0,result);if(result[7:0]!="T") $fatal(1,"Config ROM byte 0");
    word_io(0,result);if(result[7:0]!="e") $fatal(1,"Config ROM byte 1");
    word_io(0,result);if(result[7:0]!="s") $fatal(1,"Config ROM byte 2");
    word_io(0,result);if(result[7:0]!="t") $fatal(1,"Config ROM byte 3");
    word_io(0,result);if(result[7:0]!=";") $fatal(1,"Config ROM byte 4");
    finish_io();
    forever begin
        enable=1;
        word_io('h16,flags);
        word_io(0,result);
        word_io(0,low_lba);
        word_io(0,high_lba);
        finish_io();
        if(flags[1:0]!=0) begin
            selected=int'(flags[5:2]);
            base=int'({high_lba,low_lba})*512;
            if(selected>=3 || base<0 || base+512>BYTES) $fatal(1,"HPS request out of range");
            requests[selected]=requests[selected]+1;
            writing=flags[1];
            enable=1;
            word_io((writing ? 16'h18 : 16'h17) | (16'(selected)<<8),result);
            for(integer j=0;j<512;j=j+1) begin
                word_io(writing ? 16'd0 : {8'd0,media[selected][base+j]},result);
                if(writing) pending[j]=result[7:0];
            end
            finish_io();
            repeat(17) @(negedge clk);
            if(writing) begin
                for(integer j=0;j<512;j=j+1) media[selected][base+j]=pending[j];
                writes[selected]=writes[selected]+1;
            end
        end
    end
end
endmodule

