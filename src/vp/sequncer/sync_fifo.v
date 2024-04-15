//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: 
// Module Name: sync_fifo
// Modify Date: 

// Description: synchronous FIFO
// ref: https://github.com/surangamh/synchronous-fifo
//////////////////////////////////////////////////

`include "common_defines.vh"
`include "vp_defines.vh"
module sync_fifo #(
    parameter DWIDTH            = `COE_WIDTH,
    parameter DEPTH             = `IQUEUE_DEPTH,
    parameter AWIDTH            = $clog2(DEPTH),
    parameter COMMON_BRAM_DELAY = `COMMON_BRAM_DELAY
) (
    input                   clk,
    input                   reset,
    input                   push,
    input      [DWIDTH-1:0] in,
    input                   pop,
    output     [DWIDTH-1:0] out,
    output                  empty,
    output                  almostempty,
    output                  full,
    output                  almostfull,
    output reg [AWIDTH:0]   num
);

  localparam        ALMOSTEMPTY = 3;  // number of items greater than zero
  localparam        ALMOSTFULL = DEPTH - 3;  // number of items less than DEPTH
//  reg               weRAM;
//  reg [DWIDTH-1:0]  wdReg;
  reg [AWIDTH-1:0]  wPtr;
  reg [AWIDTH-1:0]  rPtr;
  wire              fifoWrValid;
  wire              fifoRdValid;

  assign empty          = (num == 0)?           1 : 0;
  assign almostempty    = (num <= ALMOSTEMPTY)? 1 : 0;
  assign full           = (num == DEPTH)?       1 : 0;
  assign almostfull     = (num >= ALMOSTFULL) ? 1 : 0;
//  assign fifoWrValid    = !full & push;
//  assign fifoRdValid    = !empty & pop;
  assign fifoWrValid    = push;
  assign fifoRdValid    = pop;

if(COMMON_BRAM_DELAY == 0) begin
  two_port_ram_fwft #(
      .DWIDTH(DWIDTH),
      .AWIDTH(AWIDTH),
      .DEPTH(DEPTH)
  ) ram_fifo (
      .clk  (clk        ),
      .wea  (fifoWrValid),
      .addra(wPtr       ),
      .dina (in         ),
      .addrb(rPtr       ),
      .doutb(out        )
  );
end
else begin
  two_port_ram #(
      .DWIDTH(DWIDTH),
      .AWIDTH(AWIDTH),
      .DEPTH(DEPTH),
      .COMMON_BRAM_DELAY(COMMON_BRAM_DELAY)
  ) ram_fifo (
      .clk  (clk        ),
      .wea  (fifoWrValid),
      .addra(wPtr       ),
      .dina (in         ),
      .addrb(rPtr       ),
      .doutb(out        )
  );
end

//  // write enable logic
//  always @(posedge clk) begin
//    if (reset) weRAM <= 0;
//    else if (fifoWrValid) weRAM <= 1;
//    else weRAM <= 0;
//  end
//  // write data logic 
//  always @(posedge clk) begin
//    wdReg <= in;
//  end
  // write pointer logic
  always @(posedge clk) begin
    if (reset) wPtr <= 0;
    else if (fifoWrValid) wPtr <= wPtr + 1'b1;
  end
  // read pointer logic
  always @(posedge clk) begin
    if (reset) rPtr <= 0;
    else if (fifoRdValid) rPtr <= rPtr + 1'b1;
  end
  // count logic
  always @(posedge clk) begin
    if (reset) num <= 0;
    else if (fifoWrValid & !fifoRdValid) num <= num + 1;
    else if (fifoRdValid & !fifoWrValid) num <= num - 1;
  end
endmodule
