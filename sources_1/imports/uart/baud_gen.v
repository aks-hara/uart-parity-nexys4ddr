`timescale 1ns / 1ps
//------------------------------------------------------------------
// baud_gen.v - baud rate generator for UART (Nexys 4 DDR, 100 MHz)
//
// tick_rx : 1-clock pulse at BAUD * OVERSAMPLE  (6510 ns apart @ 9600)
// tick_tx : 1-clock pulse at BAUD               (104.16 us apart @ 9600)
//
// tick_tx is derived from the same counter as tick_rx, so there are
// always exactly OVERSAMPLE rx ticks per tx tick (no drift).
// Ticks are ENABLES, not clocks: use  "if (tick) ..."  in your FSMs.
//------------------------------------------------------------------
module baud_gen #(
    parameter CLK_FREQ   = 100_000_000,
    parameter BAUD       = 9600,
    parameter OVERSAMPLE = 16
)(
    input  wire clk,
    input  wire rst,        // active-high, synchronous
    output reg  tick_rx,
    output reg  tick_tx
);
    localparam DIV = CLK_FREQ / (BAUD * OVERSAMPLE);   // 651 for 9600

    reg [$clog2(DIV)-1:0]        cnt;
    reg [$clog2(OVERSAMPLE)-1:0] os_cnt;

    always @(posedge clk) begin
        if (rst) begin
            cnt     <= 0;
            os_cnt  <= 0;
            tick_rx <= 1'b0;
            tick_tx <= 1'b0;
        end else begin
            tick_rx <= 1'b0;             // default: pulses last 1 clock
            tick_tx <= 1'b0;
            if (cnt == DIV - 1) begin
                cnt     <= 0;
                tick_rx <= 1'b1;
                if (os_cnt == OVERSAMPLE - 1) begin
                    os_cnt  <= 0;
                    tick_tx <= 1'b1;
                end else begin
                    os_cnt <= os_cnt + 1'b1;
                end
            end else begin
                cnt <= cnt + 1'b1;
            end
        end
    end
endmodule
