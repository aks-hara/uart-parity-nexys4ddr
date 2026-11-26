`timescale 1ns / 1ps
//------------------------------------------------------------------
// uart_top.v - Nexys 4 DDR top: UART TX + RX with parity
//
// INPUT  : sw[7:0] data, sw[8] inject parity error, btnc = send
//          sw[15]  RX source: 0 = internal loopback (TX -> RX)
//                             1 = PC (USB-UART pin UART_TXD_IN)
//          cpu_resetn : active-low reset
// OUTPUT : led[0]  txd (serial line, ON when idle)
//          led[1]  parity bit sent by the transmitter
//          led[2]  data valid (7-segment is showing the byte)
//          led[3]  PARITY ERROR (held until the next send)
//          led[4]  frame error (stop bit was not 1)
//          led[15] busy (transmitter sending)
//          7-segment: received byte in hex, shown ONLY after the
//          transmitter is back in idle; blank while a new frame is sent.
//
// BAUD = 2 : slow demo (0.5 s per bit).  BAUD = 9600 : PC terminal.
//------------------------------------------------------------------
module uart_top #(
    parameter BAUD = 2
)(
    input  wire        clk,
    input  wire        cpu_resetn,
    input  wire        btnc,
    input  wire [15:0] sw,
    input  wire        uart_txd_in,       // from PC (our RX input)
    output wire        uart_rxd_out,      // to PC   (our TX output)
    output wire        ja1,
    output wire [15:0] led,
    output wire [6:0]  seg,
    output wire        dp,
    output wire [7:0]  an
);
    // reset: invert active-low button, synchronize
    reg [1:0] rst_sync = 2'b11;
    always @(posedge clk) rst_sync <= {rst_sync[0], ~cpu_resetn};
    wire rst = rst_sync[1];

    wire       tick_tx, tick_rx;
    wire       send_pulse, txd, busy, par_sent;
    wire [7:0] data_w   = sw[7:0];
    wire       inject_w = sw[8];
    wire       pc_sel   = sw[15];

    baud_gen #(.CLK_FREQ(100_000_000), .BAUD(BAUD), .OVERSAMPLE(16)) u_baud (
        .clk(clk), .rst(rst), .tick_rx(tick_rx), .tick_tx(tick_tx)
    );

    debounce u_db (.clk(clk), .btn_in(btnc), .pulse(send_pulse));

    uart_tx #(.ODD_PARITY(0)) u_tx (
        .clk(clk), .rst(rst), .tick_tx(tick_tx),
        .send(send_pulse), .data(data_w), .inject_error(inject_w),
        .txd(txd), .busy(busy), .par_sent(par_sent)
    );

    // receiver listens either to our own TX or to the PC
    wire       rxd_line = pc_sel ? uart_txd_in : txd;
    wire [7:0] rx_data;
    wire       rx_done, rx_perr, rx_ferr;

    uart_rx #(.ODD_PARITY(0)) u_rx (
        .clk(clk), .rst(rst), .tick_rx(tick_rx), .rxd(rxd_line),
        .data(rx_data), .done(rx_done),
        .parity_err(rx_perr), .frame_err(rx_ferr)
    );

    //--------------------------------------------------------------
    // Show the result only when the transmitter is idle again.
    //  - rx_done  : byte received -> keep it in hold_*, mark pending
    //  - send     : a new frame starts -> blank display, clear errors
    //  - pending && !busy : transmitter idle -> show byte and flags
    //--------------------------------------------------------------
    reg       pending  = 1'b0;
    reg       disp_en  = 1'b0;
    reg       perr_led = 1'b0;
    reg       ferr_led = 1'b0;
    reg [7:0] hold_data = 8'd0, disp_data = 8'd0;
    reg       hold_perr = 1'b0, hold_ferr = 1'b0;

    always @(posedge clk) begin
        if (rst) begin
            pending  <= 1'b0;
            disp_en  <= 1'b0;
            perr_led <= 1'b0;
            ferr_led <= 1'b0;
            hold_data <= 8'd0; disp_data <= 8'd0;
            hold_perr <= 1'b0; hold_ferr <= 1'b0;
        end else begin
            if (rx_done) begin
                hold_data <= rx_data;
                hold_perr <= rx_perr;
                hold_ferr <= rx_ferr;
                pending   <= 1'b1;
            end
            if (send_pulse && !busy) begin       // new frame is starting
                disp_en  <= 1'b0;
                perr_led <= 1'b0;
                ferr_led <= 1'b0;
            end
            if (pending && !busy) begin          // idle again: show result
                disp_data <= hold_data;
                perr_led  <= hold_perr;
                ferr_led  <= hold_ferr;
                disp_en   <= 1'b1;
                pending   <= 1'b0;
            end
        end
    end

    seg7_hex2 u_seg (
        .clk(clk), .enable(disp_en), .value(disp_data), .seg(seg), .an(an)
    );

    assign dp           = 1'b1;                  // decimal point off
    assign uart_rxd_out = txd;
    assign ja1          = txd;
    assign led          = {busy, 10'd0, ferr_led, perr_led, disp_en, par_sent, txd};
endmodule
