`timescale 1ns/1ps
module tb_dual_tape;
reg clk = 0;
always #5 clk = ~clk;
reg reset = 1;
reg [1:0] img_mounted = 0, rewind = 0;
reg img_readonly = 0;
reg [63:0] img_size = 16384;
reg record_data = 1, record_enable = 0, playback_enable = 0;
wire playback_data;
wire [1:0] busy, error, rewound, ended, sd_rd, sd_wr, sd_ack;
wire [31:0] sd_lba[2];
wire [8:0] sd_buff_addr;
wire [7:0] sd_buff_dout, sd_buff_din[2];
wire sd_buff_wr;
reg concurrent_requests = 0;
videobrain_tapes dut(.*);
tape_dual_sd_model #(.DELAY(800)) card(.*);
always @(posedge clk)
    if (sd_rd[0] && sd_wr[1]) concurrent_requests <= 1;

task mount(input [1:0] decks);
    @(negedge clk);
    img_mounted = decks;
    @(negedge clk);
    img_mounted = 0;
    wait(busy == 0);
endtask

task record_edges(input integer edges);
    @(negedge clk);
    record_enable = 1;
    playback_enable = 0;
    for (integer i = 0; i < edges; i = i + 1) begin
        repeat(40) @(negedge clk);
        record_data = !record_data;
    end
    repeat(40) @(negedge clk);
    record_enable = 0;
endtask

reg [7:0] source[16384];
integer first_length;
initial begin
    repeat(3) @(negedge clk);
    {card.media[0][11],card.media[0][10],card.media[0][9],card.media[0][8]} = 1707;
    for (integer i = 0; i < 1707; i = i + 1)
        {card.media[0][515+i*4],card.media[0][514+i*4],card.media[0][513+i*4],card.media[0][512+i*4]} =
            {~i[0],31'd40};
    for (integer i = 0; i < 16384; i = i + 1) source[i] = card.media[0][i];
    reset = 0;
    mount(3);
    if (error != 0 || card.writes[0] != 0 || card.writes[1] != 0)
        $fatal(1,"Dual mount failed");
    if (dut.tape_deck[0].tape.length != 1707 || dut.tape_deck[1].tape.length != 0)
        $fatal(1,"SD header data crossed between decks");
    record_enable = 1;
    playback_enable = 1;
    repeat(4) @(negedge clk);
    if (busy != 0 || error != 0) $fatal(1,"Remote setup started a transfer");
    record_enable = 0;
    wait(dut.tape_deck[0].tape.playing || |error);
    @(negedge clk);
    if (|error) $fatal(1,"Playback start failed");
    for (integer i = 0; i < 1707; i = i + 1) begin
        for (integer j = 0; j < 40; j = j + 1) begin
            @(negedge clk);
            if (playback_data != ~i[0]) $fatal(1,"Playback interval %0d",i);
            if (i == 65 && j == 19) begin
                playback_enable = 0;
                record_edges(200);
                playback_enable = 1;
                @(negedge clk);
                if (!busy[1]) $fatal(1,"Record flush did not overlap playback");
                wait(dut.tape_deck[0].tape.playing || |error);
                @(negedge clk);
                if (|error) $fatal(1,"EDIT read/write/read handoff failed");
            end
        end
    end
    wait(ended[0]);
    @(negedge clk);
    if (busy[0] || ended[1] || playback_data != 1)
        $fatal(1,"Playback EOF did not release the source deck");
    playback_enable = 0;
    @(negedge clk);
    wait(busy == 0);
    if (|error || card.word_at(1,8) != 201) $fatal(1,"Destination recording failed");
    if (!concurrent_requests) $fatal(1,"SD arbitration was not exercised");
    for (integer i = 0; i < 201; i = i + 1)
        if (card.word_at(1,512+i*4) != {~i[0],31'd40})
            $fatal(1,"Destination interval %0d",i);
    first_length = card.word_at(1,8);
    record_edges(5);
    wait(busy == 0);
    if (|error || card.word_at(1,8) != first_length + 6)
        $fatal(1,"Playback reset destination append position");
    for (integer i = 0; i < 16384; i = i + 1)
        if (card.media[0][i] != source[i]) $fatal(1,"Source changed at %0d",i);
    if (card.writes[0] != 0) $fatal(1,"Playback deck issued a write");

    // REVIEW must also work with the recording deck unmounted.
    img_size = 0;
    mount(2);
    img_size = 16384;
    mount(1);
    record_enable = 1;
    repeat(20) @(negedge clk);
    record_enable = 0;
    playback_enable = 1;
    wait(dut.tape_deck[0].tape.playing || |error);
    @(negedge clk);
    if (|error) $fatal(1,"REVIEW required a recording image");
    playback_enable = 0;
    @(negedge clk);
    wait(busy == 0);
    img_size = 0;
    mount(1);
    img_size = 16384;
    mount(2);
    playback_enable = 1;
    repeat(20) @(negedge clk);
    if (|error) $fatal(1,"Record setup required a playback image");
    record_edges(3);
    wait(busy == 0);
    if (|error || card.word_at(1,8) != 4) $fatal(1,"Record-only SAVE failed");
    first_length = card.writes[1];
    img_readonly = 1;
    mount(2);
    record_edges(3);
    wait(busy == 0);
    if (!error[1] || card.writes[1] != first_length)
        $fatal(1,"Read-only destination changed");
    $display("Dual tape isolation, SD stalls, EDIT handoffs and append passed");
    $finish;
end
initial begin
    #10000000;
    $fatal(1,"Dual tape timeout");
end
endmodule
