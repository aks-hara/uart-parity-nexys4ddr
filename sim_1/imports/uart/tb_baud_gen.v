`timescale 1ns / 1ps
//------------------------------------------------------------------
// tb_baud_gen.v - self-checking testbench for baud_gen
// Checks: tick spacing, 1-clock pulse width, 16 rx ticks per tx tick
// Run for at least 1.5 ms (set Vivado sim runtime or let $finish end it)
//------------------------------------------------------------------
module tb_baud_gen;
    localparam CLK_FREQ   = 100_000_000;
    localparam BAUD       = 9600;
    localparam OVERSAMPLE = 16;
    localparam DIV        = CLK_FREQ / (BAUD * OVERSAMPLE);   // 651
    localparam EXP_RX_NS  = DIV * 10;                         // 6510
    localparam EXP_TX_NS  = DIV * OVERSAMPLE * 10;            // 104160

    reg  clk = 0, rst = 1;
    wire tick_rx, tick_tx;

    baud_gen #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD), .OVERSAMPLE(OVERSAMPLE))
        uut (.clk(clk), .rst(rst), .tick_rx(tick_rx), .tick_tx(tick_tx));

    always #5 clk = ~clk;                 // 100 MHz

    integer rx_count = 0, tx_count = 0, errors = 0;
    time    t_rx = 0, t_tx = 0;
    reg     prev_rx = 0, prev_tx = 0;

    always @(posedge clk) if (!rst) begin
        // pulse must be exactly 1 clock wide
        if (tick_rx && prev_rx) begin errors = errors + 1; $display("ERR: tick_rx wider than 1 clk @%0t", $time); end
        if (tick_tx && prev_tx) begin errors = errors + 1; $display("ERR: tick_tx wider than 1 clk @%0t", $time); end
        prev_rx <= tick_rx;
        prev_tx <= tick_tx;

        if (tick_rx && !prev_rx) begin
            if (t_rx != 0 && ($time - t_rx) != EXP_RX_NS) begin
                errors = errors + 1;
                $display("ERR: rx spacing %0t ns (expected %0d)", $time - t_rx, EXP_RX_NS);
            end
            t_rx = $time;
            rx_count = rx_count + 1;
        end
        if (tick_tx && !prev_tx) begin
            if (t_tx != 0 && ($time - t_tx) != EXP_TX_NS) begin
                errors = errors + 1;
                $display("ERR: tx spacing %0t ns (expected %0d)", $time - t_tx, EXP_TX_NS);
            end
            t_tx = $time;
            tx_count = tx_count + 1;
        end
    end

    initial begin
        #100 rst = 0;
        #1_500_000;                       // ~14 tx ticks
        // ratio check (allow +/-1 for where the window ends)
        if (tx_count < 13) begin errors = errors + 1; $display("ERR: too few tx ticks (%0d)", tx_count); end
        if (rx_count < OVERSAMPLE*tx_count || rx_count > OVERSAMPLE*(tx_count+1)) begin
            errors = errors + 1;
            $display("ERR: rx/tx ratio wrong: rx=%0d tx=%0d", rx_count, tx_count);
        end
        if (errors == 0) $display("PASS: tx_ticks=%0d rx_ticks=%0d", tx_count, rx_count);
        else             $display("FAIL: %0d error(s)", errors);
        $finish;
    end
endmodule
