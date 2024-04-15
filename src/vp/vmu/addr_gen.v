//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: 
// Module Name: mvp_top
// Modify Date: 

// Description:
// Load store address generation
// opcode is oblivious to this module

// MODULE_DELAY: 
// MIN:             1
// Recommended:     2
//////////////////////////////////////////////////

`include "common_defines.vh"
`include "vp_defines.vh"
module addr_gen #(
    parameter SCALAR_WIDTH      = `SCALAR_WIDTH,
    localparam CNT_WIDTH        = `CNT_WIDTH,
    parameter COMMON_AGEN_DELAY = `COMMON_AGEN_DELAY
) (
    input                                         clk,
    input                                         rst_n,
    // from vmu_top      
    // input                                         i_seq_vmu_op_vld,
    input  [CNT_WIDTH-1:0] i_seq_vmu_cnt,
    input  [                    SCALAR_WIDTH-1:0] i_seq_vmu_scalar,

    // to vmu_top
    output [                    SCALAR_WIDTH-1:0] o_scalar_addr
);

/* Internal logic */
reg     [SCALAR_WIDTH-1:0] scalar_addr_r;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        scalar_addr_r <= 'b0; // SCALAR_WIDTH
    end
    else begin
        scalar_addr_r <= i_seq_vmu_scalar + (i_seq_vmu_cnt << ($clog2(`SYS_NUM_LANE) + $clog2(`LANE_DATA_WIDTH / 8)));
    end
end

gnrl_dff # (
    .DWIDTH(SCALAR_WIDTH),
    .DEPTH(COMMON_AGEN_DELAY-1)
) agen_dlyy (
    .clk(clk),
    .dnxt(scalar_addr_r),
    .dout(o_scalar_addr)
);
endmodule