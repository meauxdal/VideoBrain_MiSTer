`timescale 1ns/1ps
module tb_status_messages;
reg clk = 0;
always #5 clk = ~clk;
reg reset = 1, osd = 0, vs = 0;
reg [127:0] status = 0;
reg started = 0, complete = 0, source_error = 0;
reg aborted = 0, calibrating = 0;
reg busy = 0, tape_error = 0, rewound = 0, ended = 0, cart_loaded = 0;
integer messages = 0, before_count;
reg [7:0] last_info = 0;
emu dut ();

always @(negedge clk) begin
    if (dut.info_req) begin
        if (osd || status[22]) $fatal(1, "Popup while menu open or messages disabled");
        messages = messages + 1;
        last_info = dut.info;
    end
    if (dut.menu_mask[8] !== !busy)
        $fatal(1, "Tape mounting guard does not follow busy");
    if (dut.menu_mask[10] !== !cart_loaded)
        $fatal(1, "Cartridge unloading guard changed");
    if (dut.menu_mask[5] !== status[19])
        $fatal(1, "Music mode guard does not follow repeat");
end

task tick;
    @(posedge clk); #1;
    @(negedge clk); #1;
endtask

task frame;
    vs = 0; tick;
    vs = 1; tick;
    vs = 0; tick;
endtask

task expect_message(input [7:0] code);
    integer previous;
    previous = messages;
    frame;
    if (messages != previous + 1 || last_info != code)
        $fatal(1, "Missing popup %0d (last %0d)", code, last_info);
endtask

initial begin
    force dut.clk_sys = clk;
    force dut.reset = reset;
    force dut.status = status;
    force dut.OSD_STATUS = osd;
    force dut.vid_vs = vs;
    force dut.source_started = started;
    force dut.source_complete = complete;
    force dut.source_error = source_error;
    force dut.source_aborted = aborted;
    force dut.joy_calibrating = calibrating;
    force dut.tape_busy = busy;
    force dut.tape_error = tape_error;
    force dut.tape_rewound = rewound;
    force dut.tape_ended = ended;
    force dut.cart_loaded = cart_loaded;
    force dut.joystick_connected = 1'b1;
    tick; reset = 0; tick;
    osd = 1; tick;
    if (dut.source_enabled) $fatal(1, "Entry enabled in OSD by default");
    status[31] = 1; tick;
    if (dut.source_enabled) $fatal(1, "Keep-alive started entry inside OSD");
    started = 1; tick;
    if (!dut.source_enabled) $fatal(1, "Keep-alive disabled active entry");
    status[31] = 0; tick;
    if (dut.source_enabled) $fatal(1, "OSD abort option ignored");
    started = 0; tick;
    osd = 0; frame;
    status[18] = 1; tick;
    if (dut.source_music_playback) $fatal(1, "Record mode ignored");
    status[19] = 1; tick;
    if (!dut.source_music_playback) $fatal(1, "Repeat did not select playback");
    status[19] = 0; tick;
    if (dut.source_music_playback) $fatal(1, "Record selection lost after repeat");
    started = 1; tick; expect_message(1);
    complete = 1; tick; expect_message(7);
    source_error = 1; tick; expect_message(2);
    before_count = messages;
    repeat (4) frame;
    if (messages != before_count) $fatal(1, "Repeated latched keyboard notice");

    osd = 1;
    aborted = 1; tick; frame;
    if (messages != before_count) $fatal(1, "Abort notice bypassed OSD deferral");
    osd = 0; expect_message(8);
    calibrating = 1; tick; expect_message(9);
    before_count = messages;
    repeat (59) frame;
    if (messages != before_count) $fatal(1, "Calibration refreshed too soon");
    expect_message(9);
    calibrating = 0; tick;
    before_count = messages;
    repeat (65) frame;
    if (messages != before_count) $fatal(1, "Calibration popup refreshed after completion");
    osd = 1; calibrating = 1; tick;
    calibrating = 0; tick;
    osd = 0; frame;
    if (messages != before_count) $fatal(1, "Stale calibration notice");

    busy = 1; tick; expect_message(5);
    before_count = messages;
    repeat (59) frame;
    if (messages != before_count) $fatal(1, "Busy popup refreshed too soon");
    expect_message(5);
    cart_loaded = 1; tick;
    busy = 0; tick; expect_message(6);
    before_count = messages;
    repeat (65) frame;
    if (messages != before_count) $fatal(1, "Busy popup refreshed while idle");

    osd = 1;
    busy = 1; tick; frame;
    busy = 0; tick; frame;
    if (messages != before_count) $fatal(1, "Lost menu deferral");
    osd = 0; expect_message(6);
    rewound = 1; tick; rewound = 0; expect_message(4);

    busy = 1; tick; expect_message(5);
    osd = 1;
    ended = 1; tick; ended = 0;
    busy = 0; tick; frame;
    osd = 0; expect_message(10);
    before_count = messages;
    repeat (65) frame;
    if (messages != before_count) $fatal(1, "End of tape notice repeated or became idle");

    busy = 1; tick; expect_message(5);
    busy = 0; tape_error = 1; tick; expect_message(3);
    before_count = messages;
    repeat (65) frame;
    if (messages != before_count) $fatal(1, "Idle or busy popup obscured tape error");

    osd = 1;
    rewound = 1; tick; rewound = 0;
    reset = 1; tick; reset = 0; osd = 0; frame;
    if (messages != before_count) $fatal(1, "Reset retained a stale popup");

    rewound = 1; tick; rewound = 0;
    status[22] = 1; tick; frame;
    started = 0; complete = 0; source_error = 0; tape_error = 0; aborted = 0; tick;
    started = 1; complete = 1; source_error = 1;
    aborted = 1; calibrating = 1;
    tape_error = 1; rewound = 1; busy = 1; tick;
    rewound = 0; repeat (65) frame;
    busy = 0; tick;
    if (messages != before_count || dut.pending_info != 0)
        $fatal(1, "Disabled messages were emitted or queued");
    status[22] = 0; frame;
    if (messages != before_count) $fatal(1, "Enabling messages replayed an old event");
    rewound = 1; tick; rewound = 0; expect_message(4);
    $display("Status popup and tape menu guard tests passed");
    $finish;
end
endmodule
