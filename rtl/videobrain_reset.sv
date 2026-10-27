module videobrain_reset (
    input wire clk,
    input wire reset,
    input wire vblank,
    input wire master_control,
    output wire master_reset
);

reg vblank_d = 1;
reg pressed = 0, pressed_d = 0;

// Board U39 samples the active-low key on /VBLANK; U26 ORs Q2 and /Q1.
always @(posedge clk) begin
    vblank_d <= vblank;
    if (reset) begin
        pressed <= 0;
        pressed_d <= 0;
    end else if (vblank_d && !vblank) begin
        pressed <= master_control;
        pressed_d <= pressed;
    end
end

assign master_reset = pressed && !pressed_d;

endmodule
