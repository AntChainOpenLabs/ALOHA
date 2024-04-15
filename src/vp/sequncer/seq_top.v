//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: 
// Module Name: seq_wrapper
// Modify Date: 

// Description:
// From IF to ISSUE
//////////////////////////////////////////////////

`include "vp_defines.vh"
`include "common_defines.vh"
module seq_top#(
    parameter PC_WIDTH          = `PC_WIDTH         ,

    parameter INST_WIDTH        = `INST_WIDTH       ,
    parameter CONFIG_OP_WIDTH   = `CONFIG_OP_WIDTH  ,
    parameter MUXO_OP_WIDTH     = `MUXO_OP_WIDTH    ,
    parameter MUXI_OP_WIDTH     = `MUXI_OP_WIDTH    ,
    parameter RW_OP_WIDTH       = `RW_OP_WIDTH      ,     // address + enable
    parameter ALU_OP_WIDTH      = `ALU_OP_WIDTH     ,
    parameter ICONN_OP_WIDTH    = `ICONN_OP_WIDTH   ,
    parameter NTT_OP_WIDTH      = `NTT_OP_WIDTH     ,
    parameter LSU_OP_WIDTH      = `LSU_OP_WIDTH     ,
    parameter SCALAR_WIDTH      = `SCALAR_WIDTH     ,
    localparam CNT_WIDTH        = `CNT_WIDTH        ,

    parameter IQUEUE_DEPTH      = `IQUEUE_DEPTH     ,
    parameter OPQUEUE_DEPTH     = `OPQUEUE_DEPTH    ,
    parameter COMMON_BRAM_DELAY = `COMMON_BRAM_DELAY
)(
    input                                             clk,
    input                                             rst_n,
    // to control & status register           
    input                                             i_sys_start,
    output                                            o_sys_done,
    // to instructuion RAM, no hsk            
    input                                             i_seq_inst_vld,   // RAM delay of o_seq_pc_vld
    input    [INST_WIDTH-1:0]                         i_seq_inst,
    output                                            o_seq_pc_vld,
    output   [$clog2(`IRAM_DEPTH)-1:0]                o_seq_pc_offset,
    // to VXU. no hsk, since seq monitor and control VXU/VMU
    output                                            o_seq_vxu_issue_vld,  // vld is a pulse
    output   [CONFIG_OP_WIDTH-1:0]                    o_seq_vxu_op_config,
    output   [SCALAR_WIDTH-1:0]                       o_seq_vxu_scalar_config,
    output   [RW_OP_WIDTH-1:0]                        o_seq_vxu_op_b0r,
    output   [RW_OP_WIDTH-1:0]                        o_seq_vxu_op_b0w,
    output   [RW_OP_WIDTH-1:0]                        o_seq_vxu_op_b1r,
    output   [RW_OP_WIDTH-1:0]                        o_seq_vxu_op_b1w,
    output   [ALU_OP_WIDTH-1:0]                       o_seq_vxu_op_alu,
    output   [SCALAR_WIDTH-1:0]                       o_seq_vxu_scalar_alu,
    output   [ICONN_OP_WIDTH-1:0]                     o_seq_vxu_op_iconn,
    output   [SCALAR_WIDTH-1:0]                       o_seq_vxu_scalar_iconn,
    output   [NTT_OP_WIDTH-1:0]                       o_seq_vxu_op_ntt,
    output   [MUXO_OP_WIDTH-1:0]                      o_seq_vxu_op_muxo,
    output   [MUXI_OP_WIDTH-1:0]                      o_seq_vxu_op_muxi,
    // to VMU
    output                                            o_seq_vmu_issue_vld,  // vld is a pulse
    output   [CONFIG_OP_WIDTH-1:0]                    o_seq_vmu_op_config,
    output   [SCALAR_WIDTH-1:0]                       o_seq_vmu_scalar_config,
    output   [LSU_OP_WIDTH-1:0]                       o_seq_vmu_op_ls,
    output   [SCALAR_WIDTH-1:0]                       o_seq_vmu_scalar_ls,
    // global counter
    output   [CNT_WIDTH-1:0]                          o_seq_cnt,
    output                                            o_seq_comp_vld,
    // from ntt_fsm
    input    [CNT_WIDTH:0]                            i_ntt_inst_std_cnt,
    input    logic[SCALAR_WIDTH - 1:0]                i_csr_vp_step
);

