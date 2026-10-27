`timescale 1ns/1ps
module tb_printer_cartridge;
reg clk=0;
always #34.920639 clk=~clk;
reg reset_na=0, host_data_n=1, host_clock_n=1;
wire data_n, clock_n, interrupt_n, printer_txd, modem_txd;
reg modem_rxd=1;
reg [15:0] dl_addr=0;
reg [7:0] dl_data=0;
reg dl_wr=0;
reg [35:0] keys=0;
wire [15:0] pc;
videobrain_core core(.clk(clk),.reset_na(reset_na),.power_cycle(1'b0), .timing_reset_na(1'b0), .progressive(1'b1),
    .kbd_matrix(keys),.joy_fire(4'd0),.joy_pots(64'h8080808080808080),
    .joy_connected(1'b1),.joy_timer_base(14'd2580),.joy_timer_step(7'd7),
    .joy_timer_curve(1'b0),.joy_timer_auto(1'b0),
    .expander_record_data(),.expander_record_enable(),.expander_playback_enable(),
    .expander_playback_data(1'b1),.expander_modem_rxd(modem_rxd),
    .expander_modem_txd(modem_txd),.expander_printer_txd(printer_txd),
    .dl_addr(dl_addr),.dl_data(dl_data),.dl_wr(dl_wr),.dl_index(download_index),
    .cart_unload(1'b0),.unknown_cart_profile(8'd0), .infoman_printer_fix(1'b0),.pc0(pc));
reg [7:0] download_index=8'hff;
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
task load_image(input string filename,input [7:0] index);
    integer file_id,value,address;
    file_id=$fopen(filename,"rb");
    if(file_id==0) $fatal(1,"Cannot open %s",filename);
    download_index=index;address=0;
    value=$fgetc(file_id);
    while(value!=-1) begin
        @(negedge clk);dl_addr=16'(address);dl_data=8'(value);dl_wr=1;
        address=address+1;value=$fgetc(file_id);
    end
    @(negedge clk);dl_wr=0;download_index=8'hff;$fclose(file_id);
endtask

task keypress(input [35:0] mask);
    @(negedge clk);keys=mask;
    repeat(1500000) @(negedge clk);
    keys=0;repeat(1000000) @(negedge clk);
endtask
integer bit_ticks=47727,tx_count=0;
reg [7:0] tx_byte;
reg echo_on=0,monitor=0;
reg [7:0] echo_queue[16];
integer echo_write=0,echo_read=0;
initial forever begin
    @(negedge modem_txd);
    if(monitor) begin
        repeat(bit_ticks+bit_ticks/2) @(posedge clk);
        for(integer i=0;i<8;i=i+1) begin
            tx_byte[i]=modem_txd;
            repeat(bit_ticks) @(posedge clk);
        end
        if(!modem_txd) $fatal(1,"Cartridge modem stop invalid");
        tx_count=tx_count+1;
        $display("Timeshare TX %h echo %b pc %h",tx_byte,echo_on,pc);
        if(echo_on) begin echo_queue[echo_write%16]=tx_byte;echo_write=echo_write+1;end
    end
end

initial forever begin
    @(negedge clk);
    if(echo_read!=echo_write) begin modem_byte(echo_queue[echo_read%16]);echo_read=echo_read+1;end
end

task modem_byte(input [7:0] value);
    @(negedge clk);modem_rxd=0;repeat(bit_ticks) @(negedge clk);
    for(integer i=0;i<8;i=i+1) begin
        modem_rxd=value[i];repeat(bit_ticks) @(negedge clk);
    end
    modem_rxd=1;repeat(bit_ticks*2) @(negedge clk);
endtask
string bios1,bios2,firmware,cartridge;
integer fd;
reg enabled=1;
initial begin
    if(!$value$plusargs("bios1=%s",bios1) || !$value$plusargs("bios2=%s",bios2) ||
       !$value$plusargs("firmware=%s",firmware) || !$value$plusargs("cart=%s",cartridge))
        $fatal(1,"Supply original ROM paths");
    load_image(bios1,0);load_image(bios2,1);load_image(firmware,3);load_image(cartridge,2);
    for(integer rate=0;rate<2;rate=rate+1) begin
        baud110=1'(rate);bit_ticks=rate ? 130165 : 47727;
        for(integer mode=0;mode<4;mode=mode+1) begin
            for(integer capture_on=0;capture_on<2;capture_on=capture_on+1) begin
                monitor=0;reset_na=0;keys=0;repeat(10) @(negedge clk);reset_na=1;
                blank();
                wait(pc>=16'h1082 && pc<=16'h108d);
                repeat(1000000) @(negedge clk);
                if(rate) keypress((36'd1<<23)|(36'd1<<11)|(36'd1<<33));
                if(mode>=2) keypress((36'd1<<23)|(36'd1<<11)|(36'd1<<13));
                tx_count=0;echo_on=mode[0];monitor=1;
                if(capture_on) begin
                    @(negedge clk);start=1;@(negedge clk);start=0;wait(active);
                end
                keypress(36'd1<<32);
                keypress(36'd1<<15);
                repeat(bit_ticks*15) @(negedge clk);
                modem_byte('h58);
                repeat(bit_ticks*15) @(negedge clk);
                monitor=0;
                if(tx_count!=2) $fatal(1,"Timeshare keyboard missing or duplicated (%0d) pc %h",tx_count,pc);
                if(capture_on) begin
                    @(negedge clk);stop=1;@(negedge clk);stop=0;wait(!busy);
                    if(error!=0) $fatal(1,"Timeshare capture failed %d",error);
                    fd=$fopen($sformatf("out/expander1/printer-timeshare-%0d-%0d.vbp",rate,mode),"wb");
                    for(integer j=0;j<32768;j=j+1) $fwrite(fd,"%c",card.media[2][j]);
                    $fclose(fd);
                end
                $display("Timeshare rate %0d mode %0d capture %0d passed",rate,mode,capture_on);
                $fflush();
            end
        end
    end
    $finish;
end
initial begin #60s;$fatal(1,"Timeshare cartridge timeout pc %h",pc);end
endmodule
