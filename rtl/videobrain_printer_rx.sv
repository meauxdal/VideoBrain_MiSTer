`timescale 1ns/1ps
module videobrain_printer_rx #(
    parameter CLOCK_HZ = 14318180
)(
    input wire clk,
    input wire abort_frame,
    input wire enable,
    input wire baud110,
    input wire serial_in,
    output reg [7:0] data = 0,
    output reg valid = 0,
    output reg framing = 0,
    output reg rejected = 0,
    output wire busy,
    output wire idle_ready
);
localparam DIV300 = (CLOCK_HZ + 2400) / 4800;
localparam DIV110 = (CLOCK_HZ + 880) / 1760;
reg [23:0] divider = 0;
reg [5:0] idle_ticks = 0;
reg [3:0] phase = 0, bit_index = 0;
reg [1:0] votes = 0;
reg receiving = 0, pin = 1, previous = 1;
reg [7:0] shift = 0;
wire [23:0] divisor = baud110 ? 24'(DIV110) : 24'(DIV300);
wire majority = votes >= 2;
assign busy = receiving;
assign idle_ready = idle_ticks == 32;

always @(posedge clk) begin
    pin <= serial_in;
    previous <= pin;
    valid <= 0;
    framing <= 0;
    rejected <= 0;
    if (!pin || abort_frame) idle_ticks <= 0;
    if (divider != 0) divider <= divider - 1'b1;
    else begin
        divider <= divisor - 1'b1;
        if (pin && idle_ticks != 32) idle_ticks <= idle_ticks + 1'b1;
        if (receiving) begin
            phase <= phase + 1'b1;
            if (phase == 6) votes <= {1'b0, pin};
            if (phase == 7 || phase == 8) votes <= votes + {1'b0, pin};
            if (phase == 9) begin
                if (bit_index == 0) begin
                    if (majority) begin
                        rejected <= 1;
                        receiving <= 0;
                    end
                end else if (bit_index <= 8) shift[3'(bit_index - 1'b1)] <= majority;
                else begin
                    receiving <= 0;
                    if (majority) begin data <= shift; valid <= 1; end
                    else framing <= 1;
                end
            end
            if (phase == 15) bit_index <= bit_index + 1'b1;
        end
    end
    // A stop request inhibits new starts but lets an accepted frame finish.
    if (!receiving && enable && previous && !pin) begin
        receiving <= 1;
        divider <= divisor - 1'b1;
        phase <= 0;
        bit_index <= 0;
    end
    if (abort_frame) begin
        receiving <= 0;
        valid <= 0;
        framing <= 0;
    end
end
endmodule
