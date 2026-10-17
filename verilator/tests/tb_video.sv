`timescale 1ns/1ns

module tb_video;
reg clk = 0;
always #5 clk = ~clk;
reg reset = 1;
reg [127:0] status_native = 0, status_progressive = 0;
wire ce, field, de, hs, vs, hb, vb;
wire [7:0] x, r, g, b;
wire [8:0] y;
wire [7:0] nr, ng, nb, pr, pg, pb;
wire nf, pf, nhs, nvs, nde, phs, pvs, pde, nce, pce;

video_test_source source(
    .clk(clk), .reset_na(~reset), .ce_pix(ce), .field(field),
    .de(de), .hs(hs), .vs(vs), .hb(hb), .vb(vb),
    .hpos(x), .vpos(y), .r(r), .g(g), .b(b)
);

emu native(
    .RESET(reset), .HDMI_WIDTH(12'd1920), .HDMI_HEIGHT(12'd1080),
    .VGA_R(nr), .VGA_G(ng), .VGA_B(nb), .VGA_F1(nf),
    .VGA_HS(nhs), .VGA_VS(nvs), .VGA_DE(nde), .CE_PIXEL(nce)
);
emu progressive(
    .RESET(reset), .HDMI_WIDTH(12'd1920), .HDMI_HEIGHT(12'd1080),
    .VGA_R(pr), .VGA_G(pg), .VGA_B(pb), .VGA_F1(pf),
    .VGA_HS(phs), .VGA_VS(pvs), .VGA_DE(pde), .CE_PIXEL(pce)
);

// Exercise top-level routing and measurement with native timing and rendering.
// Board peripherals and unused scaler arithmetic are omitted with iverilog -i.
initial begin
    force native.clk_sys = clk;
    force native.reset = reset;
    force native.status = status_native;
    force native.forced_scandoubler = 1'b0;
    force native.ce_pix = ce;
    force native.vid_field = field;
    force native.vid_de = de;
    force native.vid_hs = hs;
    force native.vid_vs = vs;
    force native.vid_hb = hb;
    force native.vid_vb = vb;
    force native.vid_r = r;
    force native.vid_g = g;
    force native.vid_b = b;
    force progressive.clk_sys = clk;
    force progressive.reset = reset;
    force progressive.status = status_progressive;
    force progressive.forced_scandoubler = 1'b0;
    force progressive.ce_pix = ce;
    force progressive.vid_field = field;
    force progressive.vid_de = de;
    force progressive.vid_hs = hs;
    force progressive.vid_vs = vs;
    force progressive.vid_hb = hb;
    force progressive.vid_vb = vb;
    force progressive.vid_r = r;
    force progressive.vid_g = g;
    force progressive.vid_b = b;
end

integer cycles = 0, last_field_cycle = 0, fields = 0;
integer native_measurements = 0, progressive_measurements = 0;
integer active_rows = 0, bottom_pixels = 0;
reg old_field = 0, old_de = 0, old_nmeasure = 0, old_pmeasure = 0;
reg old_pmode = 0;
always @(negedge clk) begin
    cycles = cycles + 1;
    if (!reset) begin
        if (field != old_field) begin
            if (fields > 0 && cycles - last_field_cycle != (old_field ? 262 : 263)*912)
                $fatal(1, "Native field timing changed");
            if (fields > 0 && active_rows != (old_field ? 241 : 242))
                $fatal(1, "Visible rows changed: %0d", active_rows);
            if (fields > 0 && bottom_pixels != 189)
                $fatal(1, "Bottom row missing: %0d", bottom_pixels);
            last_field_cycle = cycles;
            active_rows = 0;
            bottom_pixels = 0;
            fields = fields + 1;
        end
        old_field = field;
        if (ce) begin
            if (de && !old_de) active_rows = active_rows + 1;
            if (de && y == (field ? 261 : 262)) bottom_pixels = bottom_pixels + 1;
            old_de = de;
            if (native.video_freak.VGA_VS && !old_nmeasure)
                native_measurements = native_measurements + 1;
            if (progressive.video_freak.VGA_VS && !old_pmeasure)
                progressive_measurements = progressive_measurements + 1;
            old_nmeasure = native.video_freak.VGA_VS;
            old_pmeasure = progressive.video_freak.VGA_VS;
        end
        if (nf !== field) $fatal(1, "Native parity changed");
        if (pf !== (progressive.progressive ? 1'b0 : field))
            $fatal(1, "Progressive parity metadata incorrect");
        if (progressive.progressive != old_pmode && vs)
            $fatal(1, "Mode changed during VSYNC");
        old_pmode = progressive.progressive;
        if (fields >= 1 && nce) begin
            if ({nce, nhs, nvs, nde, nr, ng, nb} !== {pce, phs, pvs, pde, pr, pg, pb})
                $fatal(1, "Progressive mode changed live video data or sync");
        end
        if (fields >= 2 && fields <= 3 && y == 50 && ce) begin
            if (native.video_freak.vsize != 483 ||
                progressive.video_freak.vsize != (field ? 242 : 241))
                $fatal(1, "Wrong scaler height");
            if (native.video_freak.hsize != 189 || progressive.video_freak.hsize != 189)
                $fatal(1, "Wrong scaler width");
        end
    end
    if (cycles > 4000000) $fatal(1, "Video test timed out");
end

task request_mode(input bit mode);
begin
    wait (y == 100 && x == 100);
    @(negedge clk);
    status_progressive[21] = mode;
    #1;
    if (progressive.progressive !== !mode)
        $fatal(1, "Mode changed within active field");
    wait (field != old_field);
    repeat (3) @(negedge clk);
    if (progressive.progressive !== mode) $fatal(1, "Mode did not latch");
end
endtask

initial begin
    repeat (10) @(negedge clk);
    reset = 0;
    if (progressive.progressive !== 0) $fatal(1, "240p must default off");
    request_mode(1);
    wait (fields == 4);
    if (native_measurements != 2 || progressive_measurements != 4)
        $fatal(1, "Wrong measurement cadence: %0d/%0d", native_measurements, progressive_measurements);
    request_mode(0);
    request_mode(1);
    wait (vs == 0 && y == 50);
    @(negedge clk);
    reset = 1;
    repeat (3) @(negedge clk);
    if (progressive.progressive !== 0) $fatal(1, "Reset did not restore native metadata");
    $display("Video routing, timing and measurement test passed");
    $finish;
end
endmodule

// Mixer passthrough isolates input routing from Quartus-specific sys constructs.
module video_mixer #(parameter GAMMA = 0)(
    input CLK_VIDEO, ce_pix, scandoubler, hq2x,
    output CE_PIXEL,
    inout [21:0] gamma_bus,
    input [7:0] R, G, B,
    input HSync, VSync, HBlank, VBlank,
    output [7:0] VGA_R, VGA_G, VGA_B,
    output VGA_VS, VGA_HS, VGA_DE
);
assign CE_PIXEL = ce_pix;
assign {VGA_R, VGA_G, VGA_B} = {R, G, B};
assign {VGA_VS, VGA_HS, VGA_DE} = {VSync, HSync, ~(HBlank | VBlank)};
endmodule
