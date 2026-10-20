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
// Restore the FIR's quarter gain within the reconstruction headroom.
wire signed [25:0] recon_target = {filtered[21:0], 4'b0};
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

/*
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
*/

module videobrain_audio_fir
(
	input                       clk,
	input                       reset,
	input         signed [23:0] input_sample,
	output reg    signed [23:0] output_sample = 0
);

// At MCLK/128: compensated rolloff, 13 kHz cutoff, quarter gain, Q1.23.
function automatic signed [23:0] coefficient(input [6:0] index);
	case (index)
	// FIR coefficients begin
		7'd0: coefficient = 24'sh000008;
		7'd1: coefficient = 24'shffffd3;
		7'd2: coefficient = 24'shffff99;
		7'd3: coefficient = 24'shffff87;
		7'd4: coefficient = 24'shffffc4;
		7'd5: coefficient = 24'sh00004c;
		7'd6: coefficient = 24'sh0000e3;
		7'd7: coefficient = 24'sh000127;
		7'd8: coefficient = 24'sh0000c8;
		7'd9: coefficient = 24'shffffc1;
		7'd10: coefficient = 24'shfffe7f;
		7'd11: coefficient = 24'shfffdbc;
		7'd12: coefficient = 24'shfffe1d;
		7'd13: coefficient = 24'shffffc7;
		7'd14: coefficient = 24'sh000218;
		7'd15: coefficient = 24'sh0003d7;
		7'd16: coefficient = 24'sh0003c9;
		7'd17: coefficient = 24'sh000176;
		7'd18: coefficient = 24'shfffda5;
		7'd19: coefficient = 24'shfffa3a;
		7'd20: coefficient = 24'shfff956;
		7'd21: coefficient = 24'shfffc1e;
		7'd22: coefficient = 24'sh0001d2;
		7'd23: coefficient = 24'sh0007c9;
		7'd24: coefficient = 24'sh000a9a;
		7'd25: coefficient = 24'sh0007f1;
		7'd26: coefficient = 24'sh000029;
		7'd27: coefficient = 24'shfff6aa;
		7'd28: coefficient = 24'shfff08d;
		7'd29: coefficient = 24'shfff200;
		7'd30: coefficient = 24'shfffbab;
		7'd31: coefficient = 24'sh0009a2;
		7'd32: coefficient = 24'sh0014c6;
		7'd33: coefficient = 24'sh001645;
		7'd34: coefficient = 24'sh000b89;
		7'd35: coefficient = 24'shfff875;
		7'd36: coefficient = 24'shffe650;
		7'd37: coefficient = 24'shffdf71;
		7'd38: coefficient = 24'shffe994;
		7'd39: coefficient = 24'sh0001d8;
		7'd40: coefficient = 24'sh001cfe;
		7'd41: coefficient = 24'sh002c5c;
		7'd42: coefficient = 24'sh002594;
		7'd43: coefficient = 24'sh000905;
		7'd44: coefficient = 24'shffe338;
		7'd45: coefficient = 24'shffc7b9;
		7'd46: coefficient = 24'shffc738;
		7'd47: coefficient = 24'shffe5df;
		7'd48: coefficient = 24'sh00173a;
		7'd49: coefficient = 24'sh0042c0;
		7'd50: coefficient = 24'sh004fc0;
		7'd51: coefficient = 24'sh0032f5;
		7'd52: coefficient = 24'shfff68f;
		7'd53: coefficient = 24'shffb76f;
		7'd54: coefficient = 24'shff97be;
		7'd55: coefficient = 24'shffacd7;
		7'd56: coefficient = 24'shfff1f2;
		7'd57: coefficient = 24'sh004778;
		7'd58: coefficient = 24'sh0080ec;
		7'd59: coefficient = 24'sh007ba6;
		7'd60: coefficient = 24'sh0032ec;
		7'd61: coefficient = 24'shffc61d;
		7'd62: coefficient = 24'shff6bf1;
		7'd63: coefficient = 24'shff5775;
		7'd64: coefficient = 24'shff9beb;
		7'd65: coefficient = 24'sh001ea3;
		7'd66: coefficient = 24'sh00a033;
		7'd67: coefficient = 24'sh00da9a;
		7'd68: coefficient = 24'sh00a660;
		7'd69: coefficient = 24'sh00134f;
		7'd70: coefficient = 24'shff6617;
		7'd71: coefficient = 24'shfef914;
		7'd72: coefficient = 24'shff0e0c;
		7'd73: coefficient = 24'shffa81a;
		7'd74: coefficient = 24'sh008335;
		7'd75: coefficient = 24'sh01310f;
		7'd76: coefficient = 24'sh014fb0;
		7'd77: coefficient = 24'sh00bf4a;
		7'd78: coefficient = 24'shffba53;
		7'd79: coefficient = 24'shfebfea;
		7'd80: coefficient = 24'shfe5746;
		7'd81: coefficient = 24'shfec86b;
		7'd82: coefficient = 24'shffef0b;
		7'd83: coefficient = 24'sh014240;
		7'd84: coefficient = 24'sh021284;
		7'd85: coefficient = 24'sh01e2b6;
		7'd86: coefficient = 24'sh00afec;
		7'd87: coefficient = 24'shff004d;
		7'd88: coefficient = 24'shfdab41;
		7'd89: coefficient = 24'shfd70cf;
		7'd90: coefficient = 24'shfe91eb;
		7'd91: coefficient = 24'sh009ff8;
		7'd92: coefficient = 24'sh02a2a5;
		7'd93: coefficient = 24'sh0389b6;
		7'd94: coefficient = 24'sh02b802;
		7'd95: coefficient = 24'sh0062c3;
		7'd96: coefficient = 24'shfd8fa5;
		7'd97: coefficient = 24'shfba7f3;
		7'd98: coefficient = 24'shfbcc64;
		7'd99: coefficient = 24'shfe3940;
		7'd100: coefficient = 24'sh020a64;
		7'd101: coefficient = 24'sh058737;
		7'd102: coefficient = 24'sh06dfb2;
		7'd103: coefficient = 24'sh050aab;
		7'd104: coefficient = 24'sh005e63;
		7'd105: coefficient = 24'shfa9489;
		7'd106: coefficient = 24'shf62a6b;
		7'd107: coefficient = 24'shf55912;
		7'd108: coefficient = 24'shf914e6;
		7'd109: coefficient = 24'sh008820;
		7'd110: coefficient = 24'sh094a1e;
		7'd111: coefficient = 24'sh1044da;
		7'd112: coefficient = 24'sh12ec3c;
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
		right_sample <= history_b[8'(newest - 8'd224 + tap)];
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
			if (filled < 225) filled <= filled + 1'b1;
			valid_count <= (filled < 225) ? filled + 1'b1 : filled;
			tap <= 0;
			running <= 1;
			accumulator <= 0;
		end

		read_valid <= running;
		if (running) begin
			left_valid <= ({1'b0, tap} < valid_count);
			right_valid <= (tap != 112 && (8'd224 - {1'b0, tap}) < valid_count);
			coeff <= coefficient(tap);
			read_last <= (tap == 112);
			if (tap == 112) running <= 0;
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
