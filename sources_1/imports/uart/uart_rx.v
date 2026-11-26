`timescale 1ns / 1ps
//------------------------------------------------------------------
// uart_rx.v - UART receiver: 1 start, 8 data (LSB first), 1 parity,
//             1 stop.  Uses tick_rx = 16 ticks per bit.
//
// Finding the middle of the bit:
//   IDLE  : wait for the line to fall (start bit begins)
//   START : count 8 ticks (half a bit) -> middle of the start bit,
//           check the line is still 0 (else it was a glitch)
//   later : sample every 16 ticks (one full bit) -> always mid-bit
//
// done is a 1-clock pulse; data / parity_err / frame_err are valid
// at that moment and then hold until the next frame.
//------------------------------------------------------------------
module uart_rx #(
    parameter ODD_PARITY = 0
)(
    input  wire       clk,
    input  wire       rst,            // active-high, synchronous
    input  wire       tick_rx,        // 16 pulses per bit time
    input  wire       rxd,            // asynchronous serial input
    output reg  [7:0] data,
    output reg        done,
    output reg        parity_err,
    output reg        frame_err       // stop bit was not 1
);
    localparam S_IDLE   = 3'd0,
               S_START  = 3'd1,
               S_DATA   = 3'd2,
               S_PARITY = 3'd3,
               S_STOP   = 3'd4;

    reg [2:0] state;
    reg [3:0] cnt;                    // counts tick_rx (0..15)
    reg [2:0] idx;                    // data bit counter
    reg [7:0] rsr;                    // receive shift register
    reg       par_rx;                 // received parity bit

    // 2-flip-flop synchronizer (line idles high)
    reg s0 = 1'b1, s1 = 1'b1;

    wire par_bad;
    parity_check #(.ODD_PARITY(ODD_PARITY)) u_pc (
        .data_in(rsr), .parity_bit(par_rx), .parity_error(par_bad)
    );

    always @(posedge clk) begin
        s0   <= rxd;
        s1   <= s0;
        done <= 1'b0;                 // default: pulse lasts 1 clock

        if (rst) begin
            state      <= S_IDLE;
            cnt        <= 4'd0;
            idx        <= 3'd0;
            rsr        <= 8'd0;
            par_rx     <= 1'b0;
            data       <= 8'd0;
            parity_err <= 1'b0;
            frame_err  <= 1'b0;
        end else begin
            case (state)
                S_IDLE: if (!s1) begin            // falling edge: start bit
                    cnt   <= 4'd0;
                    state <= S_START;
                end

                S_START: if (tick_rx) begin
                    if (cnt == 4'd7) begin        // middle of start bit
                        if (!s1) begin
                            cnt   <= 4'd0;
                            idx   <= 3'd0;
                            state <= S_DATA;
                        end else begin
                            state <= S_IDLE;      // glitch, not a real start
                        end
                    end else begin
                        cnt <= cnt + 1'b1;
                    end
                end

                S_DATA: if (tick_rx) begin
                    if (cnt == 4'd15) begin       // middle of a data bit
                        cnt <= 4'd0;
                        rsr <= {s1, rsr[7:1]};    // LSB first: shift right
                        if (idx == 3'd7) state <= S_PARITY;
                        else             idx   <= idx + 1'b1;
                    end else begin
                        cnt <= cnt + 1'b1;
                    end
                end

                S_PARITY: if (tick_rx) begin
                    if (cnt == 4'd15) begin       // middle of parity bit
                        cnt    <= 4'd0;
                        par_rx <= s1;
                        state  <= S_STOP;
                    end else begin
                        cnt <= cnt + 1'b1;
                    end
                end

                S_STOP: if (tick_rx) begin
                    if (cnt == 4'd15) begin       // middle of stop bit
                        cnt        <= 4'd0;
                        data       <= rsr;
                        parity_err <= par_bad;    // checker result
                        frame_err  <= ~s1;        // stop bit must be 1
                        done       <= 1'b1;
                        state      <= S_IDLE;
                    end else begin
                        cnt <= cnt + 1'b1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