/* Local params */
// PC state
localparam PC_RESET             = `PC_STATE_WIDTH'b00;
localparam PC_HOLD              = `PC_STATE_WIDTH'b01;
localparam PC_INCR              = `PC_STATE_WIDTH'b10;
localparam PC_DRAIN             = `PC_STATE_WIDTH'b11;

// ISSUE state
localparam IS_IDLE              = `ISSUE_STATE_WIDTH'b00;
localparam IS_CONFIG            = `ISSUE_STATE_WIDTH'b01;
localparam IS_EMIT              = `ISSUE_STATE_WIDTH'b10;
localparam IS_WAIT              = `ISSUE_STATE_WIDTH'b11;
localparam IS_SYNC              = `ISSUE_STATE_WIDTH'b100;
localparam IS_CONFIG_SYNC       = `ISSUE_STATE_WIDTH'b101;

localparam OP_CONFIG_NONE       = `CONFIG_OP_WIDTH'b00;
localparam OP_CONFIG_VLEN       = `CONFIG_OP_WIDTH'b01;

// CSR
reg     [SCALAR_WIDTH-1:0]                       HERV_VLEN_REG;

/* internal logic */
// pc
reg     [`PC_STATE_WIDTH-1:0]                    pc_cur_state;
reg     [`PC_STATE_WIDTH-1:0]                    pc_nxt_state;
//reg                                              o_seq_pc_vld_nxt;
//reg     [$clog2(`IRAM_DEPTH)-1:0]                o_seq_pc_offset_nxt;
// Queue signal
wire                                             iqueue_empty;
wire                                             iqueue_afull;
wire                                             iqueue_pop_vld;
wire                                             iqueue_pop_vld_delay;
wire                                             opqueue_empty;
wire                                             opqueue_afull;
// iqueue <-> expander
wire                                             iqueue_expander_vld;
wire    [INST_WIDTH-1:0]                         iqueue_expander_inst;
wire                                             expander_pc_break;
// expander <-> opqueue
wire                                             opq_push_vld;
reg                                              opq_pop_vld;
// issue monitor
reg     [`ISSUE_STATE_WIDTH-1:0]                 is_cur_state;
reg     [`ISSUE_STATE_WIDTH-1:0]                 is_nxt_state;
// wire                                             seq_pre_done;            // ISSUE FSM flag
// reg                                              seq_inst_done;
reg     [CNT_WIDTH-1:0]                          seq_cnt_r;
reg                                              seq_comp_vld_r;
wire    [CNT_WIDTH  :0]                          inst_std_cnt;
reg     [CNT_WIDTH  :0]                          inst_std_cnt_r;

