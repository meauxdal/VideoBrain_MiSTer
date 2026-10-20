`timescale 1ns/1ps
module tb_status_messages;
reg clk = 0;
always #5 clk = ~clk;
reg reset = 1, osd = 0, vs = 0;
reg started = 0, source_error = 0, tape_error = 0, rewound = 0;
integer messages = 0;
reg [7:0] last_info = 0;
emu dut ();

always @(negedge clk) begin
    if (dut.info_req) begin
        if (osd) $fatal(1,"Notification while menu open");
        messages = messages + 1;
        last_info = dut.info;
    end
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
    integer before_count;
    before_count = messages;
    frame;
    if (messages != before_count + 1 || last_info != code)
        $fatal(1,"Missing notification %0d", code);
    frame;
    if (messages != before_count + 1) $fatal(1,"Repeated notification");
endtask

initial begin
    force dut.clk_sys = clk;
    force dut.reset = reset;
    force dut.OSD_STATUS = osd;
    force dut.vid_vs = vs;
    force dut.source_started = started;
    force dut.source_error = source_error;
    force dut.tape_error = tape_error;
    force dut.tape_rewound = rewound;
    tick; reset = 0; tick;
    started = 1; tick; expect_message(1);
    osd = 1;
    source_error = 1; tick; frame;
    if (messages != 1) $fatal(1,"Lost menu deferral");
    osd = 0; expect_message(2);
    tape_error = 1; tick; expect_message(3);
    rewound = 1; tick; rewound = 0; expect_message(4);
    source_error = 0; tick;
    source_error = 1; tick; expect_message(2);
    osd = 1;
    rewound = 1; tick; rewound = 0;
    reset = 1; tick; reset = 0; osd = 0; frame;
    if (messages != 5) $fatal(1,"Reset retained a stale notification");
    $display("Status message tests passed");
    $finish;
end
endmodule
