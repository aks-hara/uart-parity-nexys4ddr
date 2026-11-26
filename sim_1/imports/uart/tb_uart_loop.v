`timescale 1ns / 1ps
//------------------------------------------------------------------
// tb_uart_loop.v - self-checking testbench: TX looped into RX
// Sends several bytes (some with the parity error injected) and checks
// that the receiver returns the same byte, flags parity errors only
// when injected, and never flags a framing error.
//------------------------------------------------------------------
module tb_uart_loop;
    localparam CLK_FREQ = 100_000_000;
    localparam BAUD     = 9600;

    reg        clk = 0, rst = 1, send = 0, inject = 0;
    reg  [7:0] data = 0;
    wire       tick_tx, tick_rx, txd, busy, par_sent;
    wire [7:0] rx_data;
    wire       rx_done, rx_perr, rx_ferr;

    baud_gen #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD), .OVERSAMPLE(16)) u_baud (
        .clk(clk), .rst(rst), .tick_rx(tick_rx), .tick_tx(tick_tx)
    );

    uart_tx #(.ODD_PARITY(0)) u_tx (
        .clk(clk), .rst(rst), .tick_tx(tick_tx), .send(send), .data(data),
        .inject_error(inject), .txd(txd), .busy(busy), .par_sent(par_sent)
    );

    uart_rx #(.ODD_PARITY(0)) u_rx (
        .clk(clk), .rst(rst), .tick_rx(tick_rx), .rxd(txd),
        .data(rx_data), .done(rx_done),
        .parity_err(rx_perr), .frame_err(rx_ferr)
    );

    always #5 clk = ~clk;                       // 100 MHz

    integer   errors = 0;
    integer   rx_count = 0;
    reg [7:0] got;
    reg       got_perr, got_ferr;

    always @(posedge clk) if (rx_done) begin
        rx_count <= rx_count + 1;
        got      <= rx_data;
        got_perr <= rx_perr;
        got_ferr <= rx_ferr;
    end

    task run_test(input [7:0] b, input inj);
        integer n0;
        begin
            n0 = rx_count;
            @(posedge clk); data <= b; inject <= inj; send <= 1'b1;
            @(posedge clk); send <= 1'b0;
            wait (rx_count != n0);               // wait for the receiver
            if (got !== b)        begin errors = errors + 1; $display("ERR: got %h expected %h", got, b); end
            if (got_perr !== inj) begin errors = errors + 1; $display("ERR: parity_err=%b expected %b", got_perr, inj); end
            if (got_ferr !== 1'b0) begin errors = errors + 1; $display("ERR: frame_err set"); end
            $display("sent %h (inject=%b) -> got %h parity_err=%b frame_err=%b",
                     b, inj, got, got_perr, got_ferr);
            wait (!busy);                        // transmitter idle again
            #5000;
        end
    endtask

    initial begin
        #100 rst = 0;
        #1000;
        run_test(8'h41, 0);
        run_test(8'h43, 0);
        run_test(8'h00, 0);
        run_test(8'hFF, 0);
        run_test(8'hA5, 0);
        run_test(8'h41, 1);       // parity error injected
        run_test(8'h43, 1);       // parity error injected
        run_test(8'h41, 0);       // error flag must clear again
        if (errors == 0) $display("PASS: TX -> RX loopback correct");
        else             $display("FAIL: %0d error(s)", errors);
        $finish;
    end

    initial begin                                // watchdog
        #40_000_000;
        $display("FAIL: timeout (receiver never finished)");
        $finish;
    end
endmodule
