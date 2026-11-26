`timescale 1ns / 1ps
//------------------------------------------------------------------
// parity_gen.v - parity bit generator for an 8-bit word
// ODD_PARITY = 0 -> even parity (total number of 1s incl. parity is even)
// ODD_PARITY = 1 -> odd parity
//------------------------------------------------------------------
module parity_gen #(
    parameter ODD_PARITY = 0
)(
    input  wire [7:0] data_in,
    output wire       parity_bit
);
    // ^data_in = XOR of all 8 bits (1 when the count of 1s is odd)
    assign parity_bit = (^data_in) ^ (ODD_PARITY != 0);
endmodule
