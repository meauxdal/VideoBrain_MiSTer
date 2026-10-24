`timescale 1ns/1ps
module tb_expander1_playback;
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
reg img_mounted = 0, rewind = 0;
wire busy, writable, error, rewound;
wire [31:0] sd_lba;
wire sd_rd, sd_wr, sd_ack, sd_buff_wr;
wire [13:0] sd_buff_addr;
wire [7:0] sd_buff_dout, sd_buff_din;
videobrain_tape tape(.*,.rewound(),.ended(),.reset(!reset_na),.img_readonly(1'b0),.img_size(64'd16384),
                     .sd_buff_addr(sd_buff_addr[8:0]));
tape_sd_model card(.*);
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
task initialize_remotes(input [7:0] remotes);
    integer writes_before;
    reg [31:0] length_before;
    writes_before = card.writes;
    length_before = card.word_at(8);
    host_data_n = 1;
    host_clock_n = 0;
    transfer(5,reply);
    transfer(0,reply);
    transfer(remotes,reply);
    @(negedge interrupt_n);
    #1;
    if (data_n || !clock_n) $fatal(1,"Remote initialization status");
    @(posedge interrupt_n);
    if (record_enable != remotes[1] || playback_enable != remotes[0] || error)
        $fatal(1,"Remote initialization failed");
    if (remotes == 3 && busy) $fatal(1,"Both remotes started a transfer");
    if (card.writes != writes_before || card.word_at(8) != length_before)
        $fatal(1,"Remote initialization changed image");
    host_data_n = 1;
endtask
string path;
integer file_handle, size;
reg [7:0] payload[2] = '{8'ha5,8'h5a};
reg [15:0] crc[2] = '{16'hd67e,16'hc88e};
initial begin
    @(negedge clk);
    img_mounted = 1;
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
    wait(writable);
    initialize_remotes(3);
    if (card.writes != 0) $fatal(1,"Remote initialization changed image");
    for (integer record = 0; record < 2; record = record + 1) begin
        host_data_n = 1;
        host_clock_n = 0;
        transfer(2,reply);
        transfer(0,reply);
        transfer(1,reply);
        transfer(0,reply);
        transfer(0,reply);
        transfer(1,reply);
        transfer(payload[record],reply);
        transfer(crc[record][7:0],reply);
        transfer(crc[record][15:8],reply);
        @(negedge record_enable);
        @(negedge interrupt_n);
        #1;
        if (data_n || !clock_n) $fatal(1,"Recording status %0d",record);
        @(posedge interrupt_n);
        wait(!busy);
        if (error) $fatal(1,"Tape SAVE %0d failed",record);
        if (record == 0 && card.word_at(8) != 685) $fatal(1,"First recording length");
    end
    if (card.word_at(8) <= 685) $fatal(1,"Second recording did not append");
    file_handle = $fopen("out/expander1/roundtrip.vbt","wb");
    if (!file_handle) $fatal(1,"Cannot create tape image");
    for (integer i = 0; i < 16384; i = i + 1)
        $fwrite(file_handle,"%c",card.media[i]);
    $fclose(file_handle);
    for (integer i = 0; i < 16384; i = i + 1) card.media[i] = 0;
    file_handle = $fopen("out/expander1/roundtrip.vbt","rb");
    size = $fread(card.media,file_handle);
    $fclose(file_handle);
    if (size != 16384) $fatal(1,"Cannot reload tape image");
    reset_na = 0;
    host_data_n = 1;
    host_clock_n = 1;
    #1000;
    reset_na = 1;
    @(negedge clk);
    img_mounted = 1;
    @(negedge clk);
    img_mounted = 0;
    wait(!busy);
    #100000;
    for (integer record = 0; record < 2; record = record + 1) begin
        wait(!busy);
        initialize_remotes(record == 0 ? 3 : 2);
        host_clock_n = 0;
        transfer(1,reply);
        transfer(1,reply);
        transfer(1,reply);
        transfer(1,reply);
        transfer(0,reply);
        if (reply != 0) $fatal(1,"Length high %x",reply);
        transfer(0,reply);
        if (reply != 1) $fatal(1,"Length low %x",reply);
        transfer(0,reply);
        if (reply != payload[record]) $fatal(1,"Payload %0d: %x",record,reply);
        transfer(0,reply);
        if (reply != crc[record][7:0]) $fatal(1,"CRC low %x",reply);
        transfer(0,reply);
        if (reply != crc[record][15:8]) $fatal(1,"CRC high %x",reply);
        @(negedge playback_enable);
        @(negedge interrupt_n);
        if (data_n || !clock_n) $fatal(1,"Playback status %0d",record);
        @(posedge interrupt_n);
        host_data_n = 1;
        #100000;
        if (error) $fatal(1,"Tape LOAD %0d failed",record);
    end
    $display("Original ROM two-record SAVE/LOAD through remounted SD image passed");
    $finish;
end
initial begin
    #3200000000;
    $fatal(1,"Timeout, addr %x playback %b",dut.addr,playback_enable);
end
endmodule
