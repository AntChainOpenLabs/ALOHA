//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: 
// Module Name: vmu_top
// Modify Date: 

// Description:
// Data load store

// MODULE_DELAY: 
// MIN:             x
// Recommended:     `COMMON_VXU_DELAY
//////////////////////////////////////////////////

`include "vp_defines.vh"
`include "common_defines.vh"

module vmu_top#(
    parameter CONFIG_OP_WIDTH   = `CONFIG_OP_WIDTH,
    parameter LSU_OP_WIDTH      = `LSU_OP_WIDTH,
    parameter SCALAR_WIDTH      = `SCALAR_WIDTH,
    localparam CNT_WIDTH        = `CNT_WIDTH,
    parameter COMMON_AGEN_DELAY = `COMMON_AGEN_DELAY,
    parameter COMMON_MEMR_DELAY = `COMMON_MEMR_DELAY,
    parameter COMMON_MEMW_DELAY = `COMMON_MEMW_DELAY,
    parameter COMMON_VMU_DELAY  = `COMMON_VMU_DELAY
)(
    input                                               clk,
    input                                               rst_n,
    // from/to SEQ      
    input                                               i_seq_vmu_op_vld,
    input    [CNT_WIDTH-1:0]     i_seq_vmu_cnt,
    input    [LSU_OP_WIDTH-1:0]                         i_seq_vmu_op_ls     [0:`SYS_NUM_LSU-1],
    input    [SCALAR_WIDTH-1:0]                         i_seq_vmu_scalar_ls [0:`SYS_NUM_LSU-1],
    input    [CONFIG_OP_WIDTH-1:0]                      i_seq_vmu_op_config,
    input    [SCALAR_WIDTH-1:0]                         i_seq_vmu_scalar_config,

    // from/to SPM
    output                                              o_vmu_spm_rden      [0:`SYS_NUM_LSU-1],
    output                                              o_vmu_spm_wren      [0:`SYS_NUM_LSU-1],
    output   [SCALAR_WIDTH-1:0]                         o_vmu_spm_rdaddr    [0:`SYS_NUM_LSU-1],
    output   [SCALAR_WIDTH-1:0]                         o_vmu_spm_wraddr    [0:`SYS_NUM_LSU-1]
);

/* Local params */
// Local opcode
localparam OP_CONFIG_NONE       = `CONFIG_OP_WIDTH'b00;
localparam OP_CONFIG_VLEN       = `CONFIG_OP_WIDTH'b01;
localparam OP_CONFIG_MODQ       = `CONFIG_OP_WIDTH'b10;
localparam OP_CONFIG_MODIQ      = `CONFIG_OP_WIDTH'b11;
// Local FSM states
localparam VMU_IDLE             = 'b00; // $clog2(`VMU_NUM_STATES)
localparam VMU_CONFIG           = 'b01; // $clog2(`VMU_NUM_STATES)
localparam VMU_BUSY             = 'b10; // $clog2(`VMU_NUM_STATES)
localparam VMU_END              = 'b11; // $clog2(`VMU_NUM_STATES)

/* Internal logic */
reg [$clog2(`VMU_NUM_STATES)-1:0] cur_state;
reg [$clog2(`VMU_NUM_STATES)-1:0] nxt_state;

// CSR
reg   [SCALAR_WIDTH-1:0]          HERV_VLEN_REG;
reg   [SCALAR_WIDTH-1:0]          HERV_MODQ_REG;
reg   [SCALAR_WIDTH-1:0]          HERV_MODIQ_REG;

// internal regs
reg   [LSU_OP_WIDTH-1:0]          seq_vmu_op_ls_r     [0:`SYS_NUM_LSU-1];
reg   [SCALAR_WIDTH-1:0]          seq_vmu_scalar_ls_r [0:`SYS_NUM_LSU-1];
// internal wires
wire  [LSU_OP_WIDTH-1:0]          seq_vmu_op_ls_w     [0:`SYS_NUM_LSU-1];
wire  [SCALAR_WIDTH-1:0]          seq_vmu_scalar_ls_w [0:`SYS_NUM_LSU-1];

/* FSM */
// state trans
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cur_state <= 'b00; // $clog2(`VMU_NUM_STATES)
    end
    else begin
        cur_state <= nxt_state;
    end
end

// next state
always @(*) begin   
    case (cur_state)
        VMU_IDLE: begin                                         // IDLE
            if(i_seq_vmu_op_vld) begin
                case (i_seq_vmu_op_config)
                    OP_CONFIG_NONE: nxt_state = VMU_BUSY;       // load/store state
                    default:        nxt_state = VMU_CONFIG;     // config state
                endcase
            end
            else
                nxt_state = VMU_IDLE;
        end 
        VMU_CONFIG: begin                                       // CONFIG, same as IDLE
            if(i_seq_vmu_op_vld) begin
                case (i_seq_vmu_op_config)
                    OP_CONFIG_NONE: nxt_state = VMU_BUSY;
                    default:        nxt_state = VMU_CONFIG;
                endcase
            end
            else
                nxt_state = VMU_IDLE;
        end 
        VMU_BUSY: begin                                         // BUSY at load/store, etc.
            if(i_seq_vmu_op_vld) begin
                case (i_seq_vmu_op_config)
                    OP_CONFIG_NONE: nxt_state = VMU_BUSY;
                    default:        nxt_state = VMU_CONFIG;
                endcase
            end
            else begin
                case (i_seq_vmu_cnt == (HERV_VLEN_REG[$clog2(`SYS_VLMAX)+$clog2(`LANE_DATA_WIDTH):$clog2(`SYS_NUM_LANE)+$clog2(`LANE_DATA_WIDTH)])-1)
                    1'b0:           nxt_state = VMU_BUSY;       // Keep busy util finish this inst
                    1'b1:           nxt_state = VMU_END;
                    default:        nxt_state = VMU_END;
                endcase
            end
        end 
        VMU_END: begin
            nxt_state = VMU_IDLE;
        end
        default: nxt_state = VMU_IDLE;
    endcase
