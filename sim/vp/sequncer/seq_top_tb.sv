`timescale 1ns/1ps
//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: 
// Module Name: tb_seq_top
// Modify Date: 

// Description: tb for seq
//////////////////////////////////////////////////

`include "common_defines.vh"
`include "vp_defines.vh"

module seq_top_tb;

  // Parameters
  localparam PC_WIDTH = `PC_WIDTH;
  localparam INST_WIDTH = `INST_WIDTH;
  localparam CONFIG_OP_WIDTH = `CONFIG_OP_WIDTH;
  localparam MUXO_OP_WIDTH = `MUXO_OP_WIDTH;
  localparam MUXI_OP_WIDTH = `MUXI_OP_WIDTH;
  localparam RW_OP_WIDTH = `RW_OP_WIDTH;
  localparam ALU_OP_WIDTH = `ALU_OP_WIDTH;
  localparam ICONN_OP_WIDTH = `ICONN_OP_WIDTH;
  localparam NTT_OP_WIDTH = `NTT_OP_WIDTH;
  localparam LSU_OP_WIDTH = `LSU_OP_WIDTH;
  localparam SCALAR_WIDTH = `SCALAR_WIDTH;
  localparam IQUEUE_DEPTH = `IQUEUE_DEPTH;
  localparam OPQUEUE_DEPTH = `OPQUEUE_DEPTH;
  localparam COMMON_BRAM_DELAY = `COMMON_BRAM_DELAY;
  localparam CNT_WIDTH = `CNT_WIDTH;

  localparam NUM_INST = 22;
  localparam KERNEL = 2; // 0：Homo_add 1:mul_plain 2:inst_issue_test
  localparam ADD_ASSEMBLY_PATH = "./add_inst.mem";
  localparam MUL_ASSEMBLY_PATH = "./mul_inst.mem";
  localparam INST_ISSUE_TEST_ASSEMBLY_PATH = "./inst_issue_test.mem";
  localparam ADD_PATH = "./golden/homo_add.txt";
  localparam MUL_PATH = "./golden/mul_plain.txt";
  localparam INST_ISSUE_TEST_PATH = "./golden/inst_issue_test.txt";
  
  // Ports
  reg                                         clk = 0;
  reg                                         rst_n = 0;
  reg                                         i_sys_start = 0;
  wire                                        o_sys_done;
  wire                                         i_seq_inst_vld;
  wire  [                      INST_WIDTH-1:0] i_seq_inst;
  wire                                        o_seq_pc_vld;
  wire [             $clog2(`IRAM_DEPTH)-1:0] o_seq_pc_offset;
  wire                                        o_seq_vxu_issue_vld;
  wire [                 CONFIG_OP_WIDTH-1:0] o_seq_vxu_op_config;
  wire [                    SCALAR_WIDTH-1:0] o_seq_vxu_scalar_config;
  wire [                     RW_OP_WIDTH-1:0] o_seq_vxu_op_b0r;
  wire [                     RW_OP_WIDTH-1:0] o_seq_vxu_op_b0w;
  wire [                     RW_OP_WIDTH-1:0] o_seq_vxu_op_b1r;
  wire [                     RW_OP_WIDTH-1:0] o_seq_vxu_op_b1w;
  wire [                    ALU_OP_WIDTH-1:0] o_seq_vxu_op_alu;
  wire [                    SCALAR_WIDTH-1:0] o_seq_vxu_scalar_alu;
  wire [                  ICONN_OP_WIDTH-1:0] o_seq_vxu_op_iconn;
  wire [                    SCALAR_WIDTH-1:0] o_seq_vxu_scalar_iconn;
  wire [                    NTT_OP_WIDTH-1:0] o_seq_vxu_op_ntt;
  wire [                   MUXO_OP_WIDTH-1:0] o_seq_vxu_op_muxo;
  wire [                   MUXI_OP_WIDTH-1:0] o_seq_vxu_op_muxi;
  wire                                        o_seq_vmu_issue_vld;
  wire [                 CONFIG_OP_WIDTH-1:0] o_seq_vmu_op_config;
  wire [                    SCALAR_WIDTH-1:0] o_seq_vmu_scalar_config;
  wire [                    LSU_OP_WIDTH-1:0] o_seq_vmu_op_ls;
  wire [                    SCALAR_WIDTH-1:0] o_seq_vmu_scalar_ls;
  wire [                       CNT_WIDTH-1:0] o_seq_cnt;
  wire                                        o_seq_comp_vld;

  initial $printtimescale;

  initial begin
    begin
      #101
      seq_top_dut.HERV_VLEN_REG = 1024*64;
      #170000 $finish;
    end
  end

  initial begin
      #50 i_sys_start <= 1;
  end
  
  always @(posedge clk) begin
      if (seq_top_tb.seq_top_dut.decode_exp.o_expander_break == 1) begin
        i_sys_start <= 0;
      end 
//      else begin
//        i_sys_start <= 1;
//      end
  end

  initial begin
      #20 rst_n <= 1;
  end
  
  initial begin
    forever #20 clk = ~clk;
  end
  
  // init test kernel
  initial begin
    #10
    if (KERNEL == 0) $readmemh (ADD_ASSEMBLY_PATH, seq_top_tb.inst_rom_dut.mem_bank);
    else if (KERNEL == 1) $readmemh (MUL_ASSEMBLY_PATH, seq_top_tb.inst_rom_dut.mem_bank);
    else $readmemh (INST_ISSUE_TEST_ASSEMBLY_PATH, seq_top_tb.inst_rom_dut.mem_bank);
  end
  
  // test golden result
  int fp;
  int flag;
  int index_bank, index_issue = 0;
  reg   [CONFIG_OP_WIDTH-1:0]                    seq_vxu_op_config           [0:NUM_INST-1];
  reg   [SCALAR_WIDTH-1:0]                       seq_vxu_scalar_config       [0:NUM_INST-1];
  reg   [RW_OP_WIDTH-1:0]                        seq_vxu_op_b0r              [0:NUM_INST-1];
  reg   [RW_OP_WIDTH-1:0]                        seq_vxu_op_b0w              [0:NUM_INST-1];
  reg   [RW_OP_WIDTH-1:0]                        seq_vxu_op_b1r              [0:NUM_INST-1];
  reg   [RW_OP_WIDTH-1:0]                        seq_vxu_op_b1w              [0:NUM_INST-1];
  reg   [ALU_OP_WIDTH-1:0]                       seq_vxu_op_alu              [0:NUM_INST-1];
  reg   [SCALAR_WIDTH-1:0]                       seq_vxu_scalar_alu          [0:NUM_INST-1];
  reg   [ICONN_OP_WIDTH-1:0]                     seq_vxu_op_iconn            [0:NUM_INST-1];
  reg   [SCALAR_WIDTH-1:0]                       seq_vxu_scalar_iconn        [0:NUM_INST-1];
  reg   [NTT_OP_WIDTH-1:0]                       seq_vxu_op_ntt              [0:NUM_INST-1];
  reg   [MUXO_OP_WIDTH-1:0]                      seq_vxu_op_muxo             [0:NUM_INST-1];
  reg   [MUXI_OP_WIDTH-1:0]                      seq_vxu_op_muxi             [0:NUM_INST-1];
  reg   [CONFIG_OP_WIDTH-1:0]                    seq_vmu_op_config           [0:NUM_INST-1];
  reg   [SCALAR_WIDTH-1:0]                       seq_vmu_scalar_config       [0:NUM_INST-1];
  reg   [LSU_OP_WIDTH-1:0]                       seq_vmu_op_ls               [0:NUM_INST-1];
  reg   [SCALAR_WIDTH-1:0]                       seq_vmu_scalar_ls           [0:NUM_INST-1];

  
  initial begin
    if (KERNEL == 0) fp = $fopen($sformatf(ADD_PATH), "r");
    else if (KERNEL == 1) fp = $fopen($sformatf(MUL_PATH), "r");
    else fp = $fopen($sformatf(INST_ISSUE_TEST_PATH), "r");

    for (index_bank = 0; index_bank < NUM_INST; index_bank = index_bank + 1) begin
      flag = $fscanf(fp, "%02x,%016x,%02x,%02x,%02x,%02x,%02x,%016x,%02x,%016x,%02x,%02x,%02x,%02x,%016x,%02x,%016x", 
      seq_vxu_op_config     [index_bank],
      seq_vxu_scalar_config [index_bank],
      seq_vxu_op_b0r        [index_bank],
      seq_vxu_op_b0w        [index_bank],
      seq_vxu_op_b1r        [index_bank],
      seq_vxu_op_b1w        [index_bank],
      seq_vxu_op_alu        [index_bank],
      seq_vxu_scalar_alu    [index_bank],
      seq_vxu_op_iconn      [index_bank],
      seq_vxu_scalar_iconn  [index_bank],
      seq_vxu_op_ntt        [index_bank],
      seq_vxu_op_muxo       [index_bank],
      seq_vxu_op_muxi       [index_bank],
      seq_vmu_op_config     [index_bank],
      seq_vmu_scalar_config [index_bank],
      seq_vmu_op_ls         [index_bank],
      seq_vmu_scalar_ls     [index_bank]); 
    end
  end

  always@(posedge clk) begin
    if(seq_top_tb.o_seq_vxu_issue_vld == 1) begin
        index_issue <= index_issue+1;
    end
  end

  /* test the final result */
  always @(posedge clk) begin
    #1;
    if (seq_top_tb.o_seq_vxu_issue_vld==1) begin
        if (seq_top_tb.o_seq_vxu_op_config     != seq_vxu_op_config    [index_issue]) $display("The output is wrong!!!, for the seq_vxu_op_config    , index %x, result shows %x, the correct result is %x", index_issue, seq_top_tb.o_seq_vxu_op_config    , seq_vxu_op_config    [index_issue]);
        if (seq_top_tb.o_seq_vxu_scalar_config != seq_vxu_scalar_config[index_issue]) $display("The output is wrong!!!, for the seq_vxu_scalar_config, index %x, result shows %x, the correct result is %x", index_issue, seq_top_tb.o_seq_vxu_scalar_config, seq_vxu_scalar_config[index_issue]);
        if (seq_top_tb.o_seq_vxu_op_b0r        != seq_vxu_op_b0r       [index_issue]) $display("The output is wrong!!!, for the seq_vxu_op_b0r       , index %x, result shows %x, the correct result is %x", index_issue, seq_top_tb.o_seq_vxu_op_b0r       , seq_vxu_op_b0r       [index_issue]);
        if (seq_top_tb.o_seq_vxu_op_b0w        != seq_vxu_op_b0w       [index_issue]) $display("The output is wrong!!!, for the seq_vxu_op_b0w       , index %x, result shows %x, the correct result is %x", index_issue, seq_top_tb.o_seq_vxu_op_b0w       , seq_vxu_op_b0w       [index_issue]);
        if (seq_top_tb.o_seq_vxu_op_b1r        != seq_vxu_op_b1r       [index_issue]) $display("The output is wrong!!!, for the seq_vxu_op_b1r       , index %x, result shows %x, the correct result is %x", index_issue, seq_top_tb.o_seq_vxu_op_b1r       , seq_vxu_op_b1r       [index_issue]);
        if (seq_top_tb.o_seq_vxu_op_b1w        != seq_vxu_op_b1w       [index_issue]) $display("The output is wrong!!!, for the seq_vxu_op_b1w       , index %x, result shows %x, the correct result is %x", index_issue, seq_top_tb.o_seq_vxu_op_b1w       , seq_vxu_op_b1w       [index_issue]);
        if (seq_top_tb.o_seq_vxu_op_alu        != seq_vxu_op_alu       [index_issue]) $display("The output is wrong!!!, for the seq_vxu_op_alu       , index %x, result shows %x, the correct result is %x", index_issue, seq_top_tb.o_seq_vxu_op_alu       , seq_vxu_op_alu       [index_issue]);
        if (seq_top_tb.o_seq_vxu_scalar_alu    != seq_vxu_scalar_alu   [index_issue]) $display("The output is wrong!!!, for the seq_vxu_scalar_alu   , index %x, result shows %x, the correct result is %x", index_issue, seq_top_tb.o_seq_vxu_scalar_alu   , seq_vxu_scalar_alu   [index_issue]);
        if (seq_top_tb.o_seq_vxu_op_iconn      != seq_vxu_op_iconn     [index_issue]) $display("The output is wrong!!!, for the seq_vxu_op_iconn     , index %x, result shows %x, the correct result is %x", index_issue, seq_top_tb.o_seq_vxu_op_iconn     , seq_vxu_op_iconn     [index_issue]);
        if (seq_top_tb.o_seq_vxu_scalar_iconn  != seq_vxu_scalar_iconn [index_issue]) $display("The output is wrong!!!, for the seq_vxu_scalar_iconn , index %x, result shows %x, the correct result is %x", index_issue, seq_top_tb.o_seq_vxu_scalar_iconn , seq_vxu_scalar_iconn [index_issue]);
        if (seq_top_tb.o_seq_vxu_op_ntt        != seq_vxu_op_ntt       [index_issue]) $display("The output is wrong!!!, for the seq_vxu_op_ntt       , index %x, result shows %x, the correct result is %x", index_issue, seq_top_tb.o_seq_vxu_op_ntt       , seq_vxu_op_ntt       [index_issue]);
        if (seq_top_tb.o_seq_vxu_op_muxo       != seq_vxu_op_muxo      [index_issue]) $display("The output is wrong!!!, for the seq_vxu_op_muxo      , index %x, result shows %x, the correct result is %x", index_issue, seq_top_tb.o_seq_vxu_op_muxo      , seq_vxu_op_muxo      [index_issue]);
        if (seq_top_tb.o_seq_vxu_op_muxi       != seq_vxu_op_muxi      [index_issue]) $display("The output is wrong!!!, for the seq_vxu_op_muxi      , index %x, result shows %x, the correct result is %x", index_issue, seq_top_tb.o_seq_vxu_op_muxi      , seq_vxu_op_muxi      [index_issue]);
        if (seq_top_tb.o_seq_vmu_op_config     != seq_vmu_op_config    [index_issue]) $display("The output is wrong!!!, for the seq_vmu_op_config    , index %x, result shows %x, the correct result is %x", index_issue, seq_top_tb.o_seq_vmu_op_config    , seq_vmu_op_config    [index_issue]);
        if (seq_top_tb.o_seq_vmu_scalar_config != seq_vmu_scalar_config[index_issue]) $display("The output is wrong!!!, for the seq_vmu_scalar_config, index %x, result shows %x, the correct result is %x", index_issue, seq_top_tb.o_seq_vmu_scalar_config, seq_vmu_scalar_config[index_issue]);
        if (seq_top_tb.o_seq_vmu_op_ls         != seq_vmu_op_ls        [index_issue]) $display("The output is wrong!!!, for the seq_vmu_op_ls        , index %x, result shows %x, the correct result is %x", index_issue, seq_top_tb.o_seq_vmu_op_ls        , seq_vmu_op_ls        [index_issue]);
        if (seq_top_tb.o_seq_vmu_scalar_ls     != seq_vmu_scalar_ls    [index_issue]) $display("The output is wrong!!!, for the seq_vmu_scalar_ls    , index %x, result shows %x, the correct result is %x", index_issue, seq_top_tb.o_seq_vmu_scalar_ls    , seq_vmu_scalar_ls    [index_issue]);
    end
  end
  
  inst_rom #(
      .DWIDTH(INST_WIDTH),
      .DEPTH(4096),
      .COMMON_BRAM_DELAY(COMMON_BRAM_DELAY)
  ) inst_rom_dut (
      .clk  (clk            ),
      .rst_n(rst_n          ),
      .rden (o_seq_pc_vld   ),
      .o_vld(i_seq_inst_vld ),
      .addr (o_seq_pc_offset),
      .dout (i_seq_inst     )
  );

  seq_top #(
      .PC_WIDTH(PC_WIDTH),
      .INST_WIDTH(INST_WIDTH),
      .CONFIG_OP_WIDTH(CONFIG_OP_WIDTH),
      .MUXO_OP_WIDTH(MUXO_OP_WIDTH),
      .MUXI_OP_WIDTH(MUXI_OP_WIDTH),
      .RW_OP_WIDTH(RW_OP_WIDTH),
      .ALU_OP_WIDTH(ALU_OP_WIDTH),
      .LSU_OP_WIDTH(LSU_OP_WIDTH),
      .SCALAR_WIDTH(SCALAR_WIDTH),
      .IQUEUE_DEPTH(IQUEUE_DEPTH),
      .OPQUEUE_DEPTH(OPQUEUE_DEPTH),
      .COMMON_BRAM_DELAY(COMMON_BRAM_DELAY)
  ) seq_top_dut (
      .clk                    (clk),
      .rst_n                  (rst_n),
      .i_sys_start            (i_sys_start),
      .o_sys_done             (o_sys_done),
      .i_seq_inst_vld         (i_seq_inst_vld),
      .i_seq_inst             (i_seq_inst),
      .o_seq_pc_vld           (o_seq_pc_vld),
      .o_seq_pc_offset        (o_seq_pc_offset),
      .o_seq_vxu_issue_vld    (o_seq_vxu_issue_vld),
      .o_seq_vxu_op_config    (o_seq_vxu_op_config),
      .o_seq_vxu_scalar_config(o_seq_vxu_scalar_config),
      .o_seq_vxu_op_b0r       (o_seq_vxu_op_b0r),
      .o_seq_vxu_op_b0w       (o_seq_vxu_op_b0w),
      .o_seq_vxu_op_b1r       (o_seq_vxu_op_b1r),
      .o_seq_vxu_op_b1w       (o_seq_vxu_op_b1w),
      .o_seq_vxu_op_alu       (o_seq_vxu_op_alu),
      .o_seq_vxu_scalar_alu   (o_seq_vxu_scalar_alu),
      .o_seq_vxu_op_iconn     (o_seq_vxu_op_iconn),
      .o_seq_vxu_scalar_iconn (o_seq_vxu_scalar_iconn),
      .o_seq_vxu_op_ntt       (o_seq_vxu_op_ntt),
      .o_seq_vxu_op_muxo      (o_seq_vxu_op_muxo),
      .o_seq_vxu_op_muxi      (o_seq_vxu_op_muxi),
      .o_seq_vmu_issue_vld    (o_seq_vmu_issue_vld),
      .o_seq_vmu_op_config    (o_seq_vmu_op_config),
      .o_seq_vmu_scalar_config(o_seq_vmu_scalar_config),
      .o_seq_vmu_op_ls        (o_seq_vmu_op_ls),
      .o_seq_vmu_scalar_ls    (o_seq_vmu_scalar_ls),
      .o_seq_cnt              (o_seq_cnt),
      .o_seq_comp_vld         (o_seq_comp_vld)
  );

  `ifdef FSDB_DUMP
      initial begin
          $fsdbDumpfile("top.fsdb");
          $fsdbDumpvars(0, 0, "+all");
          $fsdbDumpMDA();
      end
  `endif

endmodule