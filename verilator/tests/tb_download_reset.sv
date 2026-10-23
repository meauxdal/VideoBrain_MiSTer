`timescale 1ns/1ps
module tb_download_reset;
reg clk = 0;
always #5 clk = ~clk;
reg external_reset = 0, download = 0, check_no_reset = 0;
reg [15:0] index = 4;
reg [127:0] status = 0;
reg [1:0] buttons = 0;
reg pll_locked = 1, osd_status = 0;
reg [10:0] ps2_key = 0;

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
    if (dut.dl_wr !== 0 || dut.dl_index !== 8'hff)
        $fatal(1, "Keyboard download reached ROM write path");
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

task hot_cartridge_download;
    status[24] = 1;
    index = 16'd1;
    check_no_reset = 1;
    download = 1;
    #1;
    if (dut.reset !== 0 || dut.system_reset !== 0)
        $fatal(1, "Hot cartridge download asserted reset");
    if (dut.dl_wr !== 1 || dut.dl_index !== 8'd2)
        $fatal(1, "Hot cartridge download did not reach cartridge ROM");
    download = 0;
    #1;
    if (dut.reset !== 0) $fatal(1, "Hot cartridge download left reset asserted");
    check_no_reset = 0;

    status[27] = 1;
    #1;
    if (dut.reset !== 1 || dut.system_reset !== 0)
        $fatal(1, "Master Control did not refresh hot-loaded cartridge");
    status[27] = 0;

    rom_download(16'd2);
    status[24] = 0;
    #1;
    if (dut.reset !== 0) $fatal(1, "Master Control reset did not release");
endtask

initial begin
    force dut.clk_sys = clk;
    force dut.pll_locked = pll_locked;
    force dut.buttons = buttons;
    force dut.ps2_key = ps2_key;
    force dut.OSD_STATUS = osd_status;
    force dut.status = status;
    force dut.ioctl_download = download;
    force dut.ioctl_index = index;
    force dut.ioctl_wr = 1'b1;
    #1;
    keyboard_download(16'd4);
    keyboard_download(16'h0104);
    rom_download(16'd0);
    rom_download(16'd1);
    rom_download(16'd2);
    rom_download(16'd64);
    hot_cartridge_download();
    index = 4;
    download = 1;
    status[0] = 1;
    #1;
    if (dut.reset !== 1) $fatal(1, "Keyboard download masked OSD reset");
    status[0] = 0;
    external_reset = 1;
    #1;
    if (dut.reset !== 1) $fatal(1, "Keyboard download masked external reset");
    external_reset = 0; download = 0;
    #1;
    buttons[1] = 1;
    #1;
    if (dut.reset !== 1) $fatal(1, "Framework button did not reset");
    buttons = 0; pll_locked = 0;
    #1;
    if (dut.reset !== 1) $fatal(1, "PLL unlock did not reset");
    pll_locked = 1;
    #1;
    if (dut.reset !== 0) $fatal(1, "Reset did not release");
    if (dut.joystick_connected !== 1) $fatal(1, "Joystick did not default to connected");
    status[5] = 1;
    #1;
    if (dut.joystick_connected !== 0) $fatal(1, "Joystick did not disconnect");
    status = 0;
    status[27] = 1;
    #1;
    if (dut.reset !== 1 || dut.system_reset !== 0)
        $fatal(1, "OSD MASTER CONTROL did not use the warm reset path");
    status = 0;
    status[28] = 1;
    #1;
    if (dut.reset !== 1 || dut.system_reset !== 1)
        $fatal(1, "Cartridge unload did not reset the machine");
    status = 0;

    // Menu visibility and unrelated status bits have no reset connection.
    check_no_reset = 1;
    osd_status = 1; status = ~(128'd1 | (128'd1 << 27) | (128'd1 << 28));
    #1;
    osd_status = 0; status = 0;
    #1;
    check_no_reset = 0;

    // ESC reaches MASTER CONTROL even while the OSD is visible.
    osd_status = 1;
    repeat (2) @(posedge clk);
    #1;
    ps2_key = {1'b1, 1'b1, 1'b0, 8'h76};
    repeat (2) @(posedge clk);
    #1;
    if (dut.reset !== 1 || dut.master_control !== 1)
        $fatal(1, "ESC did not assert MASTER CONTROL: reset=%b system=%b master=%b key=%h toggle=%b",
               dut.reset, dut.system_reset, dut.master_control, dut.ps2_key, dut.key_toggle);
    ps2_key = {1'b0, 1'b0, 1'b0, 8'h76};
    repeat (2) @(posedge clk);
    #1;
    if (dut.reset !== 0) $fatal(1, "ESC release did not clear MASTER CONTROL");
    for (integer code = 0; code < 512; code = code + 1) begin
        for (integer pressed = 1; pressed >= 0; pressed = pressed - 1) begin
            ps2_key = {!ps2_key[10], 1'(pressed), 9'(code)};
            repeat (2) @(posedge clk);
            #1;
            if (dut.reset !== (code == 9'h076 && pressed != 0))
                $fatal(1, "Unexpected reset for PS/2 code %h, pressed %0d", code, pressed);
        end
    end
    status[29] = 1;
    ps2_key = {!ps2_key[10], 1'b1, 9'h076};
    repeat (2) @(posedge clk);
    #1;
    if (dut.reset !== 0 || dut.master_control !== 0)
        $fatal(1, "Disabled ESC asserted MASTER CONTROL");
    ps2_key = {!ps2_key[10], 1'b0, 9'h076};
    repeat (2) @(posedge clk);
    #1;
    ps2_key = {!ps2_key[10], 1'b1, 9'h005};
    repeat (2) @(posedge clk);
    #1;
    if (dut.kbd_matrix[35] !== 1 || dut.reset !== 0)
        $fatal(1, "Disabling ESC blocked F1");
    ps2_key = {!ps2_key[10], 1'b0, 9'h005};
    repeat (2) @(posedge clk);
    #1;
    status[27] = 1;
    #1;
    if (dut.reset !== 1 || dut.system_reset !== 0)
        $fatal(1, "Disabling ESC blocked OSD MASTER CONTROL");
    status[27] = 0;
    status[29] = 0;
    ps2_key = {!ps2_key[10], 1'b1, 9'h076};
    repeat (2) @(posedge clk);
    #1;
    if (dut.master_control !== 1) $fatal(1, "Reenabled ESC did not reset");
    status[29] = 1;
    repeat (2) @(posedge clk);
    #1;
    if (dut.reset !== 0 || dut.master_control !== 0)
        $fatal(1, "Disabling held ESC did not release MASTER CONTROL");
    status[29] = 0;
    repeat (2) @(posedge clk);
    #1;
    if (dut.reset !== 0) $fatal(1, "Reenabling held ESC retriggered reset");
    ps2_key = {!ps2_key[10], 1'b0, 9'h076};
    repeat (2) @(posedge clk);
    #1;
    $display("Download reset checks passed");
    $finish;
end
endmodule
