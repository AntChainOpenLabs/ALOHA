module tb_addr_gen;

  // Parameters
  localparam  SCALAR_WIDTH = `SCALAR_WIDTH;
  localparam  COMMON_AGEN_DELAY = `COMMON_AGEN_DELAY;

  // Ports
  reg clk = 0;
  reg rst_n = 1;
  reg [$clog2(`SYS_VLMAX/`SYS_NUM_LANE)-1:0] i_seq_vmu_cnt = 1;
  reg [                    SCALAR_WIDTH-1:0] i_seq_vmu_scalar = 2;
  wire [                    SCALAR_WIDTH-1:0] o_scalar_addr;

  addr_gen 
  #(
    .SCALAR_WIDTH(SCALAR_WIDTH ),
    .COMMON_AGEN_DELAY (
        COMMON_AGEN_DELAY )
  )
  addr_gen_dut (
    .clk (clk ),
    .rst_n (rst_n ),
    .i_seq_vmu_cnt (i_seq_vmu_cnt ),
    .i_seq_vmu_scalar (i_seq_vmu_scalar ),
    .o_scalar_addr  ( o_scalar_addr)
  );

  initial begin
    begin
      #1000
      $finish;
    end
  end

  always
    #5  clk = ! clk ;

endmodule
