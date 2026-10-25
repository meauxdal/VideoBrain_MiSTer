`timescale 1ns/1ps
module tb_printer_infoman;
reg clk=0;
always #34.920639 clk=~clk;
reg reset_na=0, host_data_n=1, host_clock_n=1;
wire data_n, clock_n, interrupt_n, printer_txd, modem_txd;
reg modem_rxd=1;
reg apple=0,trace_serial=0,trace_transfer=0;
reg [15:0] dl_addr=0;
reg [7:0] dl_data=0;
reg dl_wr=0;
reg [35:0] keys=0;
wire [15:0] pc;
wire symbols;
wire record_data,record_enable,playback_enable,playback_data;
wire [1:0] tape_busy,tape_error;
reg [1:0] tape_mount=0,tape_rewind=0;
wire [31:0] tape_lba[2];
wire [1:0] tape_rd,tape_wr;
wire [7:0] tape_din[2];
videobrain_core core(.clk(clk),.reset_na(reset_na),.progressive(1'b1),
    .kbd_matrix(keys),.joy_fire(4'd0),.joy_pots(64'h8080808080808080),
    .joy_connected(1'b1),.joy_timer_base(14'd2580),.joy_timer_step(7'd7),
    .joy_timer_curve(1'b0),.joy_timer_auto(1'b0),
    .expander_record_data(record_data),.expander_record_enable(record_enable),.expander_playback_enable(playback_enable),
    .expander_playback_data(playback_data),.expander_modem_rxd(modem_rxd),
    .expander_modem_txd(modem_txd),.expander_printer_txd(printer_txd),
    .dl_addr(dl_addr),.dl_data(dl_data),.dl_wr(dl_wr),.dl_index(download_index),
    .cart_unload(1'b0),.unknown_cart_profile(8'd0),.pc0(pc),.apl_symbols(symbols));
reg [7:0] download_index=8'hff;
wire [31:0] lbas[3];
wire [2:0] reads,writes,acks;
wire [8:0] addr;
wire [7:0] dout,dins[3];
wire wr,busy,active,stalled;
wire [3:0] error,status_code;
reg mounted=0,start=0,stop=0,baud110=0;
assign lbas[0]=tape_lba[0];assign lbas[1]=tape_lba[1];
assign reads[1:0]=tape_rd;assign writes[1:0]=tape_wr;
assign dins[0]=tape_din[0];assign dins[1]=tape_din[1];
videobrain_tapes tapes(.clk(clk),.reset(!reset_na),.img_mounted(tape_mount),
    .img_readonly(1'b0),.img_size(apple ? 64'd8388608 : 64'd131072),.rewind(tape_rewind),
    .record_data(record_data),.record_enable(record_enable),.playback_enable(playback_enable),
    .playback_data(playback_data),.busy(tape_busy),.error(tape_error),
    .sd_lba(tape_lba),.sd_rd(tape_rd),.sd_wr(tape_wr),.sd_ack(acks[1:0]),
    .sd_buff_addr(addr),.sd_buff_dout(dout),.sd_buff_din(tape_din),.sd_buff_wr(wr));
videobrain_printer_capture capture(.clk(clk),.reset(!reset_na),.serial_in(printer_txd),
    .baud110(baud110),.start(start),.stop(stop),.img_mounted(mounted),
    .img_readonly(1'b0),.img_size(64'd32768),.busy(busy),.active(active),
    .stalled(stalled),.error(error),.status_code(status_code),
    .sd_lba(lbas[2]),.sd_rd(reads[2]),.sd_wr(writes[2]),.sd_ack(acks[2]),
    .sd_buff_addr(addr),.sd_buff_dout(dout),.sd_buff_din(dins[2]),.sd_buff_wr(wr));
printer_hps_model #(.BYTES(131072)) card(.clk(clk),.sd_lba(lbas),.sd_rd(reads),.sd_wr(writes),
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
function automatic [35:0] character_key(input byte c);
    integer k;
    begin
        case(c)
            "I":k=0;"O":k=1;"P":k=2;"U":k=4;"K":k=5;"L":k=6;
            "Y":k=8;"J":k=9;"M":k=10;"T":k=12;"H":k=13;"N":k=14;
            "R":k=16;"G":k=17;"B":k=18;"E":k=20;"F":k=21;"V":k=22;
            "W":k=24;"D":k=25;"C":k=26;"Q":k=28;"S":k=29;"X":k=30;
            "A":k=32;"Z":k=33;" ":k=19;"=":k=18;
            default:k=35;
        endcase
        character_key=36'd1<<k;

    end
endfunction

reg command_ready=0;
always @(posedge clk) if(pc>=16'h1228 && pc<=16'h1236) command_ready<=1;

task command(input string text);
    // 1228 enters prompt setup; 3453 is the ready keyboard-input loop.
    wait(pc>=16'h3453 && pc<=16'h3455);
    command_ready=0;
    for(integer j=0;j<text.len();j=j+1) begin
        if(text[j]!=" " && symbols!=(text[j]=="=")) keypress(36'd1<<11);
        keypress(character_key(text[j]));
    end
    for(integer j=0;j<text.len();j=j+1) begin
        if(core.u_sys_bus.sys_ram[j+1]>=8'h3b ||
           core.u_sys_bus.cart_rom[16'h1782+core.u_sys_bus.sys_ram[j+1]]!==text[j])
            $fatal(1,"Command %s character %0d was not entered: glyph %02h",
                   text,j,core.u_sys_bus.sys_ram[j+1]);
    end
    if(trace_serial) begin
        $write("Infoman input %s glyphs:",text);
        for(integer j=0;j<16;j=j+1) $write(" %02h",core.u_sys_bus.sys_ram[j]);
        $display(" symbols %b",symbols);$fflush();
    end
    keypress(36'd1<<27);
    $display("Infoman command %s pc %h tape busy %b error %b",text,pc,tape_busy,tape_error);$fflush();
endtask
integer reference_fd=0,byte_count=0;
reg [7:0] value;
reg last_pin=1;
integer idle_ticks=0,edge_count=0;
longint unsigned cycles=0,last_edge=0;
reg [15:0] last_pc=0;
integer milestones=0;
always @(posedge clk) begin
    last_pc<=pc;
    if(trace_serial && reference_fd!=0 && pc!=last_pc && milestones<64 &&
       (pc==16'h1411 || pc==16'h1422 || pc==16'h16b0 || pc==16'h3716 || pc==16'h3e2d)) begin
        $display("Infoman path pc %h mode %02h printer %02h operation %02h",
                 pc,core.u_sys_bus.cart_ram[16'h30b],core.u_sys_bus.cart_ram[16'h31a],
                 core.u_sys_bus.cart_ram[16'h30f]);$fflush();
        milestones<=milestones+1;
    end
    cycles<=cycles+1;
    if(printer_txd!=last_pin) begin
        if(trace_serial && reference_fd!=0 && edge_count<64) begin
            $display("Printer edge %0d cycle %0d gap %0d level %b pc %h capture %0d error %0d",
                     edge_count,cycles,cycles-last_edge,printer_txd,pc,status_code,error);$fflush();
            edge_count<=edge_count+1;
        end
        last_edge<=cycles;
    end
    last_pin<=printer_txd;
    if(printer_txd!=last_pin) idle_ticks<=0;
    else if(idle_ticks<40000000) idle_ticks<=idle_ticks+1;
end
integer transfer_fd=0,transfer_rows=0;
reg transfer_started=0;
reg host_wr_d=0,expander_wr_d=0,expander_irq_d=1,host_ack_d=0;
always @(posedge clk) begin
    host_wr_d<=core.io_wr;
    expander_wr_d<=core.u_expander1.io_wr;
    expander_irq_d<=core.expander_interrupt_n;
    host_ack_d<=core.u_smi.int_ack;
    if(transfer_fd!=0 && pc==16'h3716) transfer_started<=1;
    if(transfer_fd!=0 && transfer_started && transfer_rows<4096 &&
       ((core.io_wr && !host_wr_d) || (core.u_expander1.io_wr && !expander_wr_d) ||
        core.expander_interrupt_n!=expander_irq_d || printer_txd!=last_pin ||
        (core.u_smi.int_ack && !host_ack_d) ||
        (pc!=last_pc && (pc==16'h3e17 || pc==16'h3e76 || pc==16'h3eb5 ||
                        pc==16'h3ee6 || pc==16'h3f1f || pc==16'h3b19)))) begin
        $fwrite(transfer_fd,"%0d,%04h,%04h,%b,%02h,%02h,%b,%02h,%02h,%b,%b,%b,%04h,%04h,%02h,%02h,%02h,%02h,%02h,%02h\n",
                cycles,pc,core.u_expander1.addr,core.io_wr,core.io_addr,core.io_wdata,
                core.u_expander1.io_wr,core.u_expander1.io_addr,core.u_expander1.io_wdata,
                core.expander_interrupt_n,printer_txd,core.u_smi.int_ack,core.int_vector,
                {core.u_cpu.scratch_regs[14],core.u_cpu.scratch_regs[15]},
                core.u_cpu.scratch_regs[0],core.u_cpu.scratch_regs[31],
                core.u_expander1.u_cpu.scratch_regs[2],core.u_expander1.u_cpu.scratch_regs[3],
                core.u_expander1.u_cpu.scratch_regs[18],core.u_expander1.u_cpu.scratch_regs[22]);
        transfer_rows<=transfer_rows+1;
    end
end
initial forever begin
    @(negedge printer_txd);
    if(reference_fd!=0) begin
        repeat(47727+47727/2) @(posedge clk);
        for(integer j=0;j<8;j=j+1) begin
            value[j]=printer_txd;repeat(47727) @(posedge clk);
        end
        if(!printer_txd) begin
            $display("Report reference bad stop pc %h byte %h capture %0d error %0d",
                     pc,value,status_code,error);$fflush();
            if(trace_transfer) begin
                #500ms;
                $fclose(transfer_fd);transfer_fd=0;
            end
            $fatal(1,"Report reference bad stop");
        end
        byte_count=byte_count+1;
        $fwrite(reference_fd,"%c",value);
    end
end

task report(input string text,input string label);
    integer before_count,file_id;
    before_count=byte_count;
    reference_fd=$fopen({"out/expander1/",label,".bin"},"wb");
    if(trace_transfer) begin
        transfer_started=0;transfer_rows=0;
        transfer_fd=$fopen({"out/expander1/",label,"-transfer.csv"},"w");
        $fwrite(transfer_fd,"cycle,host_pc,expander_addr,host_wr,host_port,host_value,expander_wr,expander_port,expander_value,irq_n,printer_tx,host_ack,host_vector,host_q,host_r0,host_r31,expander_r2,expander_r3,route,reload\n");
    end
    @(negedge clk);start=1;@(negedge clk);start=0;wait(active);
    command(text);
    wait(byte_count>before_count);
    wait(command_ready && idle_ticks>=28636360 && tape_busy==0);
    @(negedge clk);stop=1;@(negedge clk);stop=0;wait(!busy);
    $fclose(reference_fd);reference_fd=0;
    if(transfer_fd!=0) begin $fclose(transfer_fd);transfer_fd=0;end
    if(error!=0 || tape_error!=0) $fatal(1,"Report/cassette error %d/%b pc %h",error,tape_error,pc);
    file_id=$fopen({"out/expander1/",label,".vbp"},"wb");
    for(integer j=0;j<32768;j=j+1) $fwrite(file_id,"%c",card.media[2][j]);
    $fclose(file_id);
    $display("Infoman %s: %0d printer bytes pc %h",label,byte_count-before_count,pc);$fflush();
endtask
string bios1,bios2,firmware,cartridge,fixture;
integer fd,amount;
reg [7:0] tape_bytes[131072];
initial begin
    apple=$test$plusargs("apple");
    trace_serial=$test$plusargs("trace_serial");
    trace_transfer=$test$plusargs("trace_transfer");
    if(!$value$plusargs("bios1=%s",bios1) || !$value$plusargs("bios2=%s",bios2) ||
       !$value$plusargs("firmware=%s",firmware) || !$value$plusargs("cart=%s",cartridge) ||
       !$value$plusargs("fixture=%s",fixture)) $fatal(1,"Supply original ROMs and fixture");
    load_image(bios1,0);load_image(bios2,1);load_image(firmware,3);load_image(cartridge,2);
    blank();
    fd=$fopen(fixture,"rb");amount=$fread(tape_bytes,fd);$fclose(fd);
    if(amount!=131072) $fatal(1,"Bad tape fixture");
    for(integer j=0;j<131072;j=j+1) card.media[0][j]=tape_bytes[j];
    card.media[1][0]='h56;card.media[1][1]='h42;card.media[1][2]='h54;card.media[1][3]='h31;
    {card.media[1][7],card.media[1][6],card.media[1][5],card.media[1][4]}=14318180;
    reset_na=1;
    @(negedge clk);tape_mount=apple ? 1:3;@(negedge clk);tape_mount=0;wait(tape_busy==0);
    repeat(50000000) @(negedge clk);
    command("R");
    wait(command_ready);
    repeat(1000000) @(negedge clk);
    if(core.u_sys_bus.cart_ram[16'h0e9] != (apple ? 8'h11:8'h01))
        $fatal(1,"Fixture definition was not loaded");
    $display("Infoman REVIEW ready pc %h",pc);$fflush();
    if(apple) begin
        report("P DESC PTR","printer-infoman-apple-desc");
        $display("Information Manager APPLE PTR report/tape path passed");
        $finish;
    end
    report("P DESC PTR","printer-infoman-desc");
    command("TOT=ITEM");wait(command_ready);repeat(1000000) @(negedge clk);
    report("P ALL PTR","printer-infoman-records");
    report("TOTAL PTR","printer-infoman-total");
    $display("Information Manager original-ROM PTR report/tape path passed");
    $finish;
end
initial begin
    repeat(8) begin
        #10s;
        $display("Infoman progress pc %h bytes %0d cassette %b/%b input %b capture %0d",pc,byte_count,tape_busy,tape_error,command_ready,status_code);$fflush();
    end
end
initial begin #90s;$fatal(1,"Information Manager timeout pc %h bytes %0d tape %b/%b",pc,byte_count,tape_busy,tape_error);end
endmodule