/* output regs */
// State
reg                                              o_sys_done_r;
// to IRAM           
reg                                              o_seq_pc_vld_r;
reg  [$clog2(`IRAM_DEPTH)-1:0]                   o_seq_pc_offset_r;

// to VXU/VMU            
wire                                             o_seq_issue_vld;

// decode to opq
wire  [CONFIG_OP_WIDTH-1:0]                      dec_opq_op_config;
wire  [SCALAR_WIDTH-1:0]                         dec_opq_scalar_config;
wire  [RW_OP_WIDTH-1:0]                          dec_opq_op_b0r;
wire  [RW_OP_WIDTH-1:0]                          dec_opq_op_b0w;
wire  [RW_OP_WIDTH-1:0]                          dec_opq_op_b1r;
wire  [RW_OP_WIDTH-1:0]                          dec_opq_op_b1w;
wire  [ALU_OP_WIDTH-1:0]                         dec_opq_op_alu;
wire  [SCALAR_WIDTH-1:0]                         dec_opq_scalar_alu;
wire  [ICONN_OP_WIDTH-1:0]                       dec_opq_op_iconn;
wire  [SCALAR_WIDTH-1:0]                         dec_opq_scalar_iconn;
wire  [NTT_OP_WIDTH-1:0]                         dec_opq_op_ntt;
wire  [MUXO_OP_WIDTH-1:0]                        dec_opq_op_muxo;
wire  [MUXI_OP_WIDTH-1:0]                        dec_opq_op_muxi;
wire  [LSU_OP_WIDTH-1:0]                         dec_opq_op_ls;
wire  [SCALAR_WIDTH-1:0]                         dec_opq_scalar_ls;
// opq to output
wire  [CONFIG_OP_WIDTH-1:0]                      opq_vxu_op_config;
wire  [SCALAR_WIDTH-1:0]                         opq_vxu_scalar_config;
wire  [RW_OP_WIDTH-1:0]                          opq_vxu_op_b0r;
wire  [RW_OP_WIDTH-1:0]                          opq_vxu_op_b0w;
wire  [RW_OP_WIDTH-1:0]                          opq_vxu_op_b1r;
wire  [RW_OP_WIDTH-1:0]                          opq_vxu_op_b1w;
wire  [ALU_OP_WIDTH-1:0]                         opq_vxu_op_alu;
wire  [SCALAR_WIDTH-1:0]                         opq_vxu_scalar_alu;
wire  [ICONN_OP_WIDTH-1:0]                       opq_vxu_op_iconn;
wire  [SCALAR_WIDTH-1:0]                         opq_vxu_scalar_iconn;
wire  [NTT_OP_WIDTH-1:0]                         opq_vxu_op_ntt;
wire  [MUXO_OP_WIDTH-1:0]                        opq_vxu_op_muxo;
wire  [MUXI_OP_WIDTH-1:0]                        opq_vxu_op_muxi;
wire  [LSU_OP_WIDTH-1:0]                         opq_vmu_op_ls;
wire  [SCALAR_WIDTH-1:0]                         opq_vmu_scalar_ls;


/* I_Fetch stage */
// I_Fetch & PC offset
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pc_cur_state      <= PC_RESET;
    end else begin
        pc_cur_state      <= pc_nxt_state;
    end
end

// next state
always @(*) begin   
    case (pc_cur_state)
        PC_RESET: begin
            if (i_sys_start) begin
                pc_nxt_state = PC_INCR;
            end
            else begin
                pc_nxt_state = PC_RESET;
            end
        end
        PC_HOLD: begin
            if (expander_pc_break) begin    // stop IF, e.g., expander decode a system break instruction
                pc_nxt_state = PC_DRAIN;
            end
            else if(!iqueue_afull) begin    // If IQueue is not full, it tries to fetch a new instruction
                pc_nxt_state = PC_INCR;
            end
            else begin
                pc_nxt_state = PC_HOLD;
            end
        end
        PC_INCR: begin
            if (expander_pc_break) begin
                pc_nxt_state = PC_DRAIN;
            end
            else if(iqueue_afull) begin
                pc_nxt_state = PC_HOLD;
            end
            else begin
                pc_nxt_state = PC_INCR;
            end
        end
        PC_DRAIN: begin                     // remember to drain iqueue
            if (iqueue_empty) begin
                pc_nxt_state = PC_RESET;
            end
            else begin
                pc_nxt_state = PC_DRAIN;
            end
        end
        default: pc_nxt_state = PC_RESET;
    endcase
end

// behavior output
// config o_seq_pc_vld_r & o_seq_pc_offset_r
always @(posedge clk) begin 
    case (pc_nxt_state)
        PC_RESET: begin
            o_seq_pc_vld_r      <= 0;
            o_seq_pc_offset_r   <= -1;  // the first vld offset is 0
        end
        PC_HOLD: begin
            o_seq_pc_vld_r      <= 0;
            o_seq_pc_offset_r   <= o_seq_pc_offset_r;
        end
        PC_INCR: begin
            o_seq_pc_vld_r      <= 1;
            o_seq_pc_offset_r   <= o_seq_pc_offset_r + 1;
        end
        PC_DRAIN: begin
            o_seq_pc_vld_r      <= 0;
            o_seq_pc_offset_r   <= -1;
        end
        default: begin
            o_seq_pc_vld_r      <= 0;
            o_seq_pc_offset_r   <= -1;
        end
    endcase
end

// iqueue_pop_vld
// IQueue pop, if IQueue not empty & Opqueue not afull
// pop is forword to opqueue if NOT in PC_DRAIN
assign iqueue_pop_vld = !iqueue_empty & !opqueue_afull;

queue_wrapper #(
    .DWIDTH            (INST_WIDTH),
    .AWIDTH            ($clog2(`IQUEUE_DEPTH)),
    .COMMON_BRAM_DELAY (`COMMON_BRAM_DELAY)
) vp_seq_inst_queue(
    .clk                 (clk                    ),
    .rst_n               (rst_n                  ),
    .i_push              (i_seq_inst_vld         ),
    .i_data              (i_seq_inst             ),
    .i_pop               (iqueue_pop_vld         ),
    .o_data              (iqueue_expander_inst   ),
    .o_empty             (iqueue_empty           ),
    .o_afull             (iqueue_afull           )
);

/* Decode */
gnrl_dff_r #(1,`COMMON_BRAM_DELAY) iqueue_expander_dff (clk, rst_n, iqueue_pop_vld, iqueue_pop_vld_delay);
assign iqueue_expander_vld = iqueue_pop_vld_delay & !(pc_nxt_state == PC_RESET) & !(pc_nxt_state == PC_DRAIN);

expander decode_exp (
    .clk                (clk                    ),
    .rst_n              (rst_n                  ),
    .i_decode_en        (iqueue_expander_vld    ),
    .i_inst             (iqueue_expander_inst   ),
    .o_decode_en        (dec_opq_vld            ),
    .o_expander_break   (expander_pc_break      ),
    .o_op_config        (dec_opq_op_config      ),
    .o_scalar_config    (dec_opq_scalar_config  ),
    .o_op_b0r           (dec_opq_op_b0r         ),
    .o_op_b0w           (dec_opq_op_b0w         ),
    .o_op_b1r           (dec_opq_op_b1r         ),
    .o_op_b1w           (dec_opq_op_b1w         ),
    .o_op_alu           (dec_opq_op_alu         ),
    .o_scalar_alu       (dec_opq_scalar_alu     ),
    .o_op_iconn         (dec_opq_op_iconn       ),
    .o_scalar_iconn     (dec_opq_scalar_iconn   ),
    .o_op_ntt           (dec_opq_op_ntt         ),
    .o_op_muxo          (dec_opq_op_muxo        ),
    .o_op_muxi          (dec_opq_op_muxi        ),
    .o_op_ls            (dec_opq_op_ls          ),
    .o_scalar_ls        (dec_opq_scalar_ls      ),
    .i_csr_vp_step      (i_csr_vp_step)
);

assign opq_push_vld = dec_opq_vld; // & !expander_pc_break 

op_queues #(
    .COMMON_BRAM_DELAY  (`VP_OPQ_DELAY           )
) vp_seq_opcode_queue (
    .clk                (clk                     ),
    .rst_n              (rst_n                   ),
    .i_push             (opq_push_vld            ),
    .i_op_config        (dec_opq_op_config       ),
    .i_scalar_config    (dec_opq_scalar_config   ),
    .i_op_b0r           (dec_opq_op_b0r          ),
    .i_op_b0w           (dec_opq_op_b0w          ),
    .i_op_b1r           (dec_opq_op_b1r          ),
    .i_op_b1w           (dec_opq_op_b1w          ),
    .i_op_alu           (dec_opq_op_alu          ),
    .i_scalar_alu       (dec_opq_scalar_alu      ),
    .i_op_iconn         (dec_opq_op_iconn        ),
    .i_scalar_iconn     (dec_opq_scalar_iconn    ),
    .i_op_ntt           (dec_opq_op_ntt          ),
    .i_op_muxo          (dec_opq_op_muxo         ),
    .i_op_muxi          (dec_opq_op_muxi         ),
    .i_op_ls            (dec_opq_op_ls           ),
    .i_scalar_ls        (dec_opq_scalar_ls       ),
    .i_pop              (opq_pop_vld             ),
    .o_op_config        (opq_vxu_op_config       ),
    .o_scalar_config    (opq_vxu_scalar_config   ),
    .o_op_b0r           (opq_vxu_op_b0r          ),
    .o_op_b0w           (opq_vxu_op_b0w          ),
    .o_op_b1r           (opq_vxu_op_b1r          ),
    .o_op_b1w           (opq_vxu_op_b1w          ),
    .o_op_alu           (opq_vxu_op_alu          ),
    .o_scalar_alu       (opq_vxu_scalar_alu      ),
    .o_op_iconn         (opq_vxu_op_iconn        ),
    .o_scalar_iconn     (opq_vxu_scalar_iconn    ),
    .o_op_ntt           (opq_vxu_op_ntt          ),
    .o_op_muxo          (opq_vxu_op_muxo         ),
    .o_op_muxi          (opq_vxu_op_muxi         ),
    .o_op_ls            (opq_vmu_op_ls           ),
    .o_scalar_ls        (opq_vmu_scalar_ls       ),
    .o_empty            (opqueue_empty           ),
    .o_afull            (opqueue_afull           )
);

/* ISSUE stage */
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        is_cur_state      <= IS_IDLE;
    end else begin
        is_cur_state      <= is_nxt_state;
    end
end

// next state IS_CONFIG
always @(*) begin
    case (is_cur_state)
        IS_IDLE: begin
            if (!opqueue_empty) begin
                case (opq_vxu_op_config)
                    OP_CONFIG_NONE: is_nxt_state = IS_EMIT;
                    default: is_nxt_state = IS_CONFIG;
                endcase
            end
            else begin
                is_nxt_state = IS_IDLE;
            end
        end
        IS_CONFIG: begin    // same as IS_IDLE
            is_nxt_state = IS_CONFIG_SYNC;
        end
        IS_EMIT: begin
            is_nxt_state = IS_WAIT;
        end
        IS_WAIT: begin
            if (seq_cnt_r == 0) begin   // (inst_std_cnt - `VP_OPQ_DELAY)
                is_nxt_state = IS_SYNC;
            end
            else begin
                is_nxt_state = IS_WAIT;
            end
        end
        IS_SYNC: begin
            if (seq_cnt_r == 0) begin
                if (!opqueue_empty) begin
                    case (opq_vxu_op_config)
                        OP_CONFIG_NONE: is_nxt_state = IS_EMIT;
                        default: is_nxt_state = IS_CONFIG;
                    endcase
                end
                else begin  // inst done
                    is_nxt_state = IS_IDLE;
                end
            end
            else begin
                is_nxt_state = IS_SYNC;
            end
        end
        IS_CONFIG_SYNC: begin
           if (seq_cnt_r == 0) begin
                if (!opqueue_empty) begin
                    case (opq_vxu_op_config)
                        OP_CONFIG_NONE: is_nxt_state = IS_EMIT;
                        default: is_nxt_state = IS_CONFIG;
                    endcase
                end
                else begin  // inst done
                    is_nxt_state = IS_IDLE;
                end
            end
            else begin
                is_nxt_state = IS_CONFIG_SYNC;
            end
        end
        default: is_nxt_state = IS_IDLE;
    endcase
end

// behavior output
// HERV_VLEN_REG
always @(posedge clk) begin 
    case (is_nxt_state)
        IS_CONFIG: begin
            if(opq_vxu_op_config==OP_CONFIG_VLEN)
                HERV_VLEN_REG      <= opq_vxu_scalar_config;
            else
                HERV_VLEN_REG      <= HERV_VLEN_REG;
        end
        default: begin
            HERV_VLEN_REG      <= HERV_VLEN_REG;
        end
    endcase
end

// opq_pop_vld, o_seq_comp_vld
// o_seq_comp_vld for vxu, when o_seq_comp_vld == 1，cnt is valid； if cnt == 0，then issue opcode is valid，issue opcode invalid otherwise.
always @(*) begin 
    case (is_nxt_state)
        IS_IDLE: begin
            opq_pop_vld       = 0;
            seq_comp_vld_r    = 0;
        end
        IS_CONFIG: begin
            opq_pop_vld       = 1;
            seq_comp_vld_r    = 1;
        end
        IS_EMIT: begin
            opq_pop_vld       = 1;
            seq_comp_vld_r    = 1;
        end
        IS_WAIT: begin
            opq_pop_vld       = 0;
            seq_comp_vld_r    = 1;
        end
        IS_SYNC: begin
            opq_pop_vld       = 0;
            seq_comp_vld_r    = 0;
        end
        IS_CONFIG_SYNC: begin
            opq_pop_vld       = 0;
            seq_comp_vld_r    = 0;
        end
        default: begin
            opq_pop_vld       = 0;
            seq_comp_vld_r    = 0;
        end
    endcase
end

