`timescale 1ns/1ps
module tb_download_reset;
reg clk = 0;
always #5 clk = ~clk;
reg external_reset = 0, download = 0, check_no_reset = 0;
reg [15:0] index = 4;
reg [127:0] status = 0;

emu dut (.RESET(external_reset));

always @(posedge dut.reset)
    if (check_no_reset) $fatal(1, "Keyboard download pulsed reset");

task keyboard_download(input [15:0] file_index);
    index = file_index;
    #1;
    // Model source_dl arriving after the raw download signal.
    force dut.source_dl = 1'b0;
    check_no_reset = 1;
    download = 1;
    #1;
    if (dut.reset !== 0) $fatal(1, "Keyboard download asserted reset");
    release dut.source_dl;
    #1;
    download = 0;
    #1;
    check_no_reset = 0;
endtask

task rom_download(input [15:0] file_index);
    index = file_index;
    // A stale source_dl must not suppress a ROM download reset either.
    force dut.source_dl = 1'b1;
    download = 1;
    #1;
    if (dut.reset !== 1) $fatal(1, "ROM download did not assert reset");
    download = 0;
    release dut.source_dl;
    #1;
    if (dut.reset !== 0) $fatal(1, "Download reset did not release");
endtask

initial begin
    force dut.clk_sys = clk;
    force dut.pll_locked = 1'b1;
    force dut.buttons = 2'b00;
    force dut.ps2_key = 11'd0;
    force dut.status = status;
    force dut.ioctl_download = download;
    force dut.ioctl_index = index;
    #1;
    keyboard_download(16'd4);
    keyboard_download(16'h0104);
    rom_download(16'd0);
    rom_download(16'd1);
    rom_download(16'd2);
    rom_download(16'd64);
    index = 4;
    download = 1;
    status[0] = 1;
    #1;
    if (dut.reset !== 1) $fatal(1, "Keyboard download masked OSD reset");
    status[0] = 0;
    external_reset = 1;
    #1;
    if (dut.reset !== 1) $fatal(1, "Keyboard download masked external reset");
    $display("Download reset checks passed");
    $finish;
end
endmodule
