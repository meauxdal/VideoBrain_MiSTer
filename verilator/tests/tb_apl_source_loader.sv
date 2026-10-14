`timescale 1ns/1ps
module tb_apl_source_loader;
reg clk = 0;
always #5 clk = ~clk;
reg reset = 1, frame_tick = 0, download = 0, wr = 0;
reg [24:0] addr = 0;
reg [7:0] data = 0;
reg available = 1, symbols = 0, enabled = 0, cancel = 0;
wire busy, error, complete;
wire [35:0] keys;
apl_source_loader #(.KEY_FRAMES(2), .LINE_FRAMES(3)) dut (.*);
reg [7:0] packet [0:4103];
reg [35:0] previous = 0;
reg emulate_shift = 1;
integer presses = 0;
reg [5:0] observed [0:8191];

always @(negedge clk) begin
    if (keys != 0 && previous == 0) begin
        if ((keys & (keys - 1)) != 0) $fatal(1, "Multiple playback keys");
        for (integer i = 0; i < 36; i = i + 1)
            if (keys[i]) observed[presses] = 6'(i);
        presses = presses + 1;
        if (keys[11] && emulate_shift) symbols = !symbols;
    end
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
    $display("APL source loader tests passed");
    $finish;
end
initial begin
    #2000000; $fatal(1, "Test timed out");
end
endmodule
