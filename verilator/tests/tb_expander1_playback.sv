`timescale 1ns/1ps
module tb_expander1_playback;
reg clk = 0;
always #34.920639 clk = ~clk;
reg reset_na = 0;
reg host_data_n = 1, host_clock_n = 1;
wire data_n, clock_n, interrupt_n, record_data, record_enable, playback_enable;
reg playback_data = 1;
reg [15:0] dl_addr = 0;
reg [7:0] dl_data = 0;
reg dl_wr = 0;
expander1 dut(.*,.dl_index(8'd3));
reg [7:0] firmware[2048];
integer durations[2048];
integer count = 0, elapsed = 0;
reg recording = 0, level = 1;
always @(posedge clk) begin
    if (record_enable) begin
        if (!recording) begin
            elapsed = 1;
            level = record_data;
            recording = 1;
        end else if (level != record_data) begin
            durations[count] = elapsed;
            count = count + 1;
            elapsed = 1;
            level = record_data;
        end else elapsed = elapsed + 1;
    end else recording = 0;
end
initial begin
    @(posedge playback_enable);
    playback_data = !$test$plusargs("invert");
    $display("Playback start, %0d edges", count);
    for (integer i = 0; i < count; i = i + 1) begin
        repeat(durations[i]) @(posedge clk);
        playback_data <= !playback_data;
    end
    $display("Playback done, addr %x",dut.addr);
end
integer probes = 0;
reg [13:0] last_addr;
always @(posedge clk) begin
    last_addr <= dut.addr;
    if (playback_enable && dut.addr != last_addr && dut.addr == 'h385 && probes < 24) begin
        $display("RX sample %t pi %x", $time, dut.pi_a_n);
        probes <= probes + 1;
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
string path;
integer file_handle, size;
initial begin
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
    host_clock_n = 0;
    transfer(2,reply);
    transfer(0,reply);
    transfer(1,reply);
    transfer(0,reply);
    transfer(0,reply);
    transfer(1,reply);
    transfer('ha5,reply);
    transfer('h7e,reply);
    transfer('hd6,reply);
    @(negedge record_enable);
    reset_na = 0;
    host_data_n = 1;
    host_clock_n = 1;
    #1000;
    reset_na = 1;
    #100000;
    host_clock_n = 0;
    transfer(1,reply);
    transfer(0,reply);
    transfer(1,reply);
    transfer(0,reply);
    transfer(0,reply);
    if (reply != 0) $fatal(1,"Length high %x",reply);
    transfer(0,reply);
    if (reply != 1) $fatal(1,"Length low %x",reply);
    transfer(0,reply);
    if (reply != 'ha5) $fatal(1,"Payload %x",reply);
    transfer(0,reply);
    if (reply != 'h7e) $fatal(1,"CRC low %x",reply);
    transfer(0,reply);
    if (reply != 'hd6) $fatal(1,"CRC high %x",reply);
    @(negedge playback_enable);
    @(negedge interrupt_n);
    if (data_n || !clock_n) $fatal(1,"Playback status");
    $display("Original ROM SAVE/LOAD passed");
    $finish;
end
initial begin
    #1600000000;
    $fatal(1,"Timeout, addr %x playback %b",dut.addr,playback_enable);
end
endmodule
