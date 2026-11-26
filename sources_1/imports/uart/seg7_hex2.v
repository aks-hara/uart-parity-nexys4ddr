`timescale 1ns / 1ps
//------------------------------------------------------------------
// seg7_hex2.v - shows an 8-bit value as two hex digits on the two
// right-most digits of the Nexys 4 DDR 7-segment display.
// enable = 0 -> display completely blank.
// Segments and digit selects are ACTIVE LOW (common anode).
// seg = {g,f,e,d,c,b,a}
//------------------------------------------------------------------
module seg7_hex2 (
    input  wire       clk,
    input  wire       enable,
    input  wire [7:0] value,
    output reg  [6:0] seg,
    output reg  [7:0] an
);
    reg [16:0] refresh = 17'd0;
    always @(posedge clk) refresh <= refresh + 1'b1;

    wire       sel = refresh[16];         // alternates ~760 times/second
    wire [3:0] nib = sel ? value[7:4] : value[3:0];

    always @* begin
        case (nib)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            4'hF: seg = 7'b0001110;
            default: seg = 7'b1111111;
        endcase

        if (!enable) an = 8'b1111_1111;           // all digits off
        else         an = sel ? 8'b1111_1101      // digit 1 (high nibble)
                              : 8'b1111_1110;     // digit 0 (low nibble)
    end
endmodule
