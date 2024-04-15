//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: VP
// Module Name: vxu_top
// Modify Date: 
//
// Description:
// Vector Processing Unit Top
//////////////////////////////////////////////////
`include "vp_defines.vh"
`include "common_defines.vh"

module vp_top_full#(
        parameter ISRAM_FILE = "",
        parameter TF_ROM_FILE = ""
    )(
        input logic clk,
        input logic rst_n,
        input logic i_start_vp,
        output logic o_done_vp,

        output logic o_vp_rden,
        output logic o_vp_wren,
        output logic[`SYS_SPM_ADDR_WIDTH - 1:0] o_vp_rdaddr,
        output logic[`SYS_SPM_ADDR_WIDTH - 1:0] o_vp_wraddr,
        input logic[`SYS_NUM_LANE * `LANE_DATA_WIDTH - 1:0] i_vp_data,
        output logic[`SYS_NUM_LANE * `LANE_DATA_WIDTH - 1:0] o_vp_data,

        output logic o_vp_ksk_rden,
        output logic[`SYS_KSK_ADDR_WIDTH - 1:0] o_vp_ksk_rdaddr,
        input logic[`SYS_NUM_LANE * `LANE_DATA_WIDTH - 1:0] i_vp_ksk_data,

        input logic[`SCALAR_WIDTH - 1:0] i_csr_vp_src0_ptr,
        input logic[`SCALAR_WIDTH - 1:0] i_csr_vp_src1_ptr,
        input logic[`SCALAR_WIDTH - 1:0] i_csr_vp_rslt_ptr,
        input logic[`SCALAR_WIDTH - 1:0] i_csr_vp_step,
        input logic[`SCALAR_WIDTH - 1:0] i_csr_vp_ksk_ptr,
        input logic[`SCALAR_WIDTH - 1:0] i_csr_vp_pc
    );

    logic i_seq_inst_vld;
    logic[`INST_WIDTH - 1:0] i_seq_inst;
    logic o_seq_pc_vld;
    logic[$clog2(`IRAM_DEPTH) - 1:0] o_seq_pc_offset;
    logic o_seq_vxu_issue_vld;
    logic[`CONFIG_OP_WIDTH - 1:0] o_seq_vxu_op_config;
    logic[`SCALAR_WIDTH - 1:0] o_seq_vxu_scalar_config;
    logic[`RW_OP_WIDTH - 1:0] o_seq_vxu_op_b0r;
    logic[`RW_OP_WIDTH - 1:0] o_seq_vxu_op_b0w;
    logic[`RW_OP_WIDTH - 1:0] o_seq_vxu_op_b1r;
    logic[`RW_OP_WIDTH - 1:0] o_seq_vxu_op_b1w;
    logic[`ALU_OP_WIDTH - 1:0] o_seq_vxu_op_alu;
    logic[`SCALAR_WIDTH - 1:0] o_seq_vxu_scalar_alu;
    logic[`ICONN_OP_WIDTH - 1:0] o_seq_vxu_op_iconn;
    logic[`SCALAR_WIDTH - 1:0] o_seq_vxu_scalar_iconn;
    logic[`NTT_OP_WIDTH - 1:0] o_seq_vxu_op_ntt;
    logic[`MUXO_OP_WIDTH - 1:0] o_seq_vxu_op_muxo;
    logic[`MUXI_OP_WIDTH - 1:0] o_seq_vxu_op_muxi;
    logic o_seq_vmu_issue_vld;
    logic[`CONFIG_OP_WIDTH - 1:0] o_seq_vmu_op_config;
    logic[`SCALAR_WIDTH - 1:0] o_seq_vmu_scalar_config;
    logic[`LSU_OP_WIDTH - 1:0] o_seq_vmu_op_ls[0:`SYS_NUM_LSU - 1];
    logic[`SCALAR_WIDTH - 1:0] o_seq_vmu_scalar_ls[0:`SYS_NUM_LSU - 1];
    logic[`CNT_WIDTH - 1:0] o_seq_cnt;
    logic o_seq_comp_vld;
    logic[`CNT_WIDTH:0] ntt_inst_std_cnt; 

    logic o_vmu_spm_rden[0:`SYS_NUM_LSU - 1];
    logic o_vmu_spm_wren[0:`SYS_NUM_LSU - 1];
    logic[`SCALAR_WIDTH - 1:0] o_vmu_spm_rdaddr[0:`SYS_NUM_LSU - 1];
    logic[`SCALAR_WIDTH - 1:0] o_vmu_spm_wraddr[0:`SYS_NUM_LSU - 1];

    logic[`COMMON_MEMR_DELAY:0] memr_sel_shift;

    logic o_pc_vld;
    logic[`PC_WIDTH - 1:0] o_pc_addr;
    logic[`INST_WIDTH - 1:0] i_inst;

    logic[`COMMON_BRAM_DELAY:0] pc_vld_shift;
    genvar i;

    assign pc_vld_shift[0] = o_seq_pc_vld;

    generate
        for(i = 1;i <= `COMMON_BRAM_DELAY;i++) begin
            always_ff @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    pc_vld_shift[i] <= 'b0;
                end
                else begin
                    pc_vld_shift[i] <= pc_vld_shift[i - 1];
                end
            end
        end
    endgenerate

    assign i_seq_inst_vld = pc_vld_shift[`COMMON_BRAM_DELAY];

    assign o_pc_vld = o_seq_pc_vld;
    assign o_pc_addr = i_csr_vp_pc + o_seq_pc_offset;
    assign i_seq_inst = i_inst;

    assign o_vp_rden = o_vmu_spm_rden[0] && (o_vmu_spm_rdaddr[0][`SCALAR_WIDTH - 1:48] != 'd15);
    assign o_vp_wren = o_vmu_spm_wren[0];
    assign o_vp_rdaddr = o_vmu_spm_rdaddr[0][$clog2(`SYS_NUM_LANE) + $clog2(`LANE_DATA_WIDTH / 8) +: 16] + ((o_vmu_spm_rdaddr[0][`SCALAR_WIDTH - 1:48] == 'd0) ? i_csr_vp_src0_ptr : 
                                                                                                            (o_vmu_spm_rdaddr[0][`SCALAR_WIDTH - 1:48] == 'd1) ? i_csr_vp_src1_ptr :
                                                                                                            (o_vmu_spm_rdaddr[0][`SCALAR_WIDTH - 1:48] == 'd2) ? i_csr_vp_rslt_ptr :
                                                                                                            'b0);
    assign o_vp_wraddr = o_vmu_spm_wraddr[0][$clog2(`SYS_NUM_LANE) + $clog2(`LANE_DATA_WIDTH / 8) +: 16] + ((o_vmu_spm_wraddr[0][`SCALAR_WIDTH - 1:48] == 'd0) ? i_csr_vp_src0_ptr : 
                                                                                                            (o_vmu_spm_wraddr[0][`SCALAR_WIDTH - 1:48] == 'd1) ? i_csr_vp_src1_ptr :
                                                                                                            (o_vmu_spm_wraddr[0][`SCALAR_WIDTH - 1:48] == 'd2) ? i_csr_vp_rslt_ptr :
                                                                                                            'b0);

    assign o_vp_ksk_rden = o_vmu_spm_rden[0] && (o_vmu_spm_rdaddr[0][`SCALAR_WIDTH - 1:48] == 'd15);
    assign o_vp_ksk_rdaddr = o_vmu_spm_rdaddr[0][$clog2(`SYS_NUM_LANE) + $clog2(`LANE_DATA_WIDTH / 8) +: 16] + i_csr_vp_ksk_ptr;

    assign memr_sel_shift[0] = o_vp_ksk_rden ? 1 : 0;

    generate
        for(i = 1;i <= `COMMON_MEMR_DELAY;i++) begin
            always_ff @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    memr_sel_shift[i] <= 'b0;
                end
                else begin
                    memr_sel_shift[i] <= memr_sel_shift[i - 1];
                end
            end
        end
    endgenerate

    inst_rom #(
        .DWIDTH(`INST_WIDTH),
        .DEPTH(`IRAM_DEPTH),
        .INIT_FILE(ISRAM_FILE)
    )i_inst_rom(
        .clk(clk),
        .rst_n(rst_n),
        .rden(o_pc_vld),
        .addr(o_pc_addr[$clog2(`IRAM_DEPTH) - 1:0]),
        .dout(i_inst)
    );
    
    seq_top i_seq_top(
        .*,
        .i_sys_start(i_start_vp),
        .o_sys_done(o_done_vp),
        .o_seq_vmu_op_ls(o_seq_vmu_op_ls[0]),
        .o_seq_vmu_scalar_ls(o_seq_vmu_scalar_ls[0]),
        .i_ntt_inst_std_cnt(ntt_inst_std_cnt),
        .i_csr_vp_step(i_csr_vp_step)
    );

    vmu_top i_vmu_top(
        .*,
        .i_seq_vmu_op_vld(o_seq_vmu_issue_vld),
        .i_seq_vmu_cnt(o_seq_cnt),
        .i_seq_vmu_op_ls(o_seq_vmu_op_ls),
        .i_seq_vmu_scalar_ls(o_seq_vmu_scalar_ls),
        .i_seq_vmu_op_config(o_seq_vmu_op_config),
        .i_seq_vmu_scalar_config(o_seq_vmu_scalar_config),
        .o_vmu_spm_rden(o_vmu_spm_rden),
        .o_vmu_spm_wren(o_vmu_spm_wren),
        .o_vmu_spm_rdaddr(o_vmu_spm_rdaddr),
        .o_vmu_spm_wraddr(o_vmu_spm_wraddr)
    );

    vxu_top #(
        .TF_INIT_FILE(TF_ROM_FILE)
    )i_vxu_top(
        .*,
        .i_op_vld(o_seq_vxu_issue_vld),
        .i_cnt(o_seq_cnt),
        .i_comp_vld(o_seq_comp_vld),
        .i_op_cfg(o_seq_vxu_op_config),
        .i_scalar_cfg(o_seq_vxu_scalar_config),
        .i_op_bk0_r({o_seq_vxu_op_b0r[0], o_seq_vxu_op_b0r[`RW_OP_WIDTH - 1:2]}),
        .i_op_bk0_w({o_seq_vxu_op_b0w[0], o_seq_vxu_op_b0w[`RW_OP_WIDTH - 1:2]}),
        .i_op_bk1_r({o_seq_vxu_op_b1r[0], o_seq_vxu_op_b1r[`RW_OP_WIDTH - 1:2]}),
        .i_op_bk1_w({o_seq_vxu_op_b1w[0], o_seq_vxu_op_b1w[`RW_OP_WIDTH - 1:2]}),
        .i_op_alu(o_seq_vxu_op_alu),
        .i_scalar_alu(o_seq_vxu_scalar_alu),
        .i_op_iconn(o_seq_vxu_op_iconn),
        .i_scalar_iconn(o_seq_vxu_scalar_iconn),
        .i_op_ntt(o_seq_vxu_op_ntt),
        .i_mux_o(o_seq_vxu_op_muxo),
        .i_mux_i(o_seq_vxu_op_muxi),
        .o_ntt_inst_std_cnt(ntt_inst_std_cnt),
        .i_vp_data(memr_sel_shift[`COMMON_MEMR_DELAY] ? i_vp_ksk_data : i_vp_data),
        .o_vp_data(o_vp_data)
    );
endmodule