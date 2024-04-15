//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: 
// Module Name: two_port_ram_fwft
// Modify Date: 

// Description: 1.Update parameters
//////////////////////////////////////////////////

`include "common_defines.vh"
`include "vp_defines.vh"
module two_port_ram_fwft #(
    parameter DWIDTH = `COE_WIDTH,
    parameter DEPTH  = `IQUEUE_DEPTH,
    parameter AWIDTH = $clog2(DEPTH)
) (
    input               clk,
    input               wea,
    input  [AWIDTH-1:0] addra,
    input  [DWIDTH-1:0] dina,
    input  [AWIDTH-1:0] addrb,
    output [DWIDTH-1:0] doutb
);

  reg [DWIDTH-1:0] mem_bank[0:DEPTH-1];

  /* write */
  always @(posedge clk) begin
    if (wea) begin
      mem_bank[addra] <= dina;
    end
  end

  /* read */
  assign doutb = mem_bank[addrb];

endmodule
