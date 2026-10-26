`timescale 1ns/1ps
module tb_printer_capture;
reg clk = 0;
always #5 clk = ~clk;
reg reset = 0, serial_in = 1, baud110 = 0, start = 0, stop = 0;
reg img_mounted = 0, img_readonly = 0;
reg [63:0] img_size = 32768;
wire busy, active, stalled;
wire [3:0] error, status_code;
wire [31:0] sd_lba;
wire sd_rd, sd_wr;
reg sd_ack = 0, sd_buff_wr = 0;
reg [8:0] sd_buff_addr = 0;
reg [7:0] sd_buff_dout = 0;
wire [7:0] sd_buff_din;
videobrain_printer_capture #(.CLOCK_HZ(52800)) dut(.*);
reg [7:0] media[32768], write_buffer[512];
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
    for(integer j=0;j<32768;j=j+1) media[j]=0;
    {media[3],media[2],media[1],media[0]}=32'h31504256;
    media[4]=1; media[9]=2; media[12]=32; media[16]=64;
    crc=32'hffffffff;
    for(integer j=0;j<512;j=j+1) crc=crc_byte(crc,media[j]);
    for(integer j=0;j<4;j=j+1) media[28+j]=~crc[j*8 +:8];
endtask
initial begin
    forever begin
        @(negedge clk);
        if ((sd_rd || sd_wr) && !hold_service) begin
            if(sd_rd && sd_wr || sd_lba>=64) $fatal(1,"Invalid SD request");
            writing=sd_wr; base=int'(sd_lba)*512;
            repeat(11) @(negedge clk);
            sd_ack=1;
            for(integer j=0;j<512;j=j+1) begin
                @(negedge clk); sd_buff_addr=9'(j); sd_buff_dout=media[base+j];
                sd_buff_wr=0;
                @(negedge clk); sd_buff_wr=!writing;
                @(negedge clk); sd_buff_wr=0;
                if(writing) write_buffer[j]=sd_buff_din;
            end
            sd_buff_wr=0;
            @(negedge clk); sd_ack=0;
            // Real Main fetches the sector before writing the backing file.
            repeat(19) @(negedge clk);
            if(writing && !ignore_writes)
                for(integer j=0;j<512;j=j+1) media[base+j]=write_buffer[j];
        end
    end
end
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
    for(integer j=0;j<32768;j=j+1) $fwrite(fd,"%c",media[j]);
    $fclose(fd);
endtask
initial begin
    #10000000000; $fatal(1,"Capture test timeout state %d error %d",dut.state,error);
end
initial begin
    blank(); tick(4); mount_image();
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
    dump("out/expander1/printer.vbp");
    blank(); mount_image(); baud110=0; begin_capture();
    send_byte('ha5);send_byte('h3c,0);
    wait(!busy);
    if(error!=6) $fatal(1,"Bad stop not reported");
    dump("out/expander1/printer-framing.vbp");
    blank(); mount_image(); img_readonly=1; mount_image();
    start=1; tick(); start=0; tick();
    if(error!=2 || sd_wr) $fatal(1,"Read-only image not protected");
    img_readonly=0; mount_image(); ignore_writes=1;
    start=1;tick();start=0;wait(!busy);tick();
    if(error!=5) $fatal(1,"Ignored backing write reported success %d",error);
    ignore_writes=0;blank();mount_image();begin_capture();
    hold_service=1;
    send_byte('h12); begin : end_capture_start
        stop=1;tick();stop=0;tick(532000);
        if(!stalled || !busy) $fatal(1,"Missing stalled pending status");
    end
    hold_service=0;wait(!busy);
    if(error) $fatal(1,"Recovered stall lost bytes");
    blank();mount_image();begin_capture();
    hold_service=1;
    for(integer j=0;j<1800;j=j+1) send_byte(8'(j));
    if(error!=0 || !active || dut.fifo_count>4096) $fatal(1,"60-second-equivalent stall lost data");
    hold_service=0;end_capture();
    dump("out/expander1/printer-latency.vbp");
    blank();mount_image();begin_capture();hold_service=1;
    for(integer j=0;j<4500;j=j+1) send_byte(8'(j));
    if(error!=7 || active) $fatal(1,"Overflow did not stop capture");
    hold_service=0;wait(!busy);dump("out/expander1/printer-overflow.vbp");
    blank();mount_image();begin_capture();send_byte('ha5);
    reset=1;tick(4);reset=0;wait(!busy);
    if(error!=10) $fatal(1,"Reset did not mark interrupted session");
    dump("out/expander1/printer-reset.vbp");
    // A nonzero sector after a zero hole must never become an append target.
    blank();media[1024]=1;mount_image();
    if(error!=3 || sd_wr) $fatal(1,"Corrupt tail accepted");
    // A four-sector image reserves its last record for STOP.
    blank();img_size=2048;media[16]=4;
    for(integer j=28;j<32;j=j+1) media[j]=0;
    crc=32'hffffffff;
    for(integer j=0;j<512;j=j+1) crc=crc_byte(crc,media[j]);
    for(integer j=0;j<4;j=j+1) media[28+j]=~crc[j*8 +:8];
    mount_image();begin_capture();
    for(integer j=0;j<200;j=j+1) send_byte(8'(j));
    wait(!busy);
    if(error!=8 || media[1536]!=8'h56 || media[1536+12]!=3) $fatal(1,"Capacity STOP reservation failed");
    $display("Independent printer image capture, remount, framing, protection, failed write and stall passed");
    $finish;
end
endmodule

