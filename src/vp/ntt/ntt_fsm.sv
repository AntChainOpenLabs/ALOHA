//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: VP
// Module Name: ntt_fsm
// Modify Date: 
//
// Description:
// NTT/INTT shared address generator
//////////////////////////////////////////////////

module ntt_fsm#(
        parameter NLANE = 32,
        parameter ADDR_WIDTH = 32,
        parameter DATA_WIDTH = 64,
        parameter TF_ITEM_NUM = 3,
        parameter TF_ADDR_WIDTH = 32,
        parameter VLMAX = 65536,
        localparam STAGE_CYC = VLMAX / DATA_WIDTH / 2 / (NLANE / 2),
        localparam NTT_LOGN = $clog2(VLMAX / DATA_WIDTH),
        localparam CNT_HB_WIDTH = $clog2(NTT_LOGN),
        localparam CNT_LB_WIDTH = $clog2(STAGE_CYC),
        localparam CNT_WIDTH = CNT_HB_WIDTH + CNT_LB_WIDTH
    )(
        input logic clk,
        input logic i_idle,
        input logic i_ntt_mode,
        input logic[CNT_WIDTH - 1:0] i_cnt,
        input logic[DATA_WIDTH - 1:0] i_vl,
        input logic[$clog2(TF_ITEM_NUM) - 1:0] i_tf_item_id,
        output logic[ADDR_WIDTH - 1:0] o_shared_raddr,
        output logic[ADDR_WIDTH - 1:0] o_shared_waddr,
        output logic[TF_ADDR_WIDTH - 1:0] o_shared_tfaddr,
        output logic o_rw_vrf_swap,
        output logic o_alu_inout_swap,
        output logic[CNT_WIDTH:0] o_ntt_inst_std_cnt
    );

    logic[CNT_HB_WIDTH - 1:0] cnt_hb;
    logic[CNT_LB_WIDTH - 1:0] cnt_lb;
    logic[DATA_WIDTH - 1:0] stage_cyc;
    logic[DATA_WIDTH - 1:0] stage_cyc_log_pre;
    logic[DATA_WIDTH - 1:0] stage_cyc_log;//$clog2(stage_cyc)
    logic[DATA_WIDTH - 1:0] ntt_logn_pre;
    logic[DATA_WIDTH - 1:0] ntt_logn;
    logic[DATA_WIDTH - 1:0] reversed_cnt_lb;//stage_cyc - cnt_lb - 1
    
    assign stage_cyc = i_vl >> (unsigned'($clog2(DATA_WIDTH)) + 'd1 + unsigned'($clog2(NLANE / 2)));
    assign stage_cyc_log_pre = i_vl >> (unsigned'($clog2(DATA_WIDTH)) + 'd1);
    assign stage_cyc_log = (stage_cyc_log_pre[9] ? ('d9 - unsigned'($clog2(NLANE / 2))) : 'b0) |
                           (stage_cyc_log_pre[10] ? ('d10 - unsigned'($clog2(NLANE / 2))) : 'b0) |
                           (stage_cyc_log_pre[11] ? ('d11 - unsigned'($clog2(NLANE / 2))) : 'b0) |
                           (stage_cyc_log_pre[12] ? ('d12 - unsigned'($clog2(NLANE / 2))) : 'b0) |
                           (stage_cyc_log_pre[13] ? ('d13 - unsigned'($clog2(NLANE / 2))) : 'b0) |
                           (stage_cyc_log_pre[14] ? ('d14 - unsigned'($clog2(NLANE / 2))) : 'b0) |
                           (stage_cyc_log_pre[15] ? ('d15 - unsigned'($clog2(NLANE / 2))) : 'b0);
    assign ntt_logn_pre = i_vl >> $clog2(DATA_WIDTH);
    assign ntt_logn = (ntt_logn_pre[10] ? 'd10 : 'b0) |
                      (ntt_logn_pre[11] ? 'd11 : 'b0) |
                      (ntt_logn_pre[12] ? 'd12 : 'b0) |
                      (ntt_logn_pre[13] ? 'd13 : 'b0) |
                      (ntt_logn_pre[14] ? 'd14 : 'b0) |
                      (ntt_logn_pre[15] ? 'd15 : 'b0) |
                      (ntt_logn_pre[16] ? 'd16 : 'b0);

    always_ff @(posedge clk) begin
        o_ntt_inst_std_cnt <= stage_cyc * ntt_logn;
    end

    assign cnt_hb = i_cnt >> stage_cyc_log;
    assign cnt_lb = i_cnt & (stage_cyc - 'd1);

    assign reversed_cnt_lb = stage_cyc - cnt_lb - 'd1;

    assign o_shared_raddr = i_ntt_mode ? ((cnt_lb >> 1) | (cnt_lb[0] << (stage_cyc_log - 1))) : reversed_cnt_lb;
    assign o_shared_waddr = i_ntt_mode ? cnt_lb : ((reversed_cnt_lb >> 1) | (reversed_cnt_lb[0] << (stage_cyc_log - 1)));
    assign o_shared_tfaddr = (i_tf_item_id << (TF_ADDR_WIDTH - unsigned'($clog2(TF_ITEM_NUM)))) | (i_ntt_mode ? ((cnt_hb < unsigned'($clog2(NLANE / 2))) ? cnt_hb : (('d1 << (cnt_hb - unsigned'($clog2(NLANE / 2)))) + (cnt_lb & (('d1 << (cnt_hb - unsigned'($clog2(NLANE / 2)))) - 'd1)) + unsigned'($clog2(NLANE / 2)) - 'd1)) :
                                                                                       ((cnt_hb >= (ntt_logn - unsigned'($clog2(NLANE / 2)))) ? (ntt_logn - cnt_hb - 'd1 + ('d1 << (TF_ADDR_WIDTH - 'd1 - unsigned'($clog2(TF_ITEM_NUM))))) : ((1 << (ntt_logn - 'd1 - unsigned'($clog2(NLANE / 2)) - cnt_hb)) + (reversed_cnt_lb & (('d1 << (ntt_logn - 'd1 - unsigned'($clog2(NLANE / 2)) - cnt_hb)) - 'd1)) + unsigned'($clog2(NLANE / 2)) - 'd1 + ('d1 << (TF_ADDR_WIDTH - 'd1 - unsigned'($clog2(TF_ITEM_NUM)))))));
    assign o_rw_vrf_swap = i_idle ? 'b0 : cnt_hb[0];
    assign o_alu_inout_swap = i_idle ? 'b0 : cnt_lb[0];
endmodule