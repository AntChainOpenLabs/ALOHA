
module tb_vmu_top;

  // Parameters
  localparam  CONFIG_OP_WIDTH = `CONFIG_OP_WIDTH;
  localparam  LSU_OP_WIDTH = `LSU_OP_WIDTH;
  localparam  SCALAR_WIDTH = `SCALAR_WIDTH;
  localparam  COMMON_AGEN_DELAY = `COMMON_AGEN_DELAY;
  localparam  COMMON_MEMR_DELAY = `COMMON_MEMR_DELAY;
  localparam  COMMON_MEMW_DELAY = `COMMON_MEMW_DELAY;
  localparam  COMMON_VMU_DELAY = `COMMON_VMU_DELAY;

  // Ports
  reg clk = 0;
  reg rst_n = 1;
  reg i_seq_vmu_op_vld = 1;
  reg [$clog2(`SYS_VLMAX/`SYS_NUM_LANE)-1:0] i_seq_vmu_cnt = 1;
  reg [LSU_OP_WIDTH-1:0] i_seq_vmu_op_ls [0:`SYS_NUM_LSU-1];
  reg [SCALAR_WIDTH-1:0] i_seq_vmu_scalar_ls [0:`SYS_NUM_LSU-1];
  reg [CONFIG_OP_WIDTH-1:0] i_seq_vxu_op_config = 0;
  reg [SCALAR_WIDTH-1:0] i_seq_vxu_scalar_config = 33333;
  wire o_vmu_spm_rden[0:`SYS_NUM_LSU-1];
  wire o_vmu_spm_wren[0:`SYS_NUM_LSU-1];
  wire [SCALAR_WIDTH-1:0] o_vmu_spm_rdaddr[0:`SYS_NUM_LSU-1];
  wire [SCALAR_WIDTH-1:0] o_vmu_spm_wraddr[0:`SYS_NUM_LSU-1];

  assign i_seq_vmu_op_ls [0] = 1;
  assign i_seq_vmu_scalar_ls [0] = 128;
  
  vmu_top 
  #(
    .CONFIG_OP_WIDTH(CONFIG_OP_WIDTH ),
    .LSU_OP_WIDTH(LSU_OP_WIDTH ),
    .SCALAR_WIDTH(SCALAR_WIDTH ),
    .COMMON_AGEN_DELAY(COMMON_AGEN_DELAY ),
    .COMMON_MEMR_DELAY(COMMON_MEMR_DELAY ),
    .COMMON_MEMW_DELAY(COMMON_MEMW_DELAY ),
    .COMMON_VMU_DELAY (
        COMMON_VMU_DELAY )
  )
  vmu_top_dut (
    .clk (clk ),
    .rst_n (rst_n ),
    .i_seq_vmu_op_vld (i_seq_vmu_op_vld ),
    .i_seq_vmu_cnt (i_seq_vmu_cnt ),
    .i_seq_vmu_op_ls (i_seq_vmu_op_ls ),
    .i_seq_vmu_scalar_ls (i_seq_vmu_scalar_ls ),
    .i_seq_vxu_op_config (i_seq_vxu_op_config ),
    .i_seq_vxu_scalar_config (i_seq_vxu_scalar_config ),
    .o_vmu_spm_rden (o_vmu_spm_rden ),
    .o_vmu_spm_wren (o_vmu_spm_wren ),
    .o_vmu_spm_rdaddr (o_vmu_spm_rdaddr ),
    .o_vmu_spm_wraddr  ( o_vmu_spm_wraddr)
  );

  initial begin
    begin
    # 1000
      $finish;
    end
  end

  always
    #5  clk = ! clk ;

endmodule
