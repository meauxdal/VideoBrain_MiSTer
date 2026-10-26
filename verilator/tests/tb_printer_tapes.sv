`timescale 1ns/1ps
module tb_printer_tapes;
reg clk = 0;
always #34.920639 clk = ~clk;
reg reset_na = 0;
reg host_data_n = 1, host_clock_n = 1;
wire data_n, clock_n, interrupt_n, record_data, record_enable, playback_enable;
wire playback_data;
reg [15:0] dl_addr = 0;
reg [7:0] dl_data = 0;
reg dl_wr = 0;
expander1 dut(.*,.dl_index(8'd3),.modem_rxd(1'b1),.modem_txd(),
             .printer_rxd(1'b1),.printer_txd());
reg [7:0] firmware[2048];
reg [1:0] img_mounted = 0, rewind = 0;
wire [1:0] busy, error, rewound, sd_rd, sd_wr, sd_ack;
wire [31:0] sd_lba[2];
wire [8:0] sd_buff_addr;
wire [7:0] sd_buff_dout, sd_buff_din[2];
wire sd_buff_wr;
videobrain_tapes tapes(.*,.ended(),.reset(!reset_na),.img_readonly(1'b0),.img_size(64'd16384));
wire [31:0] all_lba[3];
wire [2:0] all_rd,all_wr,all_ack;
wire [7:0] all_din[3];
assign all_lba[0]=sd_lba[0];assign all_lba[1]=sd_lba[1];
assign all_rd[1:0]=sd_rd;assign all_wr[1:0]=sd_wr;assign sd_ack=all_ack[1:0];
assign all_din[0]=sd_buff_din[0];assign all_din[1]=sd_buff_din[1];
reg capture_start=0,capture_stop=0,capture_mounted=0,printer_pin=1;
wire capture_busy,capture_active;
wire [3:0] capture_error;
integer enabled=1;
videobrain_printer_capture #(.CLOCK_HZ(52800)) capture(
    .clk(clk),.reset(1'b0),.serial_in(printer_pin),.baud110(1'b0),
    .start(capture_start),.stop(capture_stop),.img_mounted(capture_mounted),
    .img_readonly(1'b0),.img_size(64'd32768),.busy(capture_busy),.active(capture_active),
    .error(capture_error),.sd_lba(all_lba[2]),.sd_rd(all_rd[2]),.sd_wr(all_wr[2]),
    .sd_ack(all_ack[2]),.sd_buff_addr(sd_buff_addr),.sd_buff_dout(sd_buff_dout),
    .sd_buff_din(all_din[2]),.sd_buff_wr(sd_buff_wr));
printer_hps_model card(.clk(clk),.sd_lba(all_lba),.sd_rd(all_rd),.sd_wr(all_wr),
    .sd_ack(all_ack),.sd_buff_addr(sd_buff_addr),.sd_buff_dout(sd_buff_dout),
    .sd_buff_din(all_din),.sd_buff_wr(sd_buff_wr));
reg [7:0] blank_image[32768];
integer printer_bursts=0;
// Synthetic independent printer source stresses cassette SD service, not cartridge routing.
initial forever begin
    @(posedge busy[0] or posedge busy[1]);
    if(capture_active) begin
        for(integer c=0;c<16;c=c+1) begin
            @(negedge clk);printer_pin=0;repeat(176) @(negedge clk);
            for(integer b=0;b<8;b=b+1) begin printer_pin=1'(c>>b);repeat(176) @(negedge clk);end
            printer_pin=1;repeat(352) @(negedge clk);
        end
        printer_bursts=printer_bursts+1;
    end
end

task transfer(input [7:0] value, output [7:0] result);
    for (integer i = 7; i >= 0; i = i - 1) begin
        @(negedge interrupt_n);
        host_data_n = !value[i];
        host_clock_n = 1;
        #1;
        result[i] = !clock_n;
        @(posedge interrupt_n);
    end
    $display("Host %x reply %x",value,result);
endtask
reg [7:0] reply;
task status_reply;
    @(negedge interrupt_n);
    #1;
    if (data_n || !clock_n) $fatal(1,"Firmware transfer status");
    @(posedge interrupt_n);
    host_data_n = 1;
endtask

task remote_setup(input [7:0] mode);
    host_data_n = 1;
    host_clock_n = 0;
    transfer(5,reply);
    transfer(0,reply);
    transfer(mode,reply);
    status_reply();
endtask

task write_record(input [7:0] value, input [15:0] crc);
    host_data_n = 1;
    host_clock_n = 0;
    transfer(2,reply);
    transfer(0,reply);
    transfer(1,reply);
    transfer(0,reply);
    transfer(0,reply);
    transfer(1,reply);
    transfer(value,reply);
    transfer(crc[7:0],reply);
    transfer(crc[15:8],reply);
    @(negedge record_enable);
    status_reply();
    if (|error) $fatal(1,"Record deck failed");
endtask

task read_record(input [7:0] value, input [15:0] crc);
    host_data_n = 1;
    host_clock_n = 0;
    transfer(1,reply);
    transfer(1,reply);
    transfer(1,reply);
    transfer(1,reply);
    transfer(0,reply);
    if (reply != 0) $fatal(1,"Read length high");
    transfer(0,reply);
    if (reply != 1) $fatal(1,"Read length low");
    transfer(0,reply);
    if (reply != value) $fatal(1,"Read payload %x expected %x",reply,value);
    transfer(0,reply);
    if (reply != crc[7:0]) $fatal(1,"Read CRC low");
    transfer(0,reply);
    if (reply != crc[15:8]) $fatal(1,"Read CRC high");
    @(negedge playback_enable);
    status_reply();
    if (|error) $fatal(1,"Playback deck failed");
endtask

string path;
integer file_handle, size;
integer destination_writes;
reg [7:0] source[16384];
initial begin
    if($value$plusargs("capture=%d",enabled)) begin end
    repeat(4) @(negedge clk);
    for(integer d=0;d<2;d=d+1) begin
        {card.media[d][3],card.media[d][2],card.media[d][1],card.media[d][0]}=32'h31544256;
        {card.media[d][7],card.media[d][6],card.media[d][5],card.media[d][4]}=32'd14318180;
    end
    if(enabled!=0) begin
        file_handle=$fopen("out/expander1/printer-tape-blank.vbp","rb");
        size=$fread(blank_image,file_handle);$fclose(file_handle);
        if(size!=32768) $fatal(1,"Missing printer blank");
        for(integer j=0;j<32768;j=j+1) card.media[2][j]=blank_image[j];
        capture_mounted=1;@(negedge clk);capture_mounted=0;@(negedge clk);wait(!capture_busy);
        @(negedge clk);capture_start=1;@(negedge clk);capture_start=0;wait(capture_active);
    end
    @(negedge clk);
    img_mounted = 3;
    @(negedge clk);
    img_mounted = 0;
    if (!$value$plusargs("firmware=%s",path)) $fatal(1,"Supply firmware");
    file_handle = $fopen(path,"rb");
    size = $fread(firmware,file_handle);
    $fclose(file_handle);
    if (size != 2048) $fatal(1,"Invalid firmware size");
    for (integer i = 0; i < 2048; i = i + 1) begin
        @(negedge clk);
        dl_addr = 16'(i);
        dl_data = firmware[i];
        dl_wr = 1;
    end
    @(negedge clk);
    dl_wr = 0;
    reset_na = 1;
    #100000;
    wait(busy == 0);
    remote_setup(3);
    write_record(8'ha5,16'hd67e);
    wait(busy == 0);
    write_record(8'h5a,16'hc88e);
    wait(busy == 0);
    reset_na = 0;
    for (integer i = 0; i < 16384; i = i + 1) begin
        source[i] = card.media[1][i];
        card.media[0][i] = source[i];
        card.media[1][i] = 0;
    end
    {card.media[1][3],card.media[1][2],card.media[1][1],card.media[1][0]} = 32'h31544256;
    {card.media[1][7],card.media[1][6],card.media[1][5],card.media[1][4]} = 32'd14318180;
    host_data_n = 1;
    host_clock_n = 1;
    #1000;
    reset_na = 1;
    @(negedge clk);
    img_mounted = 3;
    @(negedge clk);
    img_mounted = 0;
    wait(busy == 0);
    #100000;
    // EDIT reads the definition, writes a copy, then resumes the source.
    remote_setup(0);
    read_record(8'ha5,16'hd67e);
    write_record(8'ha5,16'hd67e);
    read_record(8'h5a,16'hc88e);
    write_record(8'h5a,16'hc88e);
    wait(busy == 0);
    for (integer i = 0; i < 16384; i = i + 1)
        if (card.media[0][i] != source[i]) $fatal(1,"EDIT changed source at %0d",i);
    if (card.writes[0] != 0 || |error) $fatal(1,"EDIT deck error");
    file_handle = $fopen("out/expander1/edit.vbt","wb");
    if (!file_handle) $fatal(1,"Cannot create EDIT image");
    for (integer i = 0; i < 16384; i = i + 1) $fwrite(file_handle,"%c",card.media[1][i]);
    $fclose(file_handle);
    destination_writes = card.writes[1];
    reset_na = 0;
    for (integer i = 0; i < 16384; i = i + 1) card.media[0][i] = card.media[1][i];
    host_data_n = 1;
    host_clock_n = 1;
    #1000;
    reset_na = 1;
    @(negedge clk);
    img_mounted = 1;
    @(negedge clk);
    img_mounted = 0;
    wait(busy == 0);
    #100000;
    remote_setup(2);
    read_record(8'ha5,16'hd67e);
    read_record(8'h5a,16'hc88e);
    if (card.writes[1] != destination_writes) $fatal(1,"REVIEW changed destination");
    $display("Original firmware EDIT read/write/read with separate tapes passed");
    if(enabled!=0) begin
        @(negedge clk);capture_stop=1;@(negedge clk);capture_stop=0;wait(!capture_busy);
        if(capture_error!=0 || printer_bursts==0 || card.writes[2]==0)
            $fatal(1,"Concurrent printer capture failed %0d/%0d",capture_error,printer_bursts);
        file_handle=$fopen("out/expander1/printer-tapes.vbp","wb");
        for(integer j=0;j<32768;j=j+1) $fwrite(file_handle,"%c",card.media[2][j]);
        $fclose(file_handle);
    end
    $display("Original ROM tape operations with printer capture=%0d passed",enabled);
    $finish;
end
initial begin
    #6400000000;
    $fatal(1,"EDIT test timeout, firmware address %x",dut.addr);
end
endmodule
