`timescale 1ns/1ps
module tb_apl_source_loader;
reg clk = 0;
always #5 clk = ~clk;
reg reset = 1, frame_tick = 0, download = 0, wr = 0;
reg [24:0] addr = 0;
reg [7:0] data = 0;
reg available = 1, symbols = 0, enabled = 0, cancel = 0;
reg [1:0] speed = 0;
reg music_playback = 0, auto_repeat = 0;
wire busy, error, complete;
wire [35:0] keys;
apl_source_loader #(.LINE_FRAMES(3)) dut (.*);
reg [7:0] packet [0:4103];
reg [35:0] previous = 0;
reg emulate_shift = 1;
integer presses = 0;
reg [5:0] observed [0:8191];
integer held_cycles [0:8191];
integer field_count = 0;
integer press_field [0:8191];
integer release_field [0:8191];
integer shift_delay = 0, shift_due = -1;

always @(negedge clk) begin
    if (frame_tick) field_count = field_count + 1;
    if (shift_due >= 0 && field_count >= shift_due) begin
        symbols = !symbols;
        shift_due = -1;
    end
    if (keys != 0 && previous == 0) begin
        if ((keys & (keys - 1)) != 0) $fatal(1, "Multiple playback keys");
        for (integer i = 0; i < 36; i = i + 1)
            if (keys[i]) observed[presses] = 6'(i);
        presses = presses + 1;
        held_cycles[presses - 1] = 0;
        press_field[presses - 1] = field_count;
        if (keys[11] && emulate_shift) begin
            if (shift_delay == 0) symbols = !symbols;
            else shift_due = field_count + shift_delay;
        end
    end
    if (keys == 0 && previous != 0) release_field[presses - 1] = field_count;
    if (keys != 0) held_cycles[presses - 1] = held_cycles[presses - 1] + 1;
    previous = keys;
end

task tick;
    @(posedge clk); #1;
endtask

task init_packet(input integer count);
    reg [15:0] checksum;
    checksum = 16'hffff;
    packet[0] = "V"; packet[1] = "B"; packet[2] = "K"; packet[3] = "1";
    packet[4] = 8'(count); packet[5] = 8'(count >> 8);
    for (integer n = 0; n < count; n = n + 1) begin
        checksum = checksum ^ {packet[n + 8], 8'd0};
        for (integer j = 0; j < 8; j = j + 1)
            checksum = checksum[15] ? (checksum << 1) ^ 16'h1021 : checksum << 1;
    end
    packet[6] = checksum[7:0]; packet[7] = checksum[15:8];
endtask

task send_packet(input integer count, input integer wrong_addr);
    download = 1;
    for (integer n = 0; n < count; n = n + 1) begin
        wr = 1; addr = n == wrong_addr ? 25'(n + 1) : 25'(n); data = packet[n];
        tick;
        if (keys != 0) $fatal(1, "Typed before validation");
    end
    download = 0; wr = 0; tick; tick;
endtask

task finish_entry;
    for (integer i = 0; i < 100000 && busy; i = i + 1) tick;
    if (busy || keys != 0) $fatal(1, "Playback failed to release");
endtask

task check_music_limit(input integer notes, input bit playback_mode, input bit repeat_song);
    integer offset, entered, expected;
    // Generated music preamble, rests/bank changes, and No-Record/Replay tail.
    packet[8] = 11; packet[11] = 19; packet[14] = 8'hfe;
    packet[17] = 11; packet[20] = 19;
    offset = 23;
    for (integer n = 0; n < notes; n = n + 1) begin
        packet[offset] = 255; packet[offset + 3] = 22; packet[offset + 6] = 29;
        offset = offset + 9;
    end
    packet[offset] = 11; packet[offset + 3] = 7;
    packet[offset + 6] = 11; packet[offset + 9] = 8'hfd;
    offset = offset + 12;
    for (integer n = 8; n < offset; n = n + 3) begin
        packet[n + 1] = 2; packet[n + 2] = 1;
    end
    init_packet(offset - 8); packet[3] = "2";
    entered = !playback_mode && notes > 79 ? 79 : notes;
    expected = 5 + entered * 2 + (playback_mode ? 3 : 4);
    music_playback = playback_mode; auto_repeat = repeat_song; presses = 0;
    send_packet(offset, -1);
    if (repeat_song) begin
        for (integer i = 0; i < 10000 && presses < expected * 2; i = i + 1) tick;
        if (!busy || error || complete || presses != expected * 2)
            $fatal(1, "Music cutoff repeat failed");
        cancel = 1; tick; cancel = 0;
    end else begin
        finish_entry;
        if (error || !complete || presses != expected)
            $fatal(1, "Music cutoff failed: notes=%0d playback=%0d presses=%0d expected=%0d",
                   notes, playback_mode, presses, expected);
    end
    for (integer pass = 0; pass < (repeat_song ? 2 : 1); pass = pass + 1) begin
        offset = pass * expected;
        if (observed[offset + 2] != (playback_mode ? 7 : 33))
            $fatal(1, "Music recording selector failed");
        for (integer n = 0; n < entered; n = n + 1)
            if (observed[offset + 5 + n * 2] != 22 || observed[offset + 6 + n * 2] != 29)
                $fatal(1, "Music note/bank order failed");
        offset = offset + 5 + entered * 2;
        if (observed[offset] != 11 || observed[offset + 1] != 7 || observed[offset + 2] != 11 ||
            (!playback_mode && observed[offset + 3] != 12))
            $fatal(1, "Music closing controls lost at cutoff");
    end
    auto_repeat = 0; music_playback = 0;
endtask

task check_speed(input [1:0] setting, input integer duration);
    integer held, released;
    speed = setting; symbols = 0; presses = 0;
    frame_tick = 0; shift_delay = 7;
    packet[8] = 0; packet[9] = 8'h61; packet[10] = 8'h61; packet[11] = 8'h9b;
    init_packet(4); send_packet(12, -1);
    speed = 2'd3; // Changes after download must not affect this file.
    for (integer i = 0; i < 250 && busy; i = i + 1) begin
        repeat (32) tick;
        frame_tick = 1; tick;
        frame_tick = 0; tick;
    end
    if (busy || error || !complete || presses != 5 || observed[0] != 0 ||
        observed[1] != 11 || observed[2] != 33 || observed[3] != 33 || observed[4] != 27)
        $fatal(1, "Speed %0d lost or reordered keys", setting);
    for (integer n = 0; n < 5; n = n + 1) begin
        held = (n == 1 || n == 4) && duration < 8 ? 8 : duration;
        if (release_field[n] - press_field[n] != held)
            $fatal(1, "Speed %0d hold mismatch at %0d", setting, n);
        released = n == 4 ? field_count : press_field[n + 1];
        if (released - release_field[n] != held + (n == 4 ? 3 : 0))
            $fatal(1, "Speed %0d gap or line wait mismatch at %0d", setting, n);
    end
    shift_delay = 0; speed = 0; frame_tick = 1;
endtask

initial begin
    tick; reset = 0; tick;
    packet[8] = 8'h61; packet[9] = 8'h56; packet[10] = 8'h61; packet[11] = 8'h9b;
    packet[12] = 8'h5e; packet[13] = 8'h56; packet[14] = 8'h5a; packet[15] = 8'h9b;
    init_packet(8);
    send_packet(16, -1);
    repeat (5) tick;
    if (!busy || error || presses != 0) $fatal(1, "OSD wait failed");
    enabled = 1; frame_tick = 1;
    finish_entry;
    if (error || !complete || presses != 9 || observed[0] != 11 || observed[1] != 33 ||
        observed[2] != 22 || observed[3] != 33 || observed[4] != 27 ||
        observed[5] != 30 || observed[6] != 22 || observed[7] != 26 || observed[8] != 27)
        $fatal(1, "Arithmetic key sequence mismatch");

    // A second load must use the live symbol latch without another SHIFT.
    presses = 0;
    send_packet(16, -1); finish_entry;
    if (error || presses != 8 || observed[0] != 33) $fatal(1, "Live mode mismatch");

    packet[8] = 0; // Letter I requires a transition back to letters.
    init_packet(4); presses = 0;
    send_packet(12, -1); finish_entry;
    if (error || observed[0] != 11 || observed[1] != 0) $fatal(1, "Letter mode mismatch");

    // Rejected streams must never emit a key.
    presses = 0; packet[6] = packet[6] ^ 1;
    send_packet(12, -1);
    if (!error || busy || presses != 0) $fatal(1, "Bad CRC accepted");
    init_packet(4); send_packet(11, -1);
    if (!error || busy || presses != 0) $fatal(1, "Truncated stream accepted");
    send_packet(12, 9);
    if (!error || busy || presses != 0) $fatal(1, "Wrong address accepted");
    packet[0] = "X"; send_packet(12, -1);
    if (!error || busy || presses != 0) $fatal(1, "Bad magic accepted");
    init_packet(4); packet[4] = 0; packet[5] = 0; send_packet(12, -1);
    if (!error || busy || presses != 0) $fatal(1, "Zero length accepted");
    init_packet(4); packet[4] = 1; packet[5] = 16; send_packet(12, -1);
    if (!error || busy || presses != 0) $fatal(1, "Oversize length accepted");
    packet[8] = 11; init_packet(4); send_packet(12, -1);
    if (!error || busy || presses != 0) $fatal(1, "Raw SHIFT accepted");

    packet[8] = 8'h61; init_packet(4);
    available = 0; send_packet(12, -1);
    if (!error || busy || presses != 0) $fatal(1, "Wrong cartridge accepted");
    available = 1;

    // Cancel while a key is held, then reopen OSD during another entry.
    send_packet(12, -1);
    while (keys == 0) tick;
    cancel = 1; tick; cancel = 0;
    if (busy || keys != 0 || complete) $fatal(1, "Cancel left a key held or reported completion");
    send_packet(12, -1);
    while (keys == 0) tick;
    enabled = 0; tick;
    if (busy || keys != 0) $fatal(1, "OSD cancel failed");
    enabled = 1;

    // Missing SHIFT acknowledgement must fail rather than keep toggling.
    symbols = 0; emulate_shift = 0;
    send_packet(12, -1); finish_entry;
    if (!error) $fatal(1, "Missing SHIFT acknowledgement ignored");
    emulate_shift = 1;

    // Exercise the final address in the staging RAM.
    for (integer n = 8; n < 4104; n = n + 1) packet[n] = 0;
    packet[4103] = 8'h9b;
    init_packet(4096); send_packet(4104, -1); finish_entry;
    if (error) $fatal(1, "Maximum stream failed");

    check_speed(0, 8);
    check_speed(1, 6);
    check_speed(2, 10);
    check_speed(3, 8);

    // Timed physical events work without APL and never consult its mode.
    available = 0; presses = 0; speed = 2;
    packet[8] = 11; packet[9] = 3; packet[10] = 2;
    packet[11] = 35; packet[12] = 5; packet[13] = 4;
    packet[14] = 255; packet[15] = 7; packet[16] = 0;
    packet[17] = 27; packet[18] = 2; packet[19] = 0;
    init_packet(12); packet[3] = "2";
    send_packet(20, -1); finish_entry;
    if (error || !complete || presses != 3 || observed[0] != 11 ||
        observed[1] != 35 || observed[2] != 27 || held_cycles[0] != 3 ||
        held_cycles[1] != 5 || held_cycles[2] != 2)
        $fatal(1, "Timed event sequence or hold duration mismatch");

    // Space field ticks apart to check release gaps and a silent wait.
    presses = 0; frame_tick = 0;
    send_packet(20, -1);
    for (integer i = 0; i < 50 && busy; i = i + 1) begin
        repeat (20) tick;
        frame_tick = 1; tick;
        frame_tick = 0; tick;
    end
    if (busy || error || presses != 3 || press_field[1] - press_field[0] != 5 ||
        press_field[2] - press_field[1] != 16)
        $fatal(1, "Timed release gap or silent wait mismatch");
    frame_tick = 1;

    presses = 0; packet[9] = 0;
    init_packet(12); packet[3] = "2"; send_packet(20, -1);
    if (!error || busy || presses != 0) $fatal(1, "Zero hold accepted");
    packet[9] = 3; packet[8] = 36;
    init_packet(12); packet[3] = "2"; send_packet(20, -1);
    if (!error || busy || presses != 0) $fatal(1, "Invalid physical key accepted");
    packet[8] = 11;
    init_packet(11); packet[3] = "2"; send_packet(19, -1);
    if (!error || busy || presses != 0) $fatal(1, "Partial timed event accepted");
    init_packet(12); packet[3] = "2";
    send_packet(20, -1);
    while (keys == 0) tick;
    cancel = 1; tick; cancel = 0;
    if (busy || keys != 0 || complete) $fatal(1, "Timed cancel failed");

    presses = 0;
    for (integer n = 8; n < 4103; n = n + 3) begin
        packet[n] = 35; packet[n + 1] = 1; packet[n + 2] = 0;
    end
    init_packet(4095); packet[3] = "2";
    send_packet(4103, -1); finish_entry;
    if (error || !complete || presses != 1365) $fatal(1, "Maximum timed stream failed");
    // Music controls select Record or No-Record and suppress replay in Playback.
    packet[8] = 8'hfe; packet[9] = 3; packet[10] = 2;
    packet[11] = 29; packet[12] = 5; packet[13] = 4;
    packet[14] = 8'hfd; packet[15] = 7; packet[16] = 0;
    init_packet(9); packet[3] = "2";
    presses = 0;
    send_packet(17, -1); finish_entry;
    if (error || !complete || presses != 3 || observed[0] != 33 ||
        observed[1] != 29 || observed[2] != 12)
        $fatal(1, "Record controls failed");
    music_playback = 1; presses = 0;
    send_packet(17, -1);
    music_playback = 0; // Mode is latched for the whole file.
    finish_entry;
    if (error || !complete || presses != 2 || observed[0] != 7 || observed[1] != 29)
        $fatal(1, "Playback controls failed");

    // Repeat must restart at byte zero, retain timing, and release on cancellation.
    music_playback = 1; auto_repeat = 1; presses = 0;
    frame_tick = 0;
    send_packet(17, -1);
    for (integer i = 0; i < 100 && presses < 6; i = i + 1) begin
        repeat (20) tick;
        frame_tick = 1; tick;
        frame_tick = 0; tick;
    end
    if (!busy || error || complete || presses != 6)
        $fatal(1, "Timed repeat failed");
    for (integer i = 0; i < 6; i = i + 1)
        if (observed[i] != (i % 2 == 0 ? 7 : 29)) $fatal(1, "Repeat order failed");
    for (integer i = 2; i < 6; i = i + 1)
        if (press_field[i] - press_field[i - 2] != 21) $fatal(1, "Repeat timing failed");
    cancel = 1; tick; cancel = 0;
    if (busy || keys != 0 || complete) $fatal(1, "Repeat cancel failed");
    repeat (40) tick;
    if (busy || presses != 6) $fatal(1, "Repeat restarted after cancel");

    frame_tick = 1;
    presses = 0; send_packet(17, -1);
    for (integer i = 0; i < 500 && presses < 3; i = i + 1) tick;
    enabled = 0; tick;
    if (busy || keys != 0 || complete) $fatal(1, "Repeat OSD cancel failed");
    enabled = 1; auto_repeat = 0; music_playback = 0;

    check_music_limit(78, 0, 0);
    check_music_limit(79, 0, 0);
    check_music_limit(80, 0, 0);
    check_music_limit(90, 0, 1);
    check_music_limit(90, 1, 0);

    // Both VBK1 completion paths must repeat, including final line waits.
    available = 1;
    for (integer line_end = 0; line_end < 2; line_end = line_end + 1) begin
        packet[8] = line_end != 0 ? 8'h9b : 0;
        init_packet(1); presses = 0; auto_repeat = 1;
        send_packet(9, -1);
        for (integer i = 0; i < 500 && presses < 3; i = i + 1) tick;
        if (!busy || error || complete || presses != 3) $fatal(1, "VBK1 repeat failed");
        auto_repeat = 0; finish_entry;
        if (!complete || error) $fatal(1, "Repeat disable failed");
    end

    $display("APL source loader tests passed");
    $finish;
end
initial begin
    #2000000; $fatal(1, "Test timed out");
end
endmodule
