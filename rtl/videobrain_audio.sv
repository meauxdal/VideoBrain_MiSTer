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

assign sample = pole4[25:10];

endmodule
