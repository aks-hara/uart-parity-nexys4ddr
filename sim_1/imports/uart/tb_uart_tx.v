`timescale 1ns / 1ps
//------------------------------------------------------------------
// tb_uart_tx.v - self-checking testbench for baud_gen + uart_tx
// A behavioural receiver samples the frame at mid-bit and checks:
// start=0, data bits (LSB first), parity bit, stop=1.
// Sends 0x41, 0x43, then 0x41 with the parity error injected.
//------------------------------------------------------------------
module tb_uart_tx;
    localparam CLK_FREQ = 100_000_000;
    localparam BAUD     = 9600;
    localparam BIT_NS   = (CLK_FREQ / (BAUD * 16)) * 16 * 10;   // 104160

    reg        clk = 0, rst = 1, send = 0, inject = 0;
    reg  [7:0] data = 0;
    wire       tick_tx, txd, busy;

    baud_gen #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD), .OVERSAMPLE(16)) u_baud (
        .clk(clk), .rst(rst), .tick_rx(), .tick_tx(tick_tx)
    );

    uart_tx #(.ODD_PARITY(0)) uut (
        .clk(clk), .rst(rst), .tick_tx(tick_tx), .send(send),
        .data(data), .inject_error(inject), .txd(txd), .busy(busy)
    );

    always #5 clk = ~clk;                       // 100 MHz

    integer errors = 0;
    integer i;
    reg [7:0] rx_byte;
    reg       rx_par, rx_stop;

    task send_byte(input [7:0] b, input inj);
        begin
            @(posedge clk); data <= b; inject <= inj; send <= 1'b1;
            @(posedge clk); send <= 1'b0;
        end
    endtask

    task check_frame(input [7:0] exp, input inj);
        reg exp_par;
        begin
            @(negedge txd);                     // start bit begins
            #(BIT_NS / 2);                      // middle of start bit
            if (txd !== 1'b0) begin errors = errors + 1; $display("ERR: start bit not 0"); end
            for (i = 0; i < 8; i = i + 1) begin
                #(BIT_NS); rx_byte[i] = txd;    // LSB first
            end
            #(BIT_NS); rx_par  = txd;
            #(BIT_NS); rx_stop = txd;
            exp_par = (^exp) ^ inj;
            if (rx_byte !== exp)     begin errors = errors + 1; $display("ERR: data %h expected %h", rx_byte, exp); end
            if (rx_par  !== exp_par) begin errors = errors + 1; $display("ERR: parity %b expected %b", rx_par, exp_par); end
            if (rx_stop !== 1'b1)    begin errors = errors + 1; $display("ERR: stop bit not 1"); end
            $display("frame: data=%h parity=%b stop=%b (inject=%b)", rx_byte, rx_par, rx_stop, inj);
        end
    endtask

    initial begin
        #100 rst = 0;
        #1000;
        send_byte(8'h41, 0); check_frame(8'h41, 0);   // two 1s -> parity 0
        wait (!busy); #2000;
        send_byte(8'h43, 0); check_frame(8'h43, 0);   // three 1s -> parity 1
        wait (!busy); #2000;
        send_byte(8'h41, 1); check_frame(8'h41, 1);   // injected: parity 1
        wait (!busy); #2000;
        if (errors == 0) $display("PASS: all frames correct");
        else             $display("FAIL: %0d error(s)", errors);
        $finish;
    end
endmodule
