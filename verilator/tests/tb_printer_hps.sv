`timescale 1ns/1ps
module tb_printer_hps;
reg clk = 0;
always #5 clk = ~clk;
reg reset = 0, serial_in = 1, baud110 = 0, start = 0, stop = 0;
reg img_mounted = 0, img_readonly = 0;
reg [63:0] img_size = 32768;
wire busy, active, stalled;
wire [3:0] error, status_code;
wire [31:0] sd_lba;
wire sd_rd, sd_wr;
wire sd_ack, sd_buff_wr;
wire [8:0] sd_buff_addr;
wire [7:0] sd_buff_dout;
wire [7:0] sd_buff_din;
videobrain_printer_capture #(.CLOCK_HZ(52800)) dut(.*);
reg [7:0] write_buffer[512];
reg writing, ignore_writes = 0, hold_service = 0;
integer base;
reg [31:0] crc;
function automatic [31:0] crc_byte(input [31:0] c, input [7:0] b);
    reg [31:0] n;
    begin
        n=c ^ {24'd0,b};
        for(integer j=0;j<8;j=j+1) n=n[0] ? (n>>1)^32'hedb88320 : n>>1;
        crc_byte=n;
    end
endfunction
task blank;
    for(integer j=0;j<32768;j=j+1) card.media[2][j]=0;
    {card.media[2][3],card.media[2][2],card.media[2][1],card.media[2][0]}=32'h31504256;
    card.media[2][4]=1; card.media[2][9]=2; card.media[2][12]=32; card.media[2][16]=64;
    crc=32'hffffffff;
    for(integer j=0;j<512;j=j+1) crc=crc_byte(crc,card.media[2][j]);
    for(integer j=0;j<4;j=j+1) card.media[2][28+j]=~crc[j*8 +:8];
endtask
wire [31:0] lbas[3];
wire [2:0] reads, writes, acks;
wire [7:0] dins[3];
reg traffic = 1;
reg [1:0] req_read = 0, req_write = 0;
assign lbas[0]=0;
assign lbas[1]=0;
assign lbas[2]=sd_lba;
assign reads={sd_rd,1'b0,req_read[0]};
assign writes={sd_wr,req_write[1],1'b0};
assign sd_ack=acks[2];
assign dins[0]=0;
reg [7:0] write_byte=0;
always @(posedge clk) write_byte <= sd_buff_addr[7:0] ^ 8'ha5;
assign dins[1]=write_byte;
assign dins[2]=sd_buff_din;
always @(posedge clk) begin
    if(acks[0]) req_read[0]<=0;
    else if(traffic) req_read[0]<=1;
    if(acks[1]) req_write[1]<=0;
    else if(traffic) req_write[1]<=1;
end
printer_hps_model card(.clk(clk),.sd_lba(lbas),.sd_rd(reads),.sd_wr(writes),
    .sd_ack(acks),.sd_buff_addr(sd_buff_addr),.sd_buff_dout(sd_buff_dout),
    .sd_buff_din(dins),.sd_buff_wr(sd_buff_wr));
task tick(input integer n=1);
    repeat(n) @(negedge clk);
endtask
task mount_image;
    tick();
    img_mounted=1; tick(); img_mounted=0; tick();
    wait(!busy); tick(2);
endtask
task begin_capture;
    tick();
    start=1; tick(); start=0;
    wait(active || error!=0); tick();
    if(!active) $fatal(1,"Start failed: %d",error);
endtask
task end_capture;
    stop=1; tick(); stop=0;
    wait(!busy); tick(2);
endtask
task send_byte(input [7:0] value, input bit good_stop=1);
    integer period;
    period=baud110 ? 480 : 176;
    serial_in=0; tick(period);
    for(integer j=0;j<8;j=j+1) begin serial_in=value[j]; tick(period); end
    serial_in=good_stop; tick(period);
    serial_in=1; tick(period);
endtask
task dump(input string filename);
    integer fd;
    fd=$fopen(filename,"wb");
    if(!fd) $fatal(1,"Cannot create capture image");
    for(integer j=0;j<32768;j=j+1) $fwrite(fd,"%c",card.media[2][j]);
    $fclose(fd);
endtask
initial begin
    #10000000000; $fatal(1,"Capture test timeout state %d error %d",dut.state,error);
end
initial begin
    tick(4); blank(); tick(4); mount_image();
    if(status_code!=2) $display("header %h crc %h padding %b",dut.header,~dut.read_crc,dut.padding_ok);
    if(status_code!=2) $fatal(1,"Blank image rejected %d",error);
    begin_capture();
    for(integer j=0;j<5000;j=j+1) send_byte(8'(j));
    end_capture();
    if(error) $fatal(1,"Stream failed %d",error);
    mount_image(); baud110=1; begin_capture();
    send_byte(0);send_byte('h20);send_byte('ha5);send_byte('h0d);send_byte('h0a);send_byte('hff);
    for(integer j=0;j<256;j=j+1) send_byte(8'(j));
    end_capture();
    dump("out/expander1/printer-hps.vbp");
    blank(); mount_image(); baud110=0; begin_capture();
    send_byte('ha5);send_byte('h3c,0);
    wait(!busy);
    if(error!=6) $fatal(1,"Bad stop not reported");
    dump("out/expander1/printer-hps-framing.vbp");
    traffic=0;tick(10000);
    if(card.requests[0]==0 || card.requests[1]==0 || card.requests[2]==0)
        $fatal(1,"Missing three-drive contention");
    for(integer j=0;j<512;j=j+1) begin
        if(card.media[0][j] != 0) $fatal(1,"Read drive overwritten");
        if(card.media[1][j] != (8'(j)^8'ha5)) $fatal(1,"Write drive buffer crossed");
    end
    $display("Stock hps_io three-drive arbitration and independent printer capture passed");
    $finish;
end
endmodule
