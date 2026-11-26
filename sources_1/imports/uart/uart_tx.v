`timescale 1ns / 1ps
//------------------------------------------------------------------
// uart_tx.v - UART transmitter: 1 start, 8 data (LSB first),
//             1 parity, 1 stop.  One state change per tick_tx.
// send         : 1-clock pulse, latches data (ignored while busy)
// inject_error : sampled at send; inverts the parity bit on the wire
//------------------------------------------------------------------
module uart_tx #(
    parameter ODD_PARITY = 0
)(
    input  wire       clk,
    input  wire       rst,           // active-high, synchronous
    input  wire       tick_tx,       // 1 pulse per bit time
    input  wire       send,
    input  wire [7:0] data,
    input  wire       inject_error,
    output reg        txd,
    output reg        busy,
    output wire       par_sent       // parity bit of the current/last frame (after injection)
);
    localparam S_IDLE   = 3'd0,
               S_START  = 3'd1,   // waits for tick, then drives start bit
               S_DATA   = 3'd2,   // each tick drives next data bit
               S_PARITY = 3'd3,   // next tick drives parity bit
               S_STOP   = 3'd4,   // next tick drives stop bit
               S_DONE   = 3'd5;   // stop bit lasts one full tick, then idle

    reg [2:0] state;
    reg [7:0] tsr;                // transmit shift register
    reg       par;                // parity bit to send
    reg [2:0] idx;                // data bit counter

    assign par_sent = par;       // holds its value until the next send

    wire par_calc;
    parity_gen #(.ODD_PARITY(ODD_PARITY)) u_pg (
        .data_in(data), .parity_bit(par_calc)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            txd   <= 1'b1;        // line idles high, also during reset
            busy  <= 1'b0;
            tsr   <= 8'd0;
            par   <= 1'b0;
            idx   <= 3'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    txd <= 1'b1;
                    if (send) begin
                        tsr   <= data;
                        par   <= par_calc ^ inject_error;
                        busy  <= 1'b1;
                        state <= S_START;
                    end
                end
                S_START: if (tick_tx) begin
                    txd   <= 1'b0;                 // start bit
                    idx   <= 3'd0;
                    state <= S_DATA;
                end
                S_DATA: if (tick_tx) begin
                    txd <= tsr[0];                 // LSB first
                    tsr <= {1'b0, tsr[7:1]};
                    if (idx == 3'd7) state <= S_PARITY;
                    else             idx   <= idx + 1'b1;
                end
                S_PARITY: if (tick_tx) begin
                    txd   <= par;
                    state <= S_STOP;
                end
                S_STOP: if (tick_tx) begin
                    txd   <= 1'b1;                 // stop bit
                    state <= S_DONE;
                end
                S_DONE: if (tick_tx) begin
                    busy  <= 1'b0;
                    state <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule