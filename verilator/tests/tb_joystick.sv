module tb_joystick;

reg enabled = 0;
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
int partners[1:2][0:3] = '{'{1, 0, 3, 2}, '{2, 3, 0, 1}};

videobrain_joystick dut (.*);

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
	$display("Joystick routing and presets passed");
	$finish;
end

endmodule
