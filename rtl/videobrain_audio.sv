module videobrain_audio
(
	input                clk,
	input                reset,
	input          [1:0] code,
	input                stb,
	output signed [15:0] sample
);

reg signed [15:0] dac = 0;
reg signed [24:0] pole1 = 0, pole2 = 0;
wire signed [24:0] target = {dac, 9'b0};
wire signed [24:0] delta1 = target - pole1;
wire signed [24:0] delta2 = pole1 - pole2;

// Two 4.46 kHz poles at 14.318181 MHz, before output resampling.
always @(posedge clk) begin
	if (reset) begin
		dac <= 0;
		pole1 <= 0;
		pole2 <= 0;
	end else begin
		if (stb) dac <= {2'b00, code, 12'b0} - 16'sd8192;
		pole1 <= pole1 + (delta1 >>> 9);
		pole2 <= pole2 + (delta2 >>> 9);
	end
end

assign sample = pole2[24:9];

endmodule
