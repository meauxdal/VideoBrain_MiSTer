//============================================================================
//  VideoBrain Family Computer for MiSTer
//  SPDX-License-Identifier: GPL-2.0-or-later
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//  See LICENSE and LICENSING.md in the repository root.
//
//============================================================================

module emu
(
	`include "sys/emu_ports.vh"
);


assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
// The modem cable has no flow control; assert the HPS's active-low handshakes.
assign {UART_RTS, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

assign VGA_F1 = progressive ? 1'b0 : vid_field;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign AUDIO_S   = 1;
assign AUDIO_MIX = 0;

assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;


wire [1:0] ar = status[122:121];

`include "build_id.v"
localparam CONF_STR = {
	"VideoBrain;UART300:110;",
	"F1,BIN,Load Cartridge;",
	"d8S0,VBT,Mount Tape;",
	"T[23],Rewind Tape;",
	"-;",
	"P3,Input;",
	"P3-;",
	"P3O[5],Joysticks,Connected,Disconnected;",
	"D4P3O[15:14],Stick Preset,Auto,Tennis,Gladiator;",
	"D4P3O[17:16],Paired Sticks,Off,1+2 / 3+4,1+3 / 2+4 (Doubles);",
	"D4P3T[20],Calibrate Sticks;",
	"P3-;",
	"P3O[29],Esc Reset,On,Off;",
	"P3F4,VBK,Load Keyboard File;",
	"P3O[18],Music Mode,Playback,Record;",
	"P3O[19],Music Repeat,Off,On;",
	"P1,Video;",
	"P1-;",
	"P1O[21],240p,Off,On;",
	"P1O[122:121],Aspect Ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1O[125:123],Scale,Normal,V-Integer,HV-Integer-,HV-Integer+,HV-Integer;",
	"P1O[4:3],Scandoubler FX,None,HQ2x,CRT 25%,CRT 50%;",
	"P2,System;",
	"P2-;",
	"P2F0,BIN,Load BIOS;",
	"P2F2,BIN,Load Expander 1 ROM;",
	"P2O[11:9],Mapper Fallback,Standard,Timeshare,Money Minder,APL/S,Info. Manager;",
	"P2O[22],Info Messages,On,Off;",
	//"P2O[26:24],Audio Test,Off,500 Hz,1 kHz,2 kHz,4 kHz;",
	"P2-;",
	"P2T[27],Master Control (Soft Reset);",
	"-;",
	"DAR[28],Unload Cartridge;",
	"R[0],Reset;",
	"J,Fire,Fire (Paired);",
	"jn,A,B;",
	"I,Keyboard entry started,Bad keyboard file,Tape error,Tape rewound,Tape busy,Tape idle,Keyboard entry finished;",
	"v,1;",
	"V,v",`BUILD_DATE
};

wire forced_scandoubler;
wire   [1:0] buttons;
wire [127:0] status;
wire joystick_connected = ~status[5];
wire cart_loaded;
wire  [10:0] ps2_key;
wire  [31:0] joystick_0, joystick_1, joystick_2, joystick_3;
wire [15:0] joystick_l_analog_0, joystick_l_analog_1;
wire [15:0] joystick_l_analog_2, joystick_l_analog_3;
wire [15:0] joystick_r_analog_0, joystick_r_analog_1;
wire [15:0] joystick_r_analog_2, joystick_r_analog_3;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire [15:0] ioctl_index;
wire [31:0] tape_lba;
wire tape_rd, tape_wr, tape_ack;
wire [13:0] tape_buff_addr;
wire [7:0] tape_buff_dout, tape_buff_din;
wire tape_buff_wr, tape_mounted, tape_readonly;
wire [63:0] tape_size;
wire tape_record_data, tape_record_enable, tape_playback_data, tape_playback_enable;
wire tape_busy, tape_error, tape_rewound;
wire [15:0] menu_mask = {5'd0, ~cart_loaded, 1'b0, ~tape_busy, 3'b000,
                         !joystick_connected, 4'b0011};
reg info_req = 0;
reg [7:0] info = 0, pending_info = 0;
wire [31:0] sd_lba[1];
wire [5:0] sd_blk_cnt[1];
wire [7:0] sd_buff_din[1];
assign sd_lba[0] = tape_lba;
assign sd_blk_cnt[0] = 0;
assign sd_buff_din[0] = tape_buff_din;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),

	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_in(128'd0),
	.status_set(1'b0),
	.status_menumask(menu_mask),
	.info_req(info_req),
	.info(info),

	.img_mounted(tape_mounted),
	.img_readonly(tape_readonly),
	.img_size(tape_size),
	.sd_lba(sd_lba),
	.sd_blk_cnt(sd_blk_cnt),
	.sd_rd(tape_rd),
	.sd_wr(tape_wr),
	.sd_ack(tape_ack),
	.sd_buff_addr(tape_buff_addr),
	.sd_buff_dout(tape_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(tape_buff_wr),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_index(ioctl_index),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.joystick_2(joystick_2),
	.joystick_3(joystick_3),
	.joystick_l_analog_0(joystick_l_analog_0),
	.joystick_l_analog_1(joystick_l_analog_1),
	.joystick_l_analog_2(joystick_l_analog_2),
	.joystick_l_analog_3(joystick_l_analog_3),
	.joystick_r_analog_0(joystick_r_analog_0),
	.joystick_r_analog_1(joystick_r_analog_1),
	.joystick_r_analog_2(joystick_r_analog_2),
	.joystick_r_analog_3(joystick_r_analog_3),
	.ps2_key(ps2_key)
);


wire clk_sys;
wire pll_locked;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.locked(pll_locked)
);

reg master_control = 0;
// Keep download out of the index decode to avoid a reset pulse on VBK start.
wire system_reset = RESET | status[0] | status[28] | buttons[1] |
                    (ioctl_download && (ioctl_index[7:0] != 8'd4)) | ~pll_locked;
wire reset = system_reset | master_control | status[27];

// The cartridge is OSD index 1. Expander 1 is boot1.rom or OSD index 2.
wire boot_dl = ioctl_download && (ioctl_index == 16'd0);
wire cart_dl = ioctl_download && (ioctl_index[7:0] == 8'd1);
wire source_dl = ioctl_download && (ioctl_index[7:0] == 8'd4);
wire apl_available, apl_load_error;
wire apl_symbols, source_busy, source_error, source_started, source_complete;
wire apl_input_ready, apl_key_accepted;
wire [35:0] source_keys;
wire expander_dl = ioctl_download && ((ioctl_index == 16'd64) ||
                                    (ioctl_index[7:0] == 8'd2));

wire [7:0] dl_index = expander_dl           ? 8'd3 :
                      cart_dl               ? 8'd2 :
                      boot_dl               ? (ioctl_addr[11] ? 8'd1 : 8'd0) : 8'hff;

wire [15:0] dl_addr = (cart_dl | expander_dl) ? ioctl_addr[15:0] : {4'd0, ioctl_addr[11:0]};
wire        dl_wr   = (boot_dl | cart_dl | expander_dl) & ioctl_wr;


// 9 columns by 4 rows, bit = col * 4 + row, active high. Columns 0-7 are
// selected by the CPU's port 0 latch, column 8 by UV201 CMD_KBD.
// Layout from the board netlist and MAME vidbrain.cpp.
reg [35:0] kbd_matrix = 0;

wire       key_pressed = ps2_key[9];
wire [8:0] key_code    = ps2_key[8:0];
reg        key_toggle  = 0;

always @(posedge clk_sys) begin
	key_toggle <= ps2_key[10];
	if (system_reset || status[29]) master_control <= 0;
	else if (key_toggle != ps2_key[10] && key_code == 'h076)
		master_control <= key_pressed;  // ESC = MASTER CONTROL
	if (reset) kbd_matrix <= 0;
	else if (key_toggle != ps2_key[10]) begin
		case (key_code)
			'h043: kbd_matrix[0]  <= key_pressed;  // I
			'h044: kbd_matrix[1]  <= key_pressed;  // O
			'h04D: kbd_matrix[2]  <= key_pressed;  // P
			'h04C: kbd_matrix[3]  <= key_pressed;  // ;

			'h03C: kbd_matrix[4]  <= key_pressed;  // U
			'h042: kbd_matrix[5]  <= key_pressed;  // K
			'h04B: kbd_matrix[6]  <= key_pressed;  // L
			'h041: kbd_matrix[7]  <= key_pressed;  // ,

			'h035: kbd_matrix[8]  <= key_pressed;  // Y
			'h03B: kbd_matrix[9]  <= key_pressed;  // J
			'h03A: kbd_matrix[10] <= key_pressed;  // M
			'h012: kbd_matrix[11] <= key_pressed;  // left shift
			'h059: kbd_matrix[11] <= key_pressed;  // right shift

			'h02C: kbd_matrix[12] <= key_pressed;  // T
			'h033: kbd_matrix[13] <= key_pressed;  // H
			'h031: kbd_matrix[14] <= key_pressed;  // N
			'h003: kbd_matrix[15] <= key_pressed;  // F5 = ERASE/RESTART

			'h02D: kbd_matrix[16] <= key_pressed;  // R
			'h034: kbd_matrix[17] <= key_pressed;  // G
			'h032: kbd_matrix[18] <= key_pressed;  // B
			'h029: kbd_matrix[19] <= key_pressed;  // space = RUN/STOP

			'h024: kbd_matrix[20] <= key_pressed;  // E
			'h02B: kbd_matrix[21] <= key_pressed;  // F
			'h02A: kbd_matrix[22] <= key_pressed;  // V
			'h00C: kbd_matrix[23] <= key_pressed;  // F4 = SPECIAL/ALARM

			'h01D: kbd_matrix[24] <= key_pressed;  // W
			'h023: kbd_matrix[25] <= key_pressed;  // D
			'h021: kbd_matrix[26] <= key_pressed;  // C
			'h004: kbd_matrix[27] <= key_pressed;  // F3 = NEXT/CLOCK

			'h015: kbd_matrix[28] <= key_pressed;  // Q
			'h01B: kbd_matrix[29] <= key_pressed;  // S
			'h022: kbd_matrix[30] <= key_pressed;  // X
			'h006: kbd_matrix[31] <= key_pressed;  // F2 = PREVIOUS/COLOR

			'h01C: kbd_matrix[32] <= key_pressed;  // A
			'h01A: kbd_matrix[33] <= key_pressed;  // Z
			'h04A: kbd_matrix[34] <= key_pressed;  // / = ?
			'h005: kbd_matrix[35] <= key_pressed;  // F1 = BACK/TEXT
			default: ;
		endcase
	end
end

wire [63:0] joy_pots;
wire [3:0] joy_fire;
wire [13:0] joy_timer_base;
wire [6:0] joy_timer_step;
wire joy_timer_auto;

videobrain_joystick joysticks (
	.clk(clk_sys),
	.reset(reset),
	.frame_tick(vid_vs && !source_vs_d),
	.calibrate(status[20]),
	.enabled(joystick_connected),
	.paired(status[17:16]),
	.preset(status[15:14]),
	.buttons({joystick_3, joystick_2, joystick_1, joystick_0}),
	.left_sticks({joystick_l_analog_3, joystick_l_analog_2, joystick_l_analog_1, joystick_l_analog_0}),
	.right_sticks({joystick_r_analog_3, joystick_r_analog_2, joystick_r_analog_1, joystick_r_analog_0}),
	.pots(joy_pots),
	.fire(joy_fire),
	.timer_base(joy_timer_base),
	.timer_step(joy_timer_step),
	.timer_auto(joy_timer_auto)
);


wire       ce_pix;
wire       vid_field;
wire [7:0] vid_r, vid_g, vid_b;
wire       vid_de, vid_hs, vid_vs, vid_hb, vid_vb;
wire [1:0] audio_code;
wire audio_stb;

reg source_vs_d = 0;
always @(posedge clk_sys) source_vs_d <= vid_vs;

reg source_started_d = 0, source_complete_d = 0, source_error_d = 0;
reg tape_busy_d = 0, tape_error_d = 0;
reg [5:0] tape_info_frames = 0;
always @(posedge clk_sys) begin
	source_started_d <= source_started;
	source_complete_d <= source_complete;
	source_error_d <= source_error;
	tape_busy_d <= tape_busy;
	tape_error_d <= tape_error;
	info_req <= 0;
	if (reset || status[22]) begin
		pending_info <= 0;
		tape_info_frames <= 0;
	end else begin
		// Defer until the menu closes; newer events replace stale notices.
		if (!OSD_STATUS && vid_vs && !source_vs_d) begin
			if (pending_info != 0) begin
				info <= pending_info;
				info_req <= 1;
				pending_info <= 0;
				tape_info_frames <= 0;
			end else if (tape_busy && !tape_error) begin
				// Refresh the transient popup once per second while busy.
				if (tape_info_frames == 59) begin
					info <= 5;
					info_req <= 1;
					tape_info_frames <= 0;
				end else tape_info_frames <= tape_info_frames + 1'b1;
			end else tape_info_frames <= 0;
		end
		if (source_started && !source_started_d) pending_info <= 1;
		if (source_complete && !source_complete_d) pending_info <= 7;
		if (tape_busy && !tape_busy_d) pending_info <= 5;
		if (!tape_busy && tape_busy_d && !tape_error) pending_info <= 6;
		if (tape_rewound) pending_info <= 4;
		if (source_error && !source_error_d) pending_info <= 2;
		if (tape_error && !tape_error_d) pending_info <= 3;
	end
end

// Switch before VSYNC; keep software-visible field parity toggling.
reg progressive = 0;
reg field_d = 0;
always @(posedge clk_sys) begin
	field_d <= vid_field;
	if (reset) progressive <= 0;
	else if (vid_field != field_d) progressive <= status[21];
end

apl_source_loader source_loader (
	.clk(clk_sys),
	.reset(reset),
	.frame_tick(vid_vs && !source_vs_d),
	.download(source_dl),
	.wr(ioctl_wr),
	.addr(ioctl_addr),
	.data(ioctl_dout),
	.available(apl_available),
	.symbols(apl_symbols),
	.input_ready(apl_input_ready),
	.key_accepted(apl_key_accepted),
	.music_playback(~status[18]),
	.auto_repeat(status[19]),
	.enabled(!OSD_STATUS),
	.cancel(|kbd_matrix),
	.busy(source_busy),
	.started(source_started),
	.complete(source_complete),
	.error(source_error),
	.keys(source_keys)
);

videobrain_tape tape
(
	.clk(clk_sys),
	.reset(reset),
	.img_mounted(tape_mounted),
	.img_readonly(tape_readonly),
	.img_size(tape_size),
	.rewind(status[23]),
	.record_data(tape_record_data),
	.record_enable(tape_record_enable),
	.playback_enable(tape_playback_enable),
	.playback_data(tape_playback_data),
	.busy(tape_busy),
	.writable(),
	.error(tape_error),
	.rewound(tape_rewound),
	.sd_lba(tape_lba),
	.sd_rd(tape_rd),
	.sd_wr(tape_wr),
	.sd_ack(tape_ack),
	.sd_buff_addr(tape_buff_addr[8:0]),
	.sd_buff_dout(tape_buff_dout),
	.sd_buff_din(tape_buff_din),
	.sd_buff_wr(tape_buff_wr)
);

videobrain_core core
(
	.clk        (clk_sys),
	.reset_na   (~reset),
	.progressive(progressive),

	.kbd_matrix (source_busy ? source_keys : kbd_matrix),
	.joy_fire   (joy_fire),
	.joy_pots   (joy_pots),
	.joy_connected (joystick_connected),
	.joy_timer_base (joy_timer_base),
	.joy_timer_step (joy_timer_step),
	.joy_timer_curve (1'b0),
	.joy_timer_auto (joy_timer_auto),
	.audio_code (audio_code),
	.audio_stb  (audio_stb),
	.joy_enable (),
	.expander_record_data (tape_record_data),
	.expander_record_enable (tape_record_enable),
	.expander_playback_data (tape_playback_data),
	.expander_playback_enable (tape_playback_enable),
	.expander_modem_rxd (UART_RXD),
	.expander_modem_txd (UART_TXD),
	.f8_po_a_n  (),
	.f8_po_b_n  (),

	.brclk_ena  (),
	.ce_pix     (ce_pix),
	.vid_idx    (),
	.vid_r      (vid_r),
	.vid_g      (vid_g),
	.vid_b      (vid_b),
	.vid_de     (vid_de),
	.vid_hs     (vid_hs),
	.vid_vs     (vid_vs),
	.vid_hb     (vid_hb),
	.vid_vb     (vid_vb),

	.fifo_valid (),
	.fifo_level (),

	.hblank     (),
	.vblank     (),
	.burst      (),
	.csync      (),
	.scanline   (),
	.field      (vid_field),
	.hpos       (),
	.vpos       (),

	.final_mod  (),
	.background (),
	.x_zoom     (),
	.y_zoom     (),
	.video_en   (),

	.dl_addr    (dl_addr),
	.dl_data    (ioctl_dout),
	.dl_wr      (dl_wr),
	.dl_index   (dl_index),
	.cart_unload(status[28]),
	.cart_loaded(cart_loaded),
	.unknown_cart_profile ({5'd0, status[11:9]}),
	.apl_available (apl_available),
	.apl_load_error (apl_load_error),
	.apl_symbols (apl_symbols),
	.apl_input_ready (apl_input_ready),
	.apl_key_accepted (apl_key_accepted),

	.pc0        (),
	.pc1        (),
	.dc0        ()
);


assign CLK_VIDEO = clk_sys;

// Measure each progressive picture or both native interlaced fields.
video_freak video_freak
(
	.CLK_VIDEO(CLK_VIDEO),
	.CE_PIXEL(ce_pix),
	.VGA_VS(vid_vs & (progressive | ~vid_field)),
	.HDMI_WIDTH(HDMI_WIDTH),
	.HDMI_HEIGHT(HDMI_HEIGHT),
	.VGA_DE(),
	.VIDEO_ARX(VIDEO_ARX),
	.VIDEO_ARY(VIDEO_ARY),
	.VGA_DE_IN(vid_de),
	.ARX(!ar ? 12'd4 : {10'd0, ar - 2'd1}),
	.ARY(!ar ? 12'd3 : 12'd0),
	.CROP_SIZE(12'd0),
	.CROP_OFF(5'd0),
	.SCALE(status[125:123])
);

wire [2:0] scale = status[4:3];
assign VGA_SL = (scale == 3) ? 2'b10 : (scale == 2) ? 2'b01 : 2'b00;

video_mixer #(.GAMMA(0)) video_mixer
(
	.CLK_VIDEO(CLK_VIDEO),
	.CE_PIXEL(CE_PIXEL),
	.ce_pix(ce_pix),

	.scandoubler(scale || forced_scandoubler),
	.hq2x(scale == 1),

	.gamma_bus(),

	.R(vid_r),
	.G(vid_g),
	.B(vid_b),

	.HSync(vid_hs),
	.VSync(vid_vs),
	.HBlank(vid_hb),
	.VBlank(vid_vb),

	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_VS(VGA_VS),
	.VGA_HS(VGA_HS),
	.VGA_DE(VGA_DE)
);


wire [15:0] audio_sample;
/*
wire [2:0] audio_test = status[26:24];
wire [31:0] audio_test_hz = audio_test == 1 ? 32'd500 :
                            audio_test == 2 ? 32'd1000 :
                            audio_test == 3 ? 32'd2000 :
                            audio_test == 4 ? 32'd4000 : 32'd0;
wire [1:0] audio_test_code;
videobrain_audio_tone audio_tone
(
	.clk(clk_sys),
	.reset(reset),
	.frequency_hz(audio_test_hz),
	.code(audio_test_code)
);
*/

videobrain_audio audio
(
	.clk(clk_sys),
	.reset(reset),
	//.code(audio_test_hz != 0 ? audio_test_code : audio_code),
	//.stb(audio_test_hz != 0 ? 1'b1 : audio_stb),
	.code(audio_code),
	.stb(audio_stb),
	.sample(audio_sample)
);

assign AUDIO_L = audio_sample;
assign AUDIO_R = audio_sample;

assign LED_USER = ioctl_download | source_busy | tape_busy;

endmodule
