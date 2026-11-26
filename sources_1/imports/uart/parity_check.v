`timescale 1ns / 1ps
//------------------------------------------------------------------
// parity_check.v - parity checker for a received 8-bit word
// parity_error = 1 when the received parity bit does not match.
// ODD_PARITY = 0 -> even parity, 1 -> odd parity (same as parity_gen)
//------------------------------------------------------------------
module parity_check #(
    parameter ODD_PARITY = 0
)(
    input  wire [7:0] data_in,
    input  wire       parity_bit,     // parity bit that was received
    output wire       parity_error
);
    // XOR of all data bits and the parity bit is 0 for even parity
    // when nothing is wrong (1 for odd parity, hence the last term).
    assign parity_error = (^data_in) ^ parity_bit ^ (ODD_PARITY != 0);
endmodule
