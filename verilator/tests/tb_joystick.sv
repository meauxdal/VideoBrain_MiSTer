module tb_joystick;

reg clk = 0;
reg reset = 0;
reg frame_tick = 0;
reg calibrate = 0;
reg enabled = 0;
reg relative_mode = 0;
reg [1:0] paired = 0;
reg [1:0] preset = 0;
reg [127:0] buttons = 0;
reg [63:0] left_sticks = 0;
reg [63:0] right_sticks = 0;
wire [63:0] pots;
wire [3:0] fire;
wire [13:0] timer_base;
wire [6:0] timer_step;
wire timer_auto;
wire calibrating;
int partners[1:2][0:3] = '{'{1, 0, 3, 2}, '{2, 3, 0, 1}};

videobrain_joystick dut (.*);

task tick;
	#1 clk = 1;
	#1 clk = 0;
	#1;
endtask

task center_relative;
	reset = 1;
	tick();
	reset = 0;
	tick();
	assert (pots == {8{8'h80}}) else $fatal(1, "Relative reset center");
endtask

task frame;
	frame_tick = 1;
	tick();
	frame_tick = 0;
	tick();
endtask

function automatic [63:0] calibration_position(input int phase);
	case (phase)
		1: calibration_position = {4{16'h8000}};
		2: calibration_position = {4{16'h80ff}};
		3: calibration_position = {4{16'h0080}};
		4: calibration_position = {4{16'hff80}};
		default: calibration_position = {4{16'h8080}};
	endcase
endfunction

initial begin
	buttons = '1;
	left_sticks = '1;
	right_sticks = '1;
	paired = 1;
	#1;
	assert (pots == 64'h8080808080808080 && fire == 0) else $fatal(1, "Disabled inputs");

	enabled = 1;
	paired = 0;
	buttons = 0;
	// Exercise every analog report, including deadband edges, on all ports.
	for (int axis = -128; axis < 128; axis++) begin
		for (int i = 0; i < 4; i++) begin
			left_sticks[i*16 +: 16] = {8'(axis), 8'(-axis-1)};
		end
		#1;
		for (int i = 0; i < 4; i++) begin
			assert (pots[i*16 +: 8] == 8'((axis >= -8 && axis <= 8) ? 128 : axis + 128))
				else $fatal(1, "Vertical port %0d axis %0d", i, axis);
			assert (pots[i*16+8 +: 8] == 8'((axis >= -9 && axis <= 7) ? 128 : 127-axis))
				else $fatal(1, "Horizontal port %0d axis %0d", i, axis);
		end
	end

	for (int i = 0; i < 4; i++) begin
		buttons = 0;
		left_sticks = 0;
		right_sticks = 64'h407f407f407f407f;
		buttons[i*32 + 5] = 1;
		#1;
		assert (pots == 64'h8080808080808080 && fire == 0) else $fatal(1, "Pairing off");
		buttons[i*32 + 4] = 1;
		#1;
		assert (fire == (4'b0001 << i)) else $fatal(1, "Own fire port %0d", i);
		buttons[i*32 +: 4] = 4'b1010;
		#1;
		assert (pots[i*16 +: 16] == 16'h0000) else $fatal(1, "Up/left");
		buttons[i*32 +: 4] = 4'b0101;
		#1;
		assert (pots[i*16 +: 16] == 16'hffff) else $fatal(1, "Down/right");
		buttons[i*32 +: 4] = 4'b1111;
		#1;
		assert (pots[i*16 +: 16] == 16'h8080) else $fatal(1, "Opposing directions");
	end

	for (int mode = 1; mode <= 2; mode++) begin
		paired = 2'(mode);
		for (int i = 0; i < 4; i++) begin
			int partner;
			partner = partners[mode][i];
			buttons = 0;
			left_sticks = 0;
			right_sticks = 0;
			right_sticks[i*16 +: 16] = 16'h40c0;
			buttons[i*32 + 5] = 1;
			#1;
			assert (pots == ((64'h8080808080808080 & ~(64'hffff << (partner*16))) |
				(64'h40c0 << (partner*16)))) else $fatal(1, "Reciprocal right stick %0d", i);
			assert (fire == (4'b0001 << partner)) else $fatal(1, "Paired fire %0d", i);
			buttons[partner*32 + 4] = 1;
			#1;
			assert (fire == (4'b0001 << partner)) else $fatal(1, "Combined fire");
			buttons[i*32 + 5] = 0;
			#1;
			assert (fire == (4'b0001 << partner)) else $fatal(1, "Own fire survives release");
			left_sticks[partner*16 +: 16] = 16'h0010;
			#1;
			assert (pots[partner*16 +: 16] == 16'h9080) else $fatal(1, "Own stick priority");
			left_sticks[partner*16 +: 16] = 16'h08f8;
			#1;
			assert (pots[partner*16 +: 16] == 16'h40c0) else $fatal(1, "Deadband fallback");
			buttons[partner*32 + 2] = 1;
			#1;
			assert (pots[partner*16 +: 16] == 16'h80ff) else $fatal(1, "Own D-pad priority");
		end
	end

	paired = 3;
	buttons = 128'h20202020202020202020202020202020;
	left_sticks = 0;
	right_sticks = 64'h407f407f407f407f;
	#1;
	assert (pots == 64'h8080808080808080 && fire == 0) else $fatal(1, "Reserved pairing uses Off");

	for (int p = 0; p < 4; p++) begin
		preset = 2'(p);
		#1;
		assert (timer_auto == (p == 0 || p == 3)) else $fatal(1, "Auto selection");
		assert (timer_base == (p == 1 ? 2644 : 2580)) else $fatal(1, "Preset base");
		assert (timer_step == (p == 1 ? 24 : 7)) else $fatal(1, "Preset step");
	end
	// Calibration overrides live axes on all ports, regardless of pairing.
	buttons = '1;
	left_sticks = {8{8'h10}};
	right_sticks = '1;
	for (int mode = 0; mode < 4; mode++) begin
		paired = 2'(mode);
		calibrate = 1;
		tick();
		for (int phase = 1; phase <= 5; phase++) begin
			for (int f = 0; f < 30; f++) begin
				assert (calibrating && pots == calibration_position(phase) && fire == 4'hf)
					else $fatal(1, "Calibration mode %0d phase %0d frame %0d", mode, phase, f);
				tick();
				assert (pots == calibration_position(phase)) else $fatal(1, "Hold between frames");
				frame();
			end
		end
		assert (!calibrating && pots == {8{8'h90}}) else $fatal(1, "Live axes restored");
		frame();
		assert (pots == {8{8'h90}}) else $fatal(1, "Held trigger must not repeat");
		calibrate = 0;
		tick();
	end

	calibrate = 1;
	tick();
	assert (pots == calibration_position(1)) else $fatal(1, "Second activation");
	calibrate = 0;
	frame();
	calibrate = 1;
	tick();
	repeat (29) frame();
	assert (pots == calibration_position(1)) else $fatal(1, "Restart frame count");
	frame();
	assert (pots == calibration_position(2)) else $fatal(1, "Restart advances");
	reset = 1;
	tick();
	assert (!calibrating && pots == {8{8'h90}}) else $fatal(1, "Reset cancels calibration");
	reset = 0;
	tick();
	assert (pots == {8{8'h90}}) else $fatal(1, "Reset with held trigger");
	calibrate = 0;
	tick();
	calibrate = 1;
	tick();
	enabled = 0;
	tick();
	assert (!calibrating && pots == {8{8'h80}} && fire == 0) else $fatal(1, "Disconnect cancels calibration");
	enabled = 1;
	tick();
	assert (pots == {8{8'h90}}) else $fatal(1, "Reconnect leaves calibration idle");
	calibrate = 0;
	buttons = 0;
	left_sticks = 0;
	right_sticks = 0;
	paired = 0;
	relative_mode = 1;
	tick();
	assert (pots == {8{8'h80}}) else $fatal(1, "Relative mode starts centered");
	left_sticks = {4{16'h7f80}};
	repeat (100) tick();
	assert (pots == {8{8'h80}}) else $fatal(1, "Movement requires frame tick");
	frame();
	assert (pots == {4{16'h7c83}}) else $fatal(1, "Independent signed axes");
	left_sticks = 0;
	repeat (100) frame();
	assert (pots == {4{16'h7c83}}) else $fatal(1, "Release holds position");
	left_sticks = {4{16'h807f}};
	frame();
	assert (pots == {4{16'h7f7f}}) else $fatal(1, "Movement reverses");

	center_relative();
	left_sticks = {4{16'h08f8}};
	repeat (100) frame();
	assert (pots == {8{8'h80}}) else $fatal(1, "Relative deadband edges");
	left_sticks = {4{16'h0009}};
	repeat (31) frame();
	assert (pots == {8{8'h80}}) else $fatal(1, "Fine movement fraction");
	frame();
	assert (pots == {4{16'h8180}}) else $fatal(1, "Fine movement accumulates");

	left_sticks = {4{16'h7f80}};
	repeat (200) frame();
	assert (pots == {4{16'h00ff}}) else $fatal(1, "Both endpoints saturate");
	left_sticks = {4{16'h807f}};
	frame();
	assert (pots == {4{16'h03fb}}) else $fatal(1, "Endpoint reversal without windup");
	repeat (200) frame();
	assert (pots == {4{16'hff00}}) else $fatal(1, "Opposite endpoints saturate");
	left_sticks = {4{16'h7f80}};
	frame();
	assert (pots == {4{16'hfb03}}) else $fatal(1, "Opposite endpoint reversal");

	for (int mode = 1; mode <= 2; mode++) begin
		paired = 2'(mode);
		for (int i = 0; i < 4; i++) begin
			int partner;
			partner = partners[mode][i];
			left_sticks = 0;
			right_sticks = 0;
			center_relative();
			right_sticks[i*16 +: 16] = 16'h0040;
			left_sticks[partner*16 +: 16] = 16'h4000;
			frame();
			assert (pots == ((64'h8080808080808080 & ~(64'hffff << (partner*16))) |
				(64'h8081 << (partner*16)))) else $fatal(1, "Relative own priority and port isolation");
			left_sticks = 0;
			frame();
			assert (pots[partner*16 +: 16] == 16'h8181) else $fatal(1, "Paired input resumes at held position");
			buttons[i*32 + 5] = 1;
			#1;
			assert (fire == (4'b0001 << partner)) else $fatal(1, "Relative paired fire");
			buttons = 0;
		end
	end
	// Digital directions drive the same accumulator.
	paired = 0;
	left_sticks = 0;
	right_sticks = 0;
	center_relative();
	buttons[3:0] = 4'b0101;
	frame();
	assert (pots[15:0] == 16'h8383) else $fatal(1, "Relative D-pad movement");
	buttons = 0;
	frame();
	assert (pots[15:0] == 16'h8383) else $fatal(1, "Relative D-pad release");
	enabled = 0;
	tick();
	enabled = 1;
	tick();
	assert (pots == {8{8'h80}}) else $fatal(1, "Reconnect centers relative state");
	left_sticks = {8{8'h7f}};
	frame();
	paired = 1;
	tick();
	assert (pots == {8{8'h80}}) else $fatal(1, "Pairing change centers relative state");
	frame();
	preset = 1;
	tick();
	assert (pots == {8{8'h80}}) else $fatal(1, "Preset change centers relative state");
	frame();
	calibrate = 1;
	tick();
	for (int phase = 1; phase <= 5; phase++) begin
		for (int f = 0; f < 30; f++) begin
			assert (calibrating && pots == calibration_position(phase))
				else $fatal(1, "Relative calibration phase %0d frame %0d", phase, f);
			frame();
		end
	end
	assert (!calibrating && pots == {8{8'h80}}) else $fatal(1, "Relative calibration finishes centered");
	frame();
	assert (pots == {8{8'h83}}) else $fatal(1, "Relative motion resumes after calibration");
	relative_mode = 0;
	tick();
	assert (pots == {8{8'hff}}) else $fatal(1, "Absolute mode restores live input");
	relative_mode = 1;
	tick();
	assert (pots == {8{8'h80}}) else $fatal(1, "Relative reentry centers state");
	$display("Joystick routing, presets, calibration and relative movement passed");
	$finish;
end

endmodule
