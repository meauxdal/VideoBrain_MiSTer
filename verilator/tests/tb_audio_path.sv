module tb_audio_path
(
	input clk_core,
	input clk_audio,
	input reset,
	input sample_rate,
	input [31:0] tone_hz,
	output [1:0] tone_code,
	output signed [15:0] core_sample,
	output bclk,
	output lrclk,
	output sdata
);

videobrain_audio_tone tone
(
	.clk(clk_core), .reset(reset), .frequency_hz(tone_hz), .code(tone_code)
);

videobrain_audio core_audio
(
	.clk(clk_core), .reset(reset),
	.code(tone_code), .stb(1'b1),
	.sample(core_sample)
);

// sys_top defaults; unity volume, no boost, no Linux audio.
audio_out output_audio
(
	.reset(reset), .clk(clk_audio), .sample_rate(sample_rate),
	.flt_rate(32'd7056000), .cx(40'd4258969),
	.cx0(8'd3), .cx1(8'd3), .cx2(8'd1),
	.cy0(-24'd6216759), .cy1(24'd6143386), .cy2(-24'd2023767),
	.att(5'd0), .boost(2'd0), .mix(2'd0), .is_signed(1'b1),
	.core_l(core_sample), .core_r(core_sample),
	.alsa_l(16'd0), .alsa_r(16'd0),
	.i2s_bclk(bclk), .i2s_lrclk(lrclk), .i2s_data(sdata),
	.spdif(), .dac_l(), .dac_r()
);

endmodule
