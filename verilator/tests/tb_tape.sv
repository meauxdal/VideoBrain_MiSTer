`timescale 1ns/1ps
module tb_tape;
reg clk = 0;
always #5 clk = ~clk;
reg reset = 1, img_mounted = 0, img_readonly = 0, rewind = 0;
reg [63:0] img_size = 16384;
reg record_data = 1, record_enable = 0, playback_enable = 0;
wire playback_data, busy, writable, error;
wire [31:0] sd_lba;
wire sd_rd, sd_wr, sd_ack, sd_buff_wr;
wire [13:0] sd_buff_addr;
wire [7:0] sd_buff_dout, sd_buff_din;
videobrain_tape dut(.*,.sd_buff_addr(sd_buff_addr[8:0]));
tape_sd_model card(.*);

task mount_image;
    @(negedge clk);
    img_mounted = 1;
    @(negedge clk);
    img_mounted = 0;
    wait(!busy);
endtask
task run_record(input integer edges);
    @(negedge clk);
    playback_enable = 0;
    record_enable = 1;
    for (integer i = 0; i < edges; i = i + 1) begin
        repeat(40) @(negedge clk);
        record_data = !record_data;
    end
    repeat(40) @(negedge clk);
    record_enable = 0;
    wait(!busy);
endtask

integer writes_before;
initial begin
    repeat(3) @(negedge clk);
    reset = 0;
    mount_image();
    if (!writable || error) $fatal(1,"Blank mount failed");
    if (card.writes != 0) $fatal(1,"Mount changed image");
    repeat(3) @(negedge clk);
    record_data = 1;
    record_enable = 1;
    playback_enable = 1;
    repeat(3) @(negedge clk);
    if (busy || error || card.writes != 0) $fatal(1,"Both remotes started a transfer");
    run_record(1700);
    if (error || card.word_at(8) != 1701) $fatal(1,"SAVE failed");
    record_data = 0;
    run_record(5);
    if (error || card.word_at(8) != 1707) $fatal(1,"Append failed");
    for (integer i = 0; i < 1701; i = i + 1)
        if (card.word_at(512+i*4) != {~i[0],31'd40})
            $fatal(1,"Saved interval %0d: %x",i,card.word_at(512+i*4));
    for (integer i = 0; i < 6; i = i + 1)
        if (card.word_at(512+(1701+i)*4) != {i[0],31'd40})
            $fatal(1,"Appended interval %0d",i);

    @(negedge clk);
    playback_enable = 1;
    wait(dut.playing);
    @(negedge clk);
    if (error) $fatal(1,"Playback failed");
    playback_enable = 0;
    @(negedge clk);
    wait(!busy);

    reset = 1;
    repeat(3) @(negedge clk);
    reset = 0;
    mount_image();
    if (error) $fatal(1,"Recorded mount failed");
    writes_before = card.writes;
    @(negedge clk);
    playback_enable = 1;
    record_enable = 1;
    repeat(3) @(negedge clk);
    if (busy || error) $fatal(1,"Both remotes started playback");
    record_enable = 0;
    wait(dut.playing);
    @(negedge clk);
    for (integer i = 0; i < 1707; i = i + 1) begin
        for (integer j = 0; j < 40; j = j + 1) begin
            @(negedge clk);
            if (playback_data != ~i[0]) $fatal(1,"Playback interval %0d",i);
            if (i == 65 && j == 19) begin
                playback_enable = 0;
                @(negedge clk);
                wait(!busy);
                repeat(20) @(negedge clk);
                playback_enable = 1;
                wait(dut.playing);
                @(negedge clk);
            end
        end
    end
    playback_enable = 0;
    @(negedge clk);
    if (error) $fatal(1,"LOAD failed");
    if (card.writes != writes_before) $fatal(1,"LOAD changed image");

    run_record(3);
    if (error || card.word_at(8) != 4) $fatal(1,"SAVE after playback did not replace");
    run_record(5);
    if (error || card.word_at(8) != 10) $fatal(1,"Replacement append failed");
    @(negedge clk);
    rewind = 1;
    @(negedge clk);
    rewind = 0;
    wait(!busy);
    run_record(3);
    if (error || card.word_at(8) != 4) $fatal(1,"SAVE after rewind did not replace");

    reset = 1;
    repeat(3) @(negedge clk);
    reset = 0;
    run_record(3);
    if (error || card.word_at(8) != 4) $fatal(1,"SAVE after reset did not replace");

    img_readonly = 1;
    mount_image();
    writes_before = card.writes;
    if (writable) $fatal(1,"Readonly image writable");
    run_record(3);
    if (card.writes != writes_before) $fatal(1,"Readonly image changed");

    img_readonly = 0;
    mount_image();
    @(negedge clk);
    record_enable = 1;
    repeat(10) @(negedge clk);
    reset = 1;
    record_enable = 0;
    repeat(3) @(negedge clk);
    reset = 0;
    wait(!busy);
    mount_image();
    if (!error || card.word_at(8) != 32'hffffffff)
        $fatal(1,"Interrupted recording published");
    run_record(3);
    if (error || card.word_at(8) != 4) $fatal(1,"Interrupted image cannot be reused");

    img_size = 1024;
    mount_image();
    run_record(200);
    if (!error || card.word_at(8) != 32'hffffffff)
        $fatal(1,"Full image published");
    img_size = 16384;
    mount_image();
    @(negedge clk);
    record_enable = 1;
    repeat(2000) begin
        repeat(2) @(negedge clk);
        record_data = !record_data;
    end
    record_enable = 0;
    wait(!busy);
    if (!error || card.word_at(8) != 32'hffffffff)
        $fatal(1,"Buffer overflow published");

    {card.media[11],card.media[10],card.media[9],card.media[8]} = 32'd2000;
    for (integer i = 0; i < 2000; i = i + 1)
        {card.media[515+i*4],card.media[514+i*4],card.media[513+i*4],card.media[512+i*4]} =
            {~i[0],31'd2};
    mount_image();
    @(negedge clk);
    playback_enable = 1;
    wait(error);
    @(negedge clk);
    if (playback_data != 1) $fatal(1,"Underrun left playback active");
    playback_enable = 0;
    wait(!busy);

    card.media[0] = 0;
    mount_image();
    if (!error || writable) $fatal(1,"Foreign image accepted");
    writes_before = card.writes;
    run_record(3);
    if (card.writes != writes_before) $fatal(1,"Foreign image changed");
    $display("Tape protection, sectors, wrap, replay, reset, capacity and SD stalls passed");
    $finish;
end
initial begin
    #10000000;
    $fatal(1,"Tape test timed out");
end
endmodule
