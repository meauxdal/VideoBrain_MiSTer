`timescale 1ns/1ps
module tb_apl_reload;
reg clk = 0;
always #5 clk = ~clk;
reg reset = 1;
reg [15:0] dl_addr = 0;
reg [7:0] dl_data = 0, dl_index = 8'hff;
reg dl_wr = 0;
wire record_data, record_enable, playback_enable, playback_data;
wire [1:0] tape_error, sd_rd, sd_wr;
wire ready, y_zoom, video_en;
wire [7:0] background, port_a, port_b;
wire [15:0] pc;

videobrain_core core (
    .clk(clk), .reset_na(!reset), .progressive(1'b1),
    .kbd_matrix(36'd0), .joy_fire(4'd0), .joy_pots(64'h8080808080808080),
    .joy_connected(1'b1), .joy_timer_base(14'd2580), .joy_timer_step(7'd7),
    .joy_timer_curve(1'b0), .joy_timer_auto(1'b0),
    .expander_record_data(record_data), .expander_record_enable(record_enable),
    .expander_playback_enable(playback_enable), .expander_playback_data(playback_data),
    .expander_modem_rxd(1'b1), .f8_po_a_n(port_a), .f8_po_b_n(port_b),
    .dl_addr(dl_addr), .dl_data(dl_data), .dl_wr(dl_wr), .dl_index(dl_index),
    .cart_unload(1'b0), .unknown_cart_profile(8'd0), .infoman_printer_fix(1'b0),
    .apl_input_ready(ready), .y_zoom(y_zoom), .background(background),
    .video_en(video_en), .pc0(pc)
);
// Both real tape decks, with no media ever mounted.
videobrain_tapes tapes (
    .clk(clk), .reset(reset), .img_mounted(2'd0), .img_readonly(1'b0),
    .img_size(64'd0), .rewind(2'd0), .record_data(record_data),
    .record_enable(record_enable), .playback_enable(playback_enable),
    .playback_data(playback_data), .error(tape_error), .sd_rd(sd_rd), .sd_wr(sd_wr),
    .sd_ack(2'd0), .sd_buff_addr(9'd0), .sd_buff_dout(8'd0), .sd_buff_wr(1'b0)
);
always @(negedge clk) begin
    if (tape_error || sd_rd || sd_wr)
        $fatal(1, "Reload caused tape activity without media: error=%b read=%b write=%b pc=%h",
               tape_error, sd_rd, sd_wr, pc);
end

task load_image(input string path, input [7:0] index);
    integer fd, data_byte, address;
    fd = $fopen(path, "rb");
    if (!fd) $fatal(1, "Cannot open %s", path);
    @(negedge clk);
    reset = 1;
    dl_index = index;
    repeat (8) @(negedge clk);
    if (port_a !== 8'hff || port_b !== 8'hff)
        $fatal(1, "Download reset left stale CPU output ports");
    address = 0;
    data_byte = $fgetc(fd);
    while (data_byte != -1) begin
        dl_addr = 16'(address);
        dl_data = 8'(data_byte);
        dl_wr = 1;
        @(negedge clk);
        address++;
        data_byte = $fgetc(fd);
    end
    $fclose(fd);
    dl_wr = 0;
    dl_index = 8'hff;
    repeat (8) @(negedge clk);
endtask

reg have_baseline = 0, baseline_zoom;
reg [7:0] baseline_background;
task entry_screen;
    wait (ready);
    @(negedge clk);
    $display("APL/S ready: pc=%h zoom=%b background=%h", pc, y_zoom, background);
    if (!have_baseline) begin
        baseline_zoom = y_zoom;
        baseline_background = background;
        have_baseline = 1;
    end
    if (y_zoom != baseline_zoom || background != baseline_background || !video_en)
        $fatal(1, "APL/S entry screen video state changed after reload");
    $fflush();
endtask

string bios1, bios2, expander, cartridge;
integer reloads = 3;
initial begin
    if ($value$plusargs("reloads=%d", reloads) && reloads < 1)
        $fatal(1, "reloads must be positive");
    if (!$value$plusargs("bios1=%s", bios1) || !$value$plusargs("bios2=%s", bios2) ||
        !$value$plusargs("expander=%s", expander) || !$value$plusargs("cart=%s", cartridge))
        $fatal(1, "Provide bios1, bios2, expander and cart images");
    load_image(bios1, 0);
    load_image(bios2, 1);
    load_image(expander, 3);
    load_image(cartridge, 2);
    reset = 0;
    for (integer attempt = 0; attempt < reloads; attempt++) begin
        entry_screen;
        // Reload immediately at entry, then vary the timing around it.
        repeat (attempt * 7) @(negedge clk);
        load_image(cartridge, 2);
        reset = 0;
    end
    entry_screen;
    repeat (1000000) @(negedge clk);
    if (y_zoom != baseline_zoom) $fatal(1, "APL/S font mode changed after reload");
    $display("APL/S reload checks passed: %0d reloads, consistent font mode, no tape errors", reloads);
    $finish;
end
initial begin
    #20s;
    $fatal(1, "APL/S reload test timed out");
end
endmodule