end

// behavior output
always @(posedge clk) begin 
if(!rst_n) begin                                                // RESET CSRs
        HERV_VLEN_REG   <= `SCALAR_WIDTH'd1024;
        HERV_MODQ_REG   <= `SCALAR_WIDTH'b1;
        HERV_MODIQ_REG  <= `SCALAR_WIDTH'b1;
    end
    else begin
        case(nxt_state)
            VMU_CONFIG: begin
            case (i_seq_vmu_op_config)                          // set CSRs
                    OP_CONFIG_VLEN : HERV_VLEN_REG  <= i_seq_vmu_scalar_config;
                    OP_CONFIG_MODQ : HERV_MODQ_REG  <= i_seq_vmu_scalar_config;
                    OP_CONFIG_MODIQ: HERV_MODIQ_REG <= i_seq_vmu_scalar_config;
                    default        : ;
                endcase
            end
            default: begin                                      // keep
                HERV_VLEN_REG   <= HERV_VLEN_REG ;
                HERV_MODQ_REG   <= HERV_MODQ_REG ;
                HERV_MODIQ_REG  <= HERV_MODIQ_REG;
            end
        endcase
    end
end

//seq_vmu_op_ls_r, seq_vmu_scalar_ls_r
genvar index_lsu_reg;
generate
    for (index_lsu_reg = 0; index_lsu_reg < `SYS_NUM_LSU; index_lsu_reg = index_lsu_reg + 1) begin // # SYS_NUM_LSU
        
        always @(posedge clk or negedge rst_n) begin 
        if(!rst_n) begin                                                // RESET opcode REGs
                seq_vmu_op_ls_r[index_lsu_reg]         <= 0;
                seq_vmu_scalar_ls_r[index_lsu_reg]     <= 0;
            end
            else begin
                case(nxt_state)
                    VMU_BUSY: begin
                        case (i_seq_vmu_op_vld)                         // set opcode REGs
                            1 : begin
                                seq_vmu_op_ls_r[index_lsu_reg]        <= i_seq_vmu_op_ls[index_lsu_reg];
                                seq_vmu_scalar_ls_r[index_lsu_reg]    <= i_seq_vmu_scalar_ls[index_lsu_reg];
                            end
                            0 : begin
                                seq_vmu_op_ls_r[index_lsu_reg]        <= seq_vmu_op_ls_r[index_lsu_reg];
                                seq_vmu_scalar_ls_r[index_lsu_reg]    <= seq_vmu_scalar_ls_r[index_lsu_reg];
                            end
                            default : begin
                                seq_vmu_op_ls_r[index_lsu_reg]        <= seq_vmu_op_ls_r[index_lsu_reg];
                                seq_vmu_scalar_ls_r[index_lsu_reg]    <= seq_vmu_scalar_ls_r[index_lsu_reg];
                            end
                        endcase
                    end
                    default: begin                                      // clear
                        seq_vmu_op_ls_r[index_lsu_reg]                <= 0;
                        seq_vmu_scalar_ls_r[index_lsu_reg]            <= 0;
                    end
                endcase
            end
        end
    end
endgenerate

/* LSU */
wire i_ls_vld;
assign i_ls_vld = (nxt_state == VMU_BUSY) || (nxt_state == VMU_END);

genvar index_lsu;
generate
    for (index_lsu = 0; index_lsu < `SYS_NUM_LSU; index_lsu = index_lsu + 1) begin // # SYS_NUM_LSU
    
        assign seq_vmu_op_ls_w[index_lsu] = i_seq_vmu_op_vld? i_seq_vmu_op_ls[index_lsu] : seq_vmu_op_ls_r[index_lsu]; 
        assign seq_vmu_scalar_ls_w[index_lsu] = i_seq_vmu_op_vld? i_seq_vmu_scalar_ls[index_lsu] : seq_vmu_scalar_ls_r[index_lsu]; 
        
        lsu_top #(
          .LSU_OP_WIDTH(LSU_OP_WIDTH),
          .SCALAR_WIDTH(SCALAR_WIDTH),
          .COMMON_AGEN_DELAY(COMMON_AGEN_DELAY),
          .COMMON_MEMR_DELAY(COMMON_MEMR_DELAY),
          .COMMON_MEMW_DELAY(COMMON_MEMW_DELAY),
          .COMMON_VMU_DELAY (COMMON_VMU_DELAY)
        )
        lsu_top_unit (
          .clk                  (clk),
          .rst_n                (rst_n),
          .i_ls_vld             (i_ls_vld),
          .i_seq_vmu_cnt        (i_seq_vmu_cnt),
          .i_seq_vmu_op_ls      (seq_vmu_op_ls_w[index_lsu]),
          .i_seq_vmu_scalar_ls  (seq_vmu_scalar_ls_w[index_lsu]),
          .o_vmu_spm_rden       (o_vmu_spm_rden[index_lsu]),
          .o_vmu_spm_wren       (o_vmu_spm_wren[index_lsu]),
          .o_vmu_spm_rdaddr     (o_vmu_spm_rdaddr[index_lsu]),
          .o_vmu_spm_wraddr     (o_vmu_spm_wraddr[index_lsu])
        );
    end
endgenerate

endmodule