`timescale 1ns/1ps
module tb_tape;
reg clk = 0;
always #5 clk = ~clk;
reg reset = 1, img_mounted = 0, img_readonly = 0, arm = 0;
reg [63:0] img_size = 16384;
reg record_data = 1, record_enable = 0, playback_enable = 0;
wire playback_data, busy, writable, armed, error;
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
task arm_recording;
    @(negedge clk);
    arm = 0;
    @(negedge clk);
    arm = 1;
    @(negedge clk);
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
    run_record(3);
    if (!error || card.writes != 0) $fatal(1,"Unarmed recording wrote media");
    arm_recording();
    if (!armed || error) $fatal(1,"Arm failed");
    repeat(3) @(negedge clk);
    if (!armed) $fatal(1,"Arm did not stay on");
    arm = 0;
    @(negedge clk);
    if (armed) $fatal(1,"Disarm failed");
    arm_recording();
    record_data = 1;
    record_enable = 1;
    playback_enable = 1;
    repeat(3) @(negedge clk);
    if (busy || error || !armed) $fatal(1,"Both remotes started a transfer");
    run_record(1700);
    if (error || armed || card.word_at(8) != 1701) $fatal(1,"SAVE failed");
    repeat(3) @(negedge clk);
    if (armed) $fatal(1,"Consumed arm re-enabled recording");
    for (integer i = 0; i < 1701; i = i + 1)
        if (card.word_at(512+i*4) != {~i[0],31'd40})
            $fatal(1,"Saved interval %0d: %x",i,card.word_at(512+i*4));

    reset = 1;
    repeat(3) @(negedge clk);
    reset = 0;
    mount_image();
    if (error) $fatal(1,"Recorded mount failed");
    @(negedge clk);
    playback_enable = 1;
    record_enable = 1;
    repeat(3) @(negedge clk);
    if (busy || error) $fatal(1,"Both remotes started playback");
    record_enable = 0;
    wait(dut.playing);
    @(negedge clk);
    for (integer i = 0; i < 1701; i = i + 1) begin
        repeat(40) begin
            @(negedge clk);
            if (playback_data != ~i[0]) $fatal(1,"Playback interval %0d",i);
        end
    end
    playback_enable = 0;
    @(negedge clk);
    if (error) $fatal(1,"LOAD failed");

    img_readonly = 1;
    mount_image();
    writes_before = card.writes;
    arm_recording();
    if (armed || writable) $fatal(1,"Readonly image armed");
    run_record(3);
    if (card.writes != writes_before) $fatal(1,"Readonly image changed");

    img_readonly = 0;
    mount_image();
    arm_recording();
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
    arm_recording();
    if (!armed || error) $fatal(1,"Interrupted image cannot be reused");

    img_size = 1024;
    mount_image();
    arm_recording();
    run_record(200);
    if (!error || card.word_at(8) != 32'hffffffff)
        $fatal(1,"Full image published");
    img_size = 16384;
    mount_image();
    arm_recording();
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
    arm_recording();
    if (armed) $fatal(1,"Foreign image armed");
    $display("Tape protection, sectors, wrap, replay, reset, capacity and SD stalls passed");
    $finish;
end
initial begin
    #10000000;
    $fatal(1,"Tape test timed out");
end
endmodule
