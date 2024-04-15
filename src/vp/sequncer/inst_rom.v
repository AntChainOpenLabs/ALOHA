//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: 
// Module Name: inst_rom
// Modify Date: 

// Description: 1.Update parameters
//////////////////////////////////////////////////

`include "common_defines.vh"
`include "vp_defines.vh"
module inst_rom #(
    parameter DWIDTH = `COE_WIDTH,
    parameter DEPTH = `IQUEUE_DEPTH,
    parameter AWIDTH = $clog2(DEPTH),
    parameter COMMON_BRAM_DELAY = `COMMON_BRAM_DELAY,
    parameter INIT_FILE = ""
) (
    input                clk,
    input                rst_n,
    input                rden,
    input   [AWIDTH-1:0] addr,
    output               o_vld,
    output  [DWIDTH-1:0] dout
);
  //(* ram_style = "{auto | block | distributed | pipe_distributed | block_power1 | block_power2}" *)
  (* ram_style = "auto" *) reg [         DWIDTH-1:0] mem_bank[            0:DEPTH-1];
  reg [         DWIDTH-1:0] dout_reg[0:COMMON_BRAM_DELAY-1];

  initial begin
    if(INIT_FILE != "") begin
      $readmemh(INIT_FILE, mem_bank);
    end
    //ASSEMBLY_PATH}, mem_bank);
    // $readmemh ({{`PROJECT_ROOT},"NTT.srcs/sources_1/new/tf_rom/tf_576460825317867521.mem"}, mem_bank);
  end
  
  gnrl_dff_r #(1,COMMON_BRAM_DELAY) dec_opq_vld_dff (clk, rst_n, rden, o_vld);

    
  /* read */
  genvar index_dout;
  generate
    always @(posedge clk) begin
      dout_reg[0] <= mem_bank[addr];
    end

    for (index_dout = 1; index_dout < COMMON_BRAM_DELAY; index_dout = index_dout + 1) begin
      always @(posedge clk) begin
        dout_reg[index_dout] <= dout_reg[index_dout-1];
      end
    end
  endgenerate
  assign dout = dout_reg[COMMON_BRAM_DELAY-1];

endmodule
