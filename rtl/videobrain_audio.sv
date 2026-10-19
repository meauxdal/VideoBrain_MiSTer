module videobrain_audio
(
	input                clk,
	input                reset,
	input          [1:0] code,
	input                stb,
	output signed [15:0] sample
);

reg signed [15:0] dac = 0;
reg signed [25:0] pole1 = 0, pole2 = 0;
reg signed [25:0] pole3 = 0, pole4 = 0;
wire signed [25:0] target = {dac, 10'b0};
wire signed [25:0] delta1 = target - pole1;
wire signed [25:0] delta2 = pole1 - pole2;
wire signed [25:0] delta3 = pole2 - pole3;
wire signed [25:0] delta4 = pole3 - pole4;

// At 14.318181 MHz: 2.23, 4.46 and two 8.9 kHz poles before resampling.
always @(posedge clk) begin
	if (reset) begin
		dac <= 0;
		pole1 <= 0;
		pole2 <= 0;
		pole3 <= 0;
		pole4 <= 0;
	end else begin
		if (stb) dac <= {2'b00, code, 12'b0} - 16'sd8192;
		pole1 <= pole1 + (delta1 >>> 10);
		pole2 <= pole2 + (delta2 >>> 9);
		pole3 <= pole3 + (delta3 >>> 8);
		pole4 <= pole4 + (delta4 >>> 8);
	end
end

wire signed [23:0] filtered;
videobrain_audio_fir antialias
(
	.clk(clk),
	.reset(reset),
	.input_sample(pole4[25:2]),
	.output_sample(filtered)
);

reg signed [25:0] recon1 = 0, recon2 = 0, recon3 = 0, recon4 = 0;
wire signed [25:0] recon_target = {filtered, 2'b0};
wire signed [25:0] recon_delta1 = recon_target - recon1;
wire signed [25:0] recon_delta2 = recon1 - recon2;
wire signed [25:0] recon_delta3 = recon2 - recon3;
wire signed [25:0] recon_delta4 = recon3 - recon4;

// Suppress images from the FIR's held output before MiSTer resamples it.
always @(posedge clk) begin
	if (reset) begin
		recon1 <= 0;
		recon2 <= 0;
		recon3 <= 0;
		recon4 <= 0;
	end else begin
		recon1 <= recon1 + ((recon_delta1 + 26'sd64) >>> 7);
		recon2 <= recon2 + ((recon_delta2 + 26'sd64) >>> 7);
		recon3 <= recon3 + ((recon_delta3 + 26'sd64) >>> 7);
		recon4 <= recon4 + ((recon_delta4 + 26'sd64) >>> 7);
	end
end

wire signed [25:0] rounded_sample = recon4 + 26'sd512;
assign sample = rounded_sample[25:10];

endmodule

module videobrain_audio_tone
(
	input clk,
	input reset,
	input [31:0] frequency_hz,
	output [1:0] code
);

reg [31:0] phase = 0;
always @(posedge clk) begin
	if (reset || frequency_hz == 0) phase <= 0;
	else if (phase + frequency_hz >= 14318181) phase <= phase + frequency_hz - 14318181;
	else phase <= phase + frequency_hz;
end

assign code = phase < 7159090 ? 2'd0 : 2'd3;

endmodule

module videobrain_audio_fir
(
	input                       clk,
	input                       reset,
	input         signed [23:0] input_sample,
	output reg    signed [23:0] output_sample = 0
);

// At MCLK/128: 20-24 kHz transition, Kaiser beta 8.6, unity gain, Q1.23.
function automatic signed [23:0] coefficient(input [6:0] index);
	case (index)
	// FIR coefficients begin
		7'd0: coefficient = 24'shffffd4;
		7'd1: coefficient = 24'shfffff0;
		7'd2: coefficient = 24'sh000052;
		7'd3: coefficient = 24'sh000069;
		7'd4: coefficient = 24'shffffc6;
		7'd5: coefficient = 24'shffff1a;
		7'd6: coefficient = 24'shffff9f;
		7'd7: coefficient = 24'sh00011d;
		7'd8: coefficient = 24'sh00017d;
		7'd9: coefficient = 24'shffff84;
		7'd10: coefficient = 24'shfffd6e;
		7'd11: coefficient = 24'shfffead;
		7'd12: coefficient = 24'sh00029d;
		7'd13: coefficient = 24'sh0003e1;
		7'd14: coefficient = 24'shffff61;
		7'd15: coefficient = 24'shfffa3d;
		7'd16: coefficient = 24'shfffc73;
		7'd17: coefficient = 24'sh000500;
		7'd18: coefficient = 24'sh000877;
		7'd19: coefficient = 24'shffffcf;
		7'd20: coefficient = 24'shfff4da;
		7'd21: coefficient = 24'shfff7f0;
		7'd22: coefficient = 24'sh000849;
		7'd23: coefficient = 24'sh001065;
		7'd24: coefficient = 24'sh0001a2;
		7'd25: coefficient = 24'shffec99;
		7'd26: coefficient = 24'shffefb7;
		7'd27: coefficient = 24'sh000c31;
		7'd28: coefficient = 24'sh001d0c;
		7'd29: coefficient = 24'sh000629;
		7'd30: coefficient = 24'shffe0e4;
		7'd31: coefficient = 24'shffe1ea;
		7'd32: coefficient = 24'sh001001;
		7'd33: coefficient = 24'sh002ffa;
		7'd34: coefficient = 24'sh000f51;
		7'd35: coefficient = 24'shffd166;
		7'd36: coefficient = 24'shffcc27;
		7'd37: coefficient = 24'sh001266;
		7'd38: coefficient = 24'sh004adf;
		7'd39: coefficient = 24'sh001fc5;
		7'd40: coefficient = 24'shffbe22;
		7'd41: coefficient = 24'shffab7d;
		7'd42: coefficient = 24'sh001144;
		7'd43: coefficient = 24'sh006f8c;
		7'd44: coefficient = 24'sh003b23;
		7'd45: coefficient = 24'shffa795;
		7'd46: coefficient = 24'shff7c2a;
		7'd47: coefficient = 24'sh00097b;
		7'd48: coefficient = 24'sh00a022;
		7'd49: coefficient = 24'sh006679;
		7'd50: coefficient = 24'shff8eb9;
		7'd51: coefficient = 24'shff38fa;
		7'd52: coefficient = 24'shfff662;
		7'd53: coefficient = 24'sh00dfa6;
		7'd54: coefficient = 24'sh00a95e;
		7'd55: coefficient = 24'shff74fc;
		7'd56: coefficient = 24'shfed995;
		7'd57: coefficient = 24'shffd097;
		7'd58: coefficient = 24'sh0133a3;
		7'd59: coefficient = 24'sh011101;
		7'd60: coefficient = 24'shff5c26;
		7'd61: coefficient = 24'shfe4dca;
		7'd62: coefficient = 24'shff8a85;
		7'd63: coefficient = 24'sh01a8c3;
		7'd64: coefficient = 24'sh01b948;
		7'd65: coefficient = 24'shff4626;
		7'd66: coefficient = 24'shfd6e74;
		7'd67: coefficient = 24'shff0474;
		7'd68: coefficient = 24'sh0262fa;
		7'd69: coefficient = 24'sh02ef59;
		7'd70: coefficient = 24'shff34d7;
		7'd71: coefficient = 24'shfbbbc2;
		7'd72: coefficient = 24'shfdd2f1;
		7'd73: coefficient = 24'sh03f26d;
		7'd74: coefficient = 24'sh0601b8;
		7'd75: coefficient = 24'shff29c6;
		7'd76: coefficient = 24'shf62eee;
		7'd77: coefficient = 24'shf8c340;
		7'd78: coefficient = 24'sh0c9ee8;
		7'd79: coefficient = 24'sh267421;
		7'd80: coefficient = 24'sh325934;
	// FIR coefficients end
		default: coefficient = 0;
	endcase
endfunction

// Duplicate history for two synchronous reads and one simultaneous write.
reg signed [23:0] history_a [0:255];
reg signed [23:0] history_b [0:255];
reg [6:0] phase = 0;
reg [7:0] write_pos = 0, newest = 0, filled = 0, valid_count = 0;
reg [6:0] tap = 0;
reg running = 0, read_valid = 0, product_valid = 0;
reg read_last = 0, product_last = 0;
reg left_valid = 0, right_valid = 0;
reg signed [23:0] left_sample, right_sample;
reg signed [23:0] coeff = 0;
reg signed [48:0] product = 0;
reg signed [51:0] accumulator = 0;
wire signed [23:0] tap_left = left_valid ? left_sample : 24'sd0;
wire signed [23:0] tap_right = right_valid ? right_sample : 24'sd0;
wire signed [24:0] pair_sample = {tap_left[23], tap_left} + {tap_right[23], tap_right};
wire signed [51:0] sum = accumulator + {{3{product[48]}}, product};

always @(posedge clk) begin
	if (!reset && phase == 0) begin
		history_a[write_pos] <= input_sample;
		history_b[write_pos] <= input_sample;
	end
	if (running) begin
		left_sample <= history_a[8'(newest - tap)];
		right_sample <= history_b[8'(newest - 8'd160 + tap)];
	end
end

always @(posedge clk) begin
	if (reset) begin
		phase <= 0;
		write_pos <= 0;
		newest <= 0;
		filled <= 0;
		valid_count <= 0;
		tap <= 0;
		running <= 0;
		read_valid <= 0;
		product_valid <= 0;
		read_last <= 0;
		product_last <= 0;
		left_valid <= 0;
		right_valid <= 0;
		coeff <= 0;
		product <= 0;
		accumulator <= 0;
		output_sample <= 0;
	end else begin
		phase <= phase + 1'b1;
		if (phase == 0) begin
			newest <= write_pos;
			write_pos <= write_pos + 1'b1;
			if (filled < 161) filled <= filled + 1'b1;
			valid_count <= (filled < 161) ? filled + 1'b1 : filled;
			tap <= 0;
			running <= 1;
			accumulator <= 0;
		end

		read_valid <= running;
		if (running) begin
			left_valid <= ({1'b0, tap} < valid_count);
			right_valid <= (tap != 80 && (8'd160 - {1'b0, tap}) < valid_count);
			coeff <= coefficient(tap);
			read_last <= (tap == 80);
			if (tap == 80) running <= 0;
			else tap <= tap + 1'b1;
		end

		product_valid <= read_valid;
		if (read_valid) begin
			product <= pair_sample * coeff;
			product_last <= read_last;
		end
		if (product_valid) begin
			accumulator <= sum;
			if (product_last) output_sample <= 24'((sum + 52'sd4194304) >>> 23);
		end
	end
end

endmodule
