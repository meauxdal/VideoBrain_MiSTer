`timescale 1ns/1ns

module tb_joystick_timing;
reg clk = 0;
always #5 clk = ~clk;
reg reset = 1, enabled = 0, curve = 0;
reg [13:0] delay_ticks = 0;
reg [7:0] pot = 128;
reg [8:0] seed_y = 40;
wire [63:0] pots = {8{pot}};

videobrain_core native(
    .clk(clk), .reset_na(~reset), .progressive(1'b0),
    .expander_modem_rxd(1'b1), .expander_modem_txd(),
    .kbd_matrix(36'd0), .joy_fire(4'd0), .joy_pots(pots),
    .joy_connected(1'b1), .joy_timer_base(delay_ticks), .joy_timer_step(7'd0),
    .joy_timer_curve(curve), .joy_timer_auto(1'b0),
    .dl_addr(16'd0), .dl_data(8'd0), .dl_wr(1'b0), .dl_index(8'd0),
    .cart_unload(1'b0), .cart_loaded(),
    .unknown_cart_profile(8'd0), .infoman_printer_fix(1'b0)
);
videobrain_core progressive(
    .clk(clk), .reset_na(~reset), .progressive(1'b1),
    .expander_modem_rxd(1'b1), .expander_modem_txd(),
    .kbd_matrix(36'd0), .joy_fire(4'd0), .joy_pots(pots),
    .joy_connected(1'b1), .joy_timer_base(delay_ticks), .joy_timer_step(7'd0),
    .joy_timer_curve(curve), .joy_timer_auto(1'b0),
    .dl_addr(16'd0), .dl_data(8'd0), .dl_wr(1'b0), .dl_index(8'd0),
    .cart_unload(1'b0), .cart_loaded(),
    .unknown_cart_profile(8'd0), .infoman_printer_fix(1'b0)
);

integer ticks = 0, checked = 0, rollover_differences = 0;
always @(negedge clk) begin
    #1;
    ticks = ticks + 1;
    if (!reset) begin
        if (native.hpos_l !== progressive.hpos_l || native.hblank_l !== progressive.hblank_l)
            $fatal(1, "Horizontal phase changed");
        if (native.joy_timer !== progressive.joy_timer ||
            native.joy_armed !== progressive.joy_armed ||
            native.joy_timer_active !== progressive.joy_timer_active ||
            native.joy_capture_stb !== progressive.joy_capture_stb)
            $fatal(1, "Joystick reset, release or timer phase changed");
        if (native.uv_current_y !== native.vpos_l + (native.hpos_l >= 222) ||
            progressive.uv_current_y !== progressive.vpos_l + (progressive.hpos_l >= 222))
            $fatal(1, "Current Y phase changed");
    end
    if (ticks > 250000) $fatal(1, "Joystick timing test timed out");
end

task tick;
begin
    @(posedge clk);
    #1;
end
endtask

task measure(input integer y, input integer delay, input bit use_curve, input integer axis);
integer start_tick, expected_x, expected_ny, expected_py, lines_n, lines_p, raw_n, raw_p;
begin
    reset = 1;
    enabled = 0;
    seed_y = y;
    delay_ticks = delay;
    curve = use_curve;
    pot = axis;
    repeat (3) tick;
    @(negedge clk);
    reset = 0;
    // Seed the raster near rollover without simulating idle fields.
    force native.u_uv202.u_timing.vpos_l = seed_y;
    force progressive.u_uv202.u_timing.vpos_l = seed_y;
    force native.u_uv202.u_timing.field_l = 1'b1;
    force progressive.u_uv202.u_timing.field_l = 1'b1;
    repeat (2) tick;
    release native.u_uv202.u_timing.vpos_l;
    release progressive.u_uv202.u_timing.vpos_l;
    release native.u_uv202.u_timing.field_l;
    release progressive.u_uv202.u_timing.field_l;
    wait (native.hblank_l == 0);
    @(negedge clk);
    enabled = 1;
    tick;
    if (!native.joy_timer_active || native.hpos_l != 33 || native.uv_current_y != y)
        $fatal(1, "Wrong timer release phase");
    start_tick = ticks;
    while (!native.joy_capture_stb) tick;
    if (ticks - start_tick != delay + 1)
        $fatal(1, "Wrong elapsed timer ticks: %0d", ticks - start_tick);
    expected_x = 33 + (delay + 1)/4;
    expected_ny = (y + expected_x/228)%262;
    expected_py = (y + expected_x/228)%263;
    expected_x = expected_x%228;
    if (native.joy_capture_x != expected_x || progressive.joy_capture_x != expected_x ||
        native.joy_capture_y != expected_ny || progressive.joy_capture_y != expected_py)
        $fatal(1, "Wrong captured X/Y: native=%0d/%0d progressive=%0d/%0d expected=%0d/%0d/%0d",
               native.joy_capture_x, native.joy_capture_y,
               progressive.joy_capture_x, progressive.joy_capture_y,
               expected_x, expected_ny, expected_py);
    tick;
    if (native.u_sys_bus.u_uv201_regs.r_freeze_x != expected_x ||
        native.u_sys_bus.u_uv201_regs.r_freeze_y != expected_ny ||
        progressive.u_sys_bus.u_uv201_regs.r_freeze_x != expected_x ||
        progressive.u_sys_bus.u_uv201_regs.r_freeze_y != expected_py)
        $fatal(1, "Freeze register delivery changed");
    lines_n = ((expected_ny & 255) - (y & 255) - 1) & 255;
    lines_p = ((expected_py & 255) - (y & 255) - 1) & 255;
    raw_n = lines_n*228 + expected_x - 38;
    raw_p = lines_p*228 + expected_x - 38;
    if (raw_n != raw_p) rollover_differences = rollover_differences + 1;
    $display("Y=%0d delay=%0d X=%0d frozenY=%0d/%0d raw=%0d/%0d TennisReject=%0d/%0d BIOSReject=%0d/%0d",
             y, delay, expected_x, expected_ny, expected_py, raw_n, raw_p,
             lines_n >= 10, lines_p >= 10, lines_n >= 13, lines_p >= 13);
    checked = checked + 1;
end
endtask

initial begin
    // Hold CPU writes idle; exercise the actual timer, capture and freeze logic.
    force native.cpu_ce = 1'b0;
    force progressive.cpu_ce = 1'b0;
    force native.joy_enable_l = enabled;
    force progressive.joy_enable_l = enabled;
    force native.key_latch_l = 8'h01;
    force progressive.key_latch_l = 8'h01;
    force native.u_sys_bus.u_uv201_regs.r_cmd = 8'h02;
    force progressive.u_sys_bus.u_uv201_regs.r_cmd = 8'h02;
    measure(40, 2580, 0, 0);
    measure(40, 3476, 0, 128);
    measure(40, 4365, 0, 255);
    measure(40, 2644, 0, 0);
    measure(40, 5716, 0, 128);
    measure(40, 8764, 0, 255);
    measure(40, 1620, 1, 0);
    measure(40, 4564, 1, 128);
    measure(40, 11295, 1, 255);
    measure(40, 12636, 0, 0);
    measure(260, 2580, 0, 0);
    measure(260, 8764, 0, 255);
    measure(250, 11295, 1, 255);
    measure(261, 11295, 1, 255);
    if (checked != 14 || rollover_differences != 4)
        $fatal(1, "Missing joystick timing cases");
    $display("Joystick timer/capture phase test passed; rollover measurements differ as reported");
    $finish;
end
endmodule
