`timescale 1ns/1ps
module tb_printer_rom;
reg clk=0;
always #34.920639 clk=~clk;
reg reset_na=0, host_data_n=1, host_clock_n=1;
wire data_n, clock_n, interrupt_n, printer_txd, modem_txd;
reg modem_rxd=1;
reg [15:0] dl_addr=0;
reg [7:0] dl_data=0;
reg dl_wr=0;
expander1 expander(.*,.record_data(),.record_enable(),.playback_enable(),
    .playback_data(1'b1),.printer_rxd(1'b1),.dl_index(8'd3));
wire [31:0] lbas[3];
wire [2:0] reads,writes,acks;
wire [8:0] addr;
wire [7:0] dout,dins[3];
wire wr,busy,active,stalled;
wire [3:0] error,status_code;
reg mounted=0,start=0,stop=0,baud110=0;
assign lbas[0]=0;assign lbas[1]=0;
assign reads[1:0]=0;assign writes[1:0]=0;
assign dins[0]=0;assign dins[1]=0;
videobrain_printer_capture capture(.clk(clk),.reset(!reset_na),.serial_in(printer_txd),
    .baud110(baud110),.start(start),.stop(stop),.img_mounted(mounted),
    .img_readonly(1'b0),.img_size(64'd32768),.busy(busy),.active(active),
    .stalled(stalled),.error(error),.status_code(status_code),
    .sd_lba(lbas[2]),.sd_rd(reads[2]),.sd_wr(writes[2]),.sd_ack(acks[2]),
    .sd_buff_addr(addr),.sd_buff_dout(dout),.sd_buff_din(dins[2]),.sd_buff_wr(wr));
printer_hps_model card(.clk(clk),.sd_lba(lbas),.sd_rd(reads),.sd_wr(writes),
    .sd_ack(acks),.sd_buff_addr(addr),.sd_buff_dout(dout),.sd_buff_din(dins),.sd_buff_wr(wr));
function automatic [31:0] crc_byte(input [31:0] c,input [7:0] b);
    reg [31:0] n;
    begin
        n=c^{24'd0,b};
        for(integer j=0;j<8;j=j+1) n=n[0] ? (n>>1)^32'hedb88320 : n>>1;
        crc_byte=n;
    end
endfunction
reg [31:0] crc;
task blank;
    for(integer j=0;j<32768;j=j+1) card.media[2][j]=0;
    {card.media[2][3],card.media[2][2],card.media[2][1],card.media[2][0]}=32'h31504256;
    card.media[2][4]=1;card.media[2][9]=2;card.media[2][12]=32;card.media[2][16]=64;
    crc=32'hffffffff;
    for(integer j=0;j<512;j=j+1) crc=crc_byte(crc,card.media[2][j]);
    for(integer j=0;j<4;j=j+1) card.media[2][28+j]=~crc[j*8 +:8];
    @(negedge clk);mounted=1;@(negedge clk);mounted=0;@(negedge clk);wait(!busy);
endtask
task transfer(input [7:0] v);
    for(integer i=7;i>=0;i=i-1) begin
        @(negedge interrupt_n);host_data_n=!v[i];host_clock_n=1;
        @(posedge interrupt_n);
    end
endtask
task serial_bit(input bit value);
    @(negedge interrupt_n);host_data_n=!value;
endtask
task host_byte(input [7:0] value);
    serial_bit(0);
    for(integer i=0;i<8;i=i+1) serial_bit(value[i]);
    serial_bit(1);serial_bit(1);
endtask
reg [7:0] firmware[2048];
string path;
integer fd,size,bit_ticks,modem_count;
reg [7:0] expected[6]='{'h00,'h20,'ha5,'h0d,'h0a,'hff};
reg monitor_modem=0;
initial forever begin
    @(negedge modem_txd);
    if(monitor_modem) begin
        repeat(bit_ticks+bit_ticks/2) @(posedge clk);
        for(integer i=0;i<8;i=i+1) begin
            if(modem_txd !== (8'ha5 >> i & 1)) $fatal(1,"Capture changed modem TX");
            repeat(bit_ticks) @(posedge clk);
        end
        if(!modem_txd) $fatal(1,"Bad modem stop");
        modem_count=modem_count+1;
    end
end
initial begin
    if(!$value$plusargs("firmware=%s",path)) $fatal(1,"Supply firmware");
    fd=$fopen(path,"rb");size=$fread(firmware,fd);$fclose(fd);
    if(size!=2048) $fatal(1,"Bad firmware image");
    for(integer j=0;j<2048;j=j+1) begin
        @(negedge clk);dl_addr=16'(j);dl_data=firmware[j];dl_wr=1;
    end
    @(negedge clk);dl_wr=0;
    for(integer rate=0;rate<2;rate=rate+1) begin
        baud110=1'(rate);bit_ticks=rate ? 130165 : 47727;
        for(integer route=0;route<2;route=route+1) begin
            reset_na=0;host_data_n=1;host_clock_n=1;#1000;reset_na=1;
            blank();#100000;
            host_clock_n=0;transfer(4);transfer(rate ? 1:2);transfer(route ? 'h0d:2);
            #2000000; // Preserve the final command-bit hold.
            host_data_n=0;
            @(negedge clk);start=1;@(negedge clk);start=0;wait(active);
            $display("ROM capture armed rate %0d route %0d",rate,route);$fflush();
            if(route==0) begin
                for(integer j=0;j<6;j=j+1) host_byte(expected[j]);
            end else begin
                modem_count=0;monitor_modem=1;
                fork
                    host_byte('ha5);
                    begin
                        repeat(2000) @(negedge clk);
                        modem_rxd=0;repeat(bit_ticks) @(negedge clk);
                        for(integer i=0;i<8;i=i+1) begin
                            modem_rxd=1'('h3c >> i);repeat(bit_ticks) @(negedge clk);
                        end
                        modem_rxd=1;repeat(bit_ticks*2) @(negedge clk);
                    end
                join
                repeat(bit_ticks*4) @(negedge clk);
                monitor_modem=0;
                if(modem_count!=1) $fatal(1,"Missing modem host transmission");
            end
            repeat(bit_ticks*4) @(negedge clk);
            @(negedge clk);stop=1;@(negedge clk);stop=0;wait(!busy);
            if(error!=0) $fatal(1,"ROM capture error %d",error);
            fd=$fopen($sformatf("out/expander1/printer-rom-%0d-%0d.vbp",rate,route),"wb");
            for(integer j=0;j<32768;j=j+1) $fwrite(fd,"%c",card.media[2][j]);
            $fclose(fd);
        end
    end
    $display("Original Expander ROM printer-only and simultaneous modem capture at 110/300 passed");
    $finish;
end
initial begin #10s;$fatal(1,"Original ROM capture timeout state %d error %d irq %b",capture.state,error,interrupt_n);end
endmodule
