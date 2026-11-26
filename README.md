# UART with Parity on Nexys 4 DDR

Verilog UART transmitter and receiver with parity generation and checking,
built in Vivado for the Digilent Nexys 4 DDR board.

## Details
- Board: Digilent Nexys 4 DDR (FPGA part xc7a100tcsg324-1)
- Tool: Vivado 2026.1
- Language: Verilog
- Top module: `uart_top`
- Clock: 100 MHz, baud rate 9600

## Folder structure
- `sources_1` - design files (baud generator, UART TX/RX, parity, debounce, 7-segment display, top module)
- `sim_1` - testbenches
- `constrs_1` - constraints file (`uart_top.xdc`)

## How to use
1. Create a new Vivado project for the part xc7a100tcsg324-1.
2. Add the files from `sources_1` as design sources.
3. Add the files from `sim_1` as simulation sources.
4. Add `uart_top.xdc` from `constrs_1` as the constraints file.
5. Set `uart_top` as the top module, then run synthesis, implementation and generate the bitstream.
