`timescale 1ns/1ps
module tb_printer_uart;
reg [127:0] settings = 0;
reg modem_tx = 1, printer_tx = 1, uart_rx = 1;
wire uart_tx;
emu dut(.UART_RXD(uart_rx), .UART_TXD(uart_tx));
initial begin
    force dut.status = settings;
    force dut.expander_modem_txd = modem_tx;
    force dut.expander_printer_txd = printer_tx;
    #1;
    // Distinct connector patterns, both UART sources and receive isolation.
    for (integer source = 0; source < 2; source = source + 1) begin
        settings[32] = source[0];
        for (integer bits = 0; bits < 8; bits = bits + 1) begin
            {modem_tx, printer_tx, uart_rx} = bits[2:0];
            #1;
            if (uart_tx !== (source ? printer_tx : modem_tx))
                $fatal(1,"Wrong UART transmit source");
            if (dut.expander_modem_rxd !== (source ? 1'b1 : uart_rx))
                $fatal(1,"Wrong modem receive routing");
        end
    end
    settings[32] = 0;
    #1;
    if (uart_tx !== modem_tx || dut.expander_modem_rxd !== uart_rx)
        $fatal(1,"Modem did not reconnect");
    $display("Printer UART selection and modem isolation passed");
    $finish;
end
endmodule
