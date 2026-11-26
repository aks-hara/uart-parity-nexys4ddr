`timescale 1ns / 1ps
//------------------------------------------------------------------
// debounce.v - synchronizer + debouncer + one-shot for a push button
// pulse = 1 clock wide, once per press (on the debounced rising edge)
//------------------------------------------------------------------
module debounce #(
    parameter STABLE_CLKS = 1_000_000      // 10 ms at 100 MHz
)(
    input  wire clk,
    input  wire btn_in,
    output reg  pulse
);
    reg s0, s1, state, prev;
    reg [$clog2(STABLE_CLKS)-1:0] cnt;

    initial begin
        s0 = 0; s1 = 0; state = 0; prev = 0; cnt = 0; pulse = 0;
    end

    always @(posedge clk) begin
        s0 <= btn_in;                      // 2-flip-flop synchronizer
        s1 <= s0;

        if (s1 == state) begin
            cnt <= 0;                      // input agrees with stable state
        end else if (cnt == STABLE_CLKS - 1) begin
            state <= s1;                   // input stable long enough
            cnt   <= 0;
        end else begin
            cnt <= cnt + 1'b1;
        end

        prev  <= state;
        pulse <= state & ~prev;            // rising edge of debounced state
    end
endmodule
