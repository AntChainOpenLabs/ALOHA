// ===========================================================================
//
// Description:
//  Verilog module gnrl DFF chain without Reset
//
// ===========================================================================

module gnrl_dff #(
    parameter DWIDTH = 32,
    parameter DEPTH  = 4
) (
    input               clk,
    input  [DWIDTH-1:0] dnxt,
    output [DWIDTH-1:0] dout
);

  reg [DWIDTH-1:0] dout_reg[0:DEPTH-1];

  genvar index_dout;
  generate
    always @(posedge clk) begin
      dout_reg[0] <= dnxt;
    end

    for (index_dout = 1; index_dout < DEPTH; index_dout = index_dout + 1) begin
      always @(posedge clk) begin
        dout_reg[index_dout] <= dout_reg[index_dout-1];
      end
    end
  endgenerate

  if (DEPTH == 0) assign dout = dnxt;
  else assign dout = dout_reg[DEPTH-1];

endmodule

// ===========================================================================
//
// Description:
//  Verilog module gnrl DFF chain with Reset
//  Default value is 0
// ===========================================================================

module gnrl_dff_r #(
    parameter DWIDTH = 32,
    parameter DEPTH  = 4
) (
    input               clk,
    input               rst_n,
    input  [DWIDTH-1:0] dnxt,
    output [DWIDTH-1:0] dout
);

  reg [DWIDTH-1:0] dout_reg[0:DEPTH-1];

  genvar index_dout;
  generate
    always @(posedge clk or negedge rst_n) begin
      if (rst_n == 1'b0) dout_reg[0] <= 1'b0;
      else dout_reg[0] <= dnxt;
    end

    for (index_dout = 1; index_dout < DEPTH; index_dout = index_dout + 1) begin
      always @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) dout_reg[index_dout] <= 1'b0;
        else dout_reg[index_dout] <= dout_reg[index_dout-1];
      end
    end
  endgenerate

  if (DEPTH == 0) assign dout = dnxt;
  else assign dout = dout_reg[DEPTH-1];

endmodule
