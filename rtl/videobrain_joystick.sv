module videobrain_joystick (
	input          clk,
	input          reset,
	input          frame_tick,
	input          calibrate,
	input          enabled,
	input    [1:0] paired,
	input    [1:0] preset,
	input  [127:0] buttons,
	input   [63:0] left_sticks,
	input   [63:0] right_sticks,
	output  [63:0] pots,
	output   [3:0] fire,
	output  [13:0] timer_base,
	output   [6:0] timer_step,
	output         timer_auto
);

function automatic [7:0] axis_to_pot(input [7:0] axis);
	axis_to_pot = ($signed(axis) >= -8'sd8 && $signed(axis) <= 8'sd8) ? 8'd128 : axis ^ 8'h80;
endfunction

function automatic [7:0] stick_pot(input neg, input pos, input [7:0] axis);
	stick_pot = (neg == pos) ? axis_to_pot(axis) : (neg ? 8'd0 : 8'd255);
endfunction

wire paired_enabled = (paired == 2'd1 || paired == 2'd2);

reg calibrate_d = 0;
reg [2:0] calibration_phase = 0;
reg [4:0] calibration_frames = 0;
reg [15:0] calibration_pots;

always @(posedge clk) begin
	calibrate_d <= calibrate;
	if (reset || !enabled) begin
		calibration_phase <= 0;
		calibration_frames <= 0;
	end else if (calibrate && !calibrate_d) begin
		calibration_phase <= 1;
		calibration_frames <= 0;
	end else if (frame_tick && calibration_phase != 0) begin
		// Hold each direction, then center, for 30 video frames.
		if (calibration_frames == 5'd29) begin
			calibration_frames <= 0;
			calibration_phase <= (calibration_phase == 3'd5) ? 3'd0 : calibration_phase + 3'd1;
		end else calibration_frames <= calibration_frames + 5'd1;
	end
end

always @* begin
	case (calibration_phase)
		3'd1: calibration_pots = 16'h8000;
		3'd2: calibration_pots = 16'h80ff;
		3'd3: calibration_pots = 16'h0080;
		3'd4: calibration_pots = 16'hff80;
		default: calibration_pots = 16'h8080;
	endcase
end

genvar i;
generate
for (i = 0; i < 4; i = i + 1) begin : sticks
	localparam integer PARTNER = i ^ 1;
	localparam integer DOUBLES_PARTNER = i ^ 2;
	wire [31:0] own_buttons = buttons[i*32 +: 32];
	wire [15:0] own_stick = left_sticks[i*16 +: 16];
	wire [15:0] paired_stick = (paired == 2'd2) ?
		right_sticks[DOUBLES_PARTNER*16 +: 16] : right_sticks[PARTNER*16 +: 16];
	wire paired_fire = (paired == 2'd2) ?
		buttons[DOUBLES_PARTNER*32 + 5] : buttons[PARTNER*32 + 5];
	// Channel order is V1,H1,V2,H2,V3,H3,V4,H4.
	wire [15:0] own_pots = {
		stick_pot(own_buttons[1], own_buttons[0], own_stick[7:0]),
		stick_pot(own_buttons[3], own_buttons[2], own_stick[15:8])
	};
	wire [15:0] paired_pots = {
		axis_to_pot(paired_stick[7:0]), axis_to_pot(paired_stick[15:8])
	};
	// An active own stick takes priority over both paired axes.
	assign pots[i*16 +: 16] = !enabled ? 16'h8080 :
		(calibration_phase != 0) ? calibration_pots :
		(paired_enabled && own_pots == 16'h8080) ? paired_pots : own_pots;
	assign fire[i] = enabled && (own_buttons[4] || (paired_enabled && paired_fire));
end
endgenerate

// Reserved presets use Auto. Curve takes precedence in the core.
assign timer_auto = (preset != 2'd1 && preset != 2'd2);
assign timer_base = (preset == 2'd1) ? 14'd2644 : 14'd2580;
assign timer_step = (preset == 2'd1) ? 7'd24 : 7'd7;

endmodule
