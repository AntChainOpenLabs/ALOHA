//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: 
// Module Name: vp_defines
// Modify Date:

// Description: 
// params definations
// 
//////////////////////////////////////////////////

`define VP_STANDALONE
// `define VP_HERV

`ifdef VP_STANDALONE
`define PC_WIDTH 32

`define INST_WIDTH 96
`endif  // VP_STANDALONE

// SYSTEM params
`define SYS_VLMAX 524288
`define SYS_NUM_LANE 128
`define SYS_NUM_LSU 1
`define SYS_SPM_DEPTH 16           // abstract to a depth SPM 16MB 4096/256*4 = 64 ciphertext
`define SYS_SPM_ADDR_WIDTH 16
`define SYS_KSK_ADDR_WIDTH 16

`define IRAM_DEPTH 4096
`define IQUEUE_DEPTH 8
`define OPQUEUE_DEPTH 8
`define DECODE_DELAY 1

// CNTL params
`define ITL_NUM_STATES 3
`define NTT_NUM_STATES 3
`define VXU_NUM_STATES 15
`define VMU_NUM_STATES 3
`define VXU_NTT_SWAP_LATENCY 2
`define VXU_ALU_MUL_LEVEL 2
`define VXU_ALU_MUL_STAGE 2
`define VXU_ALU_LAST_STAGE 2
`define VXU_ALU_MODHALF_STAGE 1
`define VXU_INTT_SWAP_LATENCY 1
`define VXU_RF_READ_LATENCY 3

// Data params
`define COE_WIDTH 6

`define CONFIG_OP_WIDTH 2
`define MUXO_OP_WIDTH 4
`define MUXI_OP_WIDTH 4
`define RW_OP_WIDTH 6
`define ALU_OP_WIDTH 5
`define ICONN_OP_WIDTH 3
`define NTT_OP_WIDTH 3
`define LSU_OP_WIDTH 2
`define RW_EN_WIDTH 1
`define SCALAR_WIDTH 64
`define LANE_DATA_WIDTH 64
`define CNT_WIDTH `max($clog2(`SYS_VLMAX / `LANE_DATA_WIDTH / `SYS_NUM_LANE), ($clog2($clog2(`SYS_VLMAX / `LANE_DATA_WIDTH)) + $clog2(`SYS_VLMAX / `LANE_DATA_WIDTH / 2 / (`SYS_NUM_LANE / 2))))
`define TF_ITEM_NUM 3
`define TF_ADDR_WIDTH ($clog2(`SYS_VLMAX / `LANE_DATA_WIDTH) - $clog2(`SYS_NUM_LANE / 2) + 1 + 1 + $clog2(TF_ITEM_NUM))//ntt and intt tf

// Delay params
/*`define COMMON_VMU_DELAY  12       // delay of VMU
`define COMMON_AGEN_DELAY 1       // delay of Gen address
`define COMMON_MEMR_DELAY 2       // Memory read cycles, i.e., SPM
`define COMMON_MEMW_DELAY 1       // Memory write cycles, i.e., SPM*/

// Do NOT change the params below this line
// ----------------------------------------
`define PC_STATE_WIDTH 2
`define ISSUE_STATE_WIDTH 3
`define VP_OPQ_DELAY 0

`define VXU_PIPELINE_LENGTH 19

`define ISSUE_SYNC_DELAY (`VXU_PIPELINE_LENGTH - 1)
`define ISSUE_CONFIG_SYNC_DELAY 4
