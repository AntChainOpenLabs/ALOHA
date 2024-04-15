//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: 
// Module Name: two_port_ram
// Modify Date: 

// Description: 1.Update parameters
//////////////////////////////////////////////////

`include "common_defines.vh"
`include "vp_defines.vh"
module two_port_ram #(
    parameter DWIDTH = `COE_WIDTH,
    parameter DEPTH = `IQUEUE_DEPTH,
    parameter AWIDTH = $clog2(DEPTH),
    parameter COMMON_BRAM_DELAY = `COMMON_BRAM_DELAY
) (
    input               clk,
    input               wea,
    input  [AWIDTH-1:0] addra,
    input  [DWIDTH-1:0] dina,
    input  [AWIDTH-1:0] addrb,
    output [DWIDTH-1:0] doutb
);

  reg [DWIDTH-1:0] mem_bank[0:DEPTH-1];
  reg [DWIDTH-1:0] doutb_reg[0:COMMON_BRAM_DELAY-1];

  /* write */
  always @(posedge clk) begin
    if (wea) begin
      mem_bank[addra] <= dina;
    end
  end

  /* read */
  genvar index_dout;
  generate
    always @(posedge clk) begin
      doutb_reg[0] <= mem_bank[addrb];
    end

    for (index_dout = 1; index_dout < COMMON_BRAM_DELAY; index_dout = index_dout + 1) begin
      always @(posedge clk) begin
        doutb_reg[index_dout] <= doutb_reg[index_dout-1];
      end
    end
  endgenerate
  assign doutb = doutb_reg[COMMON_BRAM_DELAY-1];

endmodule