// seq_cnt_r
always @(posedge clk) begin 
    if(!rst_n) begin
        seq_cnt_r <= 0;
        inst_std_cnt_r <= 0;
    end
    else begin
        case (is_nxt_state)
            IS_IDLE: begin
                seq_cnt_r      <= 0;
                inst_std_cnt_r <= 0;
            end
            IS_CONFIG: begin
                seq_cnt_r      <= 0;
                inst_std_cnt_r <= 0;
            end
            IS_EMIT: begin
                seq_cnt_r      <= seq_cnt_r + 1;            // reset
                inst_std_cnt_r <= inst_std_cnt;
            end
            IS_WAIT: begin
                if (seq_cnt_r == (inst_std_cnt_r - 1)) begin
                    seq_cnt_r      <= 0;
                end else begin
                    seq_cnt_r      <= seq_cnt_r + 1;
                end
            end
            IS_SYNC: begin
                if (seq_cnt_r == (`ISSUE_SYNC_DELAY - `VP_OPQ_DELAY - 1)) begin
                    seq_cnt_r     <= 0;
                end else begin
                    seq_cnt_r     <= seq_cnt_r + 1;
                end
            end
            IS_CONFIG_SYNC: begin
                if (seq_cnt_r == (`ISSUE_CONFIG_SYNC_DELAY - `VP_OPQ_DELAY - 1)) begin
                    seq_cnt_r     <= 0;
                end else begin
                    seq_cnt_r     <= seq_cnt_r + 1;
                end
            end
            default: begin
                seq_cnt_r      <= 0;
                inst_std_cnt_r <= 0;
            end
        endcase
    end
end

// TODO
assign inst_std_cnt     = (o_seq_vxu_op_ntt!=0)? i_ntt_inst_std_cnt : HERV_VLEN_REG[$clog2(`SYS_VLMAX)+$clog2(`LANE_DATA_WIDTH):$clog2(`SYS_NUM_LANE)+$clog2(`LANE_DATA_WIDTH)]; // >> $clog2(SYS_NUM_LANE);
// assign opq_pop_vld      = seq_inst_done & !opqueue_empty;
assign o_seq_issue_vld  = opq_pop_vld;

//always @(posedge clk) begin
//    if(!rst_n)
//        seq_cnt_r <= 0;
//    else begin
//        if(seq_cnt_r == inst_std_cnt-1)         //clear
//            seq_cnt_r <= 0;
//        else
//            seq_cnt_r <= seq_cnt_r+1;
//    end
//end

// assign the output ports
always @(posedge clk) begin
    if(!rst_n) begin
        o_sys_done_r <= 0;
    end
    else begin
        if(o_sys_done_r == 1 && i_sys_start == 1)
            o_sys_done_r <= 0;
        else if (opqueue_empty == 1 && seq_cnt_r == (inst_std_cnt - `VP_OPQ_DELAY - 1)) begin  // pc_cur_state == PC_RESET && is_cur_state == IS_IDLE
            o_sys_done_r <= 1;
        end
    end
end

assign o_sys_done               = o_sys_done_r;

assign o_seq_pc_vld             = o_seq_pc_vld_r;
assign o_seq_pc_offset          = o_seq_pc_offset_r;

assign o_seq_vxu_issue_vld      = o_seq_issue_vld;
assign o_seq_vxu_op_config      = opq_vxu_op_config;
assign o_seq_vxu_scalar_config  = opq_vxu_scalar_config;
assign o_seq_vxu_op_b0r         = opq_vxu_op_b0r;
assign o_seq_vxu_op_b0w         = opq_vxu_op_b0w;
assign o_seq_vxu_op_b1r         = opq_vxu_op_b1r;
assign o_seq_vxu_op_b1w         = opq_vxu_op_b1w;
assign o_seq_vxu_op_alu         = opq_vxu_op_alu;
assign o_seq_vxu_scalar_alu     = opq_vxu_scalar_alu;
assign o_seq_vxu_op_iconn       = opq_vxu_op_iconn;
assign o_seq_vxu_scalar_iconn   = opq_vxu_scalar_iconn;
assign o_seq_vxu_op_ntt         = opq_vxu_op_ntt;
assign o_seq_vxu_op_muxo        = opq_vxu_op_muxo;
assign o_seq_vxu_op_muxi        = opq_vxu_op_muxi;

assign o_seq_vmu_issue_vld      = o_seq_issue_vld;
assign o_seq_vmu_op_config      = opq_vxu_op_config;
assign o_seq_vmu_scalar_config  = opq_vxu_scalar_config;
assign o_seq_vmu_op_ls          = opq_vmu_op_ls;
assign o_seq_vmu_scalar_ls      = opq_vmu_scalar_ls;

assign o_seq_cnt                = seq_cnt_r;
assign o_seq_comp_vld           = seq_comp_vld_r;

endmodule