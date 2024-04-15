//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: 
// Module Name: lsu_top
// Modify Date: 

// Description:
// Load store unit
// unit-stride ONLY!

// MODULE_DELAY: 
// MIN:             1
// Recommended:     2
//////////////////////////////////////////////////


`include "common_defines.vh"
`include "vp_defines.vh"

module lsu_top #(
    parameter LSU_OP_WIDTH      = `LSU_OP_WIDTH,
    parameter SCALAR_WIDTH      = `SCALAR_WIDTH,
    localparam CNT_WIDTH        = `CNT_WIDTH,
    parameter COMMON_AGEN_DELAY = `COMMON_AGEN_DELAY,
    parameter COMMON_MEMR_DELAY = `COMMON_MEMR_DELAY,
    parameter COMMON_MEMW_DELAY = `COMMON_MEMW_DELAY,
    parameter COMMON_VMU_DELAY  = `COMMON_VMU_DELAY
) (
    input                                               clk,
    input                                               rst_n,
    // from vmu_top      
    input                                               i_ls_vld,
    input    [CNT_WIDTH-1:0]     i_seq_vmu_cnt,
    input    [LSU_OP_WIDTH-1:0]                         i_seq_vmu_op_ls,
    input    [SCALAR_WIDTH-1:0]                         i_seq_vmu_scalar_ls,
    // to vmu_top
    output                                              o_vmu_spm_rden,
    output                                              o_vmu_spm_wren,
    output   [SCALAR_WIDTH-1:0]                         o_vmu_spm_rdaddr,
    output   [SCALAR_WIDTH-1:0]                         o_vmu_spm_wraddr
    // to vmu_top
);

/* Local state */
localparam OP_VMU_NONE          = `LSU_OP_WIDTH'b00;
localparam OP_VMU_LOAD          = `LSU_OP_WIDTH'b01;
localparam OP_VMU_STORE         = `LSU_OP_WIDTH'b10;

// Delay signal
reg                     vmu_spm_rden;
reg                     vmu_spm_wren;

// Internal signal
wire [SCALAR_WIDTH-1:0] o_scalar_addr;

always @(*) begin 
    case(i_ls_vld)              // set rden/wren
    1'b1: begin
        case (i_seq_vmu_op_ls)  // set CSRs
            OP_VMU_LOAD  :  begin
                            vmu_spm_rden  = `RW_EN_WIDTH'b1;
                            vmu_spm_wren  = `RW_EN_WIDTH'b0;
            end
            OP_VMU_STORE :  begin
                            vmu_spm_rden  = `RW_EN_WIDTH'b0;
                            vmu_spm_wren  = `RW_EN_WIDTH'b1;
            end
            default      :  begin
                            vmu_spm_rden  = `RW_EN_WIDTH'b0;
                            vmu_spm_wren  = `RW_EN_WIDTH'b0;
            end
        endcase
    end
    default: begin    // unable
        vmu_spm_rden  = `RW_EN_WIDTH'b0;
        vmu_spm_wren  = `RW_EN_WIDTH'b0;
    end
    endcase
end

gnrl_dff_r # (
    .DWIDTH(`RW_EN_WIDTH),
    .DEPTH(COMMON_AGEN_DELAY) // start to read delay
) r_agen_dly (
    .clk(clk),
    .rst_n(rst_n),
    .dnxt(vmu_spm_rden),
    .dout(o_vmu_spm_rden)
);

gnrl_dff_r # (
    .DWIDTH(`RW_EN_WIDTH),
    .DEPTH(COMMON_VMU_DELAY-COMMON_MEMW_DELAY) // start to write delay
) w_agen_dly (
    .clk(clk),
    .rst_n(rst_n),
    .dnxt(vmu_spm_wren),
    .dout(o_vmu_spm_wren)
);

addr_gen #(
    .SCALAR_WIDTH(SCALAR_WIDTH),
    .COMMON_AGEN_DELAY(COMMON_AGEN_DELAY)
)
addr_gen_unit (
    .clk(clk),
    .rst_n(rst_n),
//    .i_seq_vmu_op_vld(i_seq_vmu_op_vld),
    .i_seq_vmu_cnt(i_seq_vmu_cnt),
    .i_seq_vmu_scalar(i_seq_vmu_scalar_ls),
    .o_scalar_addr(o_scalar_addr)
);

// Output signal
assign o_vmu_spm_rdaddr = o_scalar_addr;
gnrl_dff # (
    .DWIDTH(SCALAR_WIDTH),
    .DEPTH(COMMON_VMU_DELAY-COMMON_AGEN_DELAY-COMMON_MEMW_DELAY) // start to write delay
) w_vmu_dly (
    .clk(clk),
    .dnxt(o_scalar_addr),
    .dout(o_vmu_spm_wraddr)
);

endmodule