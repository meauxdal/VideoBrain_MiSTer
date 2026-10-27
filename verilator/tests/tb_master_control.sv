`timescale 1ns/1ps
module tb_master_control;
reg clk = 0;
always #5 clk = ~clk;
reg reset = 1, vblank = 1, key = 0;
wire master_reset;
videobrain_reset dut (clk, reset, vblank, key, master_reset);

task field_edge(input expected);
    vblank = 1;
    repeat (3) @(negedge clk);
    vblank = 0;
    repeat (3) @(negedge clk);
    if (master_reset !== expected) $fatal(1, "Master Control pulse mismatch");
endtask

initial begin
    repeat (3) @(negedge clk);
    reset = 0;
    field_edge(0);
    key = 1;
    repeat (5) @(negedge clk);
    if (master_reset !== 0) $fatal(1, "Key bypassed field sampling");
    field_edge(1);
    repeat (20) @(negedge clk);
    if (master_reset !== 1) $fatal(1, "Reset did not last a field");
    field_edge(0);
    repeat (4) field_edge(0);
    key = 0;
    field_edge(0);
    field_edge(0);
    key = 1;
    field_edge(1);
    key = 0;
    if (master_reset !== 1) $fatal(1, "Release shortened reset pulse");
    field_edge(0);
    field_edge(0);
    key = 1;
    field_edge(1);
    reset = 1;
    repeat (3) @(negedge clk);
    if (master_reset !== 0) $fatal(1, "System reset did not clear pulse");
    $display("Master Control field sampling and one pulse per press passed");
    $finish;
end
endmodule
