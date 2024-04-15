//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: VP
// Module Name: vxu_top
// Modify Date: 
//
// Description:
// Vector Execution Unit
//////////////////////////////////////////////////

`include "vp_defines.vh"
`include "common_defines.vh"

module vxu_top#(
        parameter VLMAX = `SYS_VLMAX,
        parameter OP_WIDTH = `CONFIG_OP_WIDTH,
        parameter DATA_WIDTH = `LANE_DATA_WIDTH,
        parameter RF_ADDR_WIDTH = `RW_OP_WIDTH - 2,
        parameter ALU_OP_WIDTH = `ALU_OP_WIDTH,
        parameter ICONN_OP_WIDTH = `ICONN_OP_WIDTH,
        parameter NTT_OP_WIDTH = `NTT_OP_WIDTH,
        parameter MUX_O_WIDTH = `MUXO_OP_WIDTH,
        parameter MUX_I_WIDTH = `MUXI_OP_WIDTH,
        parameter NLANE = `SYS_NUM_LANE,
        parameter NTT_SWAP_LATENCY = `VXU_NTT_SWAP_LATENCY,
        parameter ALU_MUL_LEVEL = `VXU_ALU_MUL_LEVEL,
        parameter ALU_MUL_STAGE = `VXU_ALU_MUL_STAGE,
        parameter ALU_LAST_STAGE = `VXU_ALU_LAST_STAGE,
        parameter ALU_MODHALF_STAGE = `VXU_ALU_MODHALF_STAGE,
        parameter INTT_SWAP_LATENCY = `VXU_INTT_SWAP_LATENCY,
        parameter RF_READ_LATENCY = `VXU_RF_READ_LATENCY,
        parameter SPM_LATENCY = `COMMON_MEMR_DELAY + 1,
        parameter CNT_WIDTH = `max($clog2(VLMAX / DATA_WIDTH / NLANE), ($clog2($clog2(VLMAX / DATA_WIDTH)) + $clog2(VLMAX / DATA_WIDTH / 2 / (NLANE / 2)))),
        parameter NELEMENT = VLMAX / DATA_WIDTH / NLANE,
        parameter TF_ITEM_NUM = `TF_ITEM_NUM,
        parameter TF_ADDR_WIDTH = `TF_ADDR_WIDTH,
        parameter TF_INIT_FILE = ""
    )(
        //System
        input logic clk,
        input logic rst_n,

        //Sequencer
        input logic i_op_vld,
        input logic[CNT_WIDTH - 1:0] i_cnt,
        input logic i_comp_vld,
        input logic[OP_WIDTH - 1:0] i_op_cfg,
        input logic[DATA_WIDTH - 1:0] i_scalar_cfg,
        input logic[RF_ADDR_WIDTH:0] i_op_bk0_r,
        input logic[RF_ADDR_WIDTH:0] i_op_bk0_w,
        input logic[RF_ADDR_WIDTH:0] i_op_bk1_r,
        input logic[RF_ADDR_WIDTH:0] i_op_bk1_w,
        input logic[ALU_OP_WIDTH - 1:0] i_op_alu,
        input logic[DATA_WIDTH - 1:0] i_scalar_alu,
        input logic[ICONN_OP_WIDTH - 1:0] i_op_iconn,
        input logic[DATA_WIDTH - 1:0] i_scalar_iconn,
        input logic[NTT_OP_WIDTH - 1:0] i_op_ntt,
        input logic[MUX_O_WIDTH - 1:0] i_mux_o,
        input logic[MUX_I_WIDTH - 1:0] i_mux_i,
        output logic[CNT_WIDTH:0] o_ntt_inst_std_cnt,

        //SPM
        input logic[NLANE * DATA_WIDTH - 1:0] i_vp_data,
        output logic[NLANE * DATA_WIDTH - 1:0] o_vp_data
    );

    localparam NODE_ADDR_WIDTH = $clog2(NLANE);
    localparam ICONN_DATA_WIDTH = CNT_WIDTH + DATA_WIDTH;

    logic[NODE_ADDR_WIDTH - 1:0] iconn_ain[0:NLANE - 1];
    logic[ICONN_DATA_WIDTH - 1:0] iconn_din[0:NLANE - 1];
    logic[NLANE - 1:0] iconn_din_valid;
    logic[NODE_ADDR_WIDTH - 1:0] iconn_aout[0:NLANE - 1];
    logic[ICONN_DATA_WIDTH - 1:0] iconn_dout[0:NLANE - 1];
    logic[NLANE - 1:0] iconn_dout_valid;
    logic[NLANE - 1:0] iconn_fl_mode;
    logic[NODE_ADDR_WIDTH - 1:0] iconn_fl_aout[0:NLANE - 1];
    logic[ICONN_DATA_WIDTH - 1:0] iconn_fl_dout[0:NLANE - 1];
    logic[NLANE - 1:0] iconn_fl_dout_valid;
    logic[NODE_ADDR_WIDTH - 1:0] iconn_flr_ain[0:NLANE - 1];
    logic[ICONN_DATA_WIDTH - 1:0] iconn_flr_din[0:NLANE - 1];
    logic[NLANE - 1:0] iconn_flr_din_valid;
    logic[NODE_ADDR_WIDTH - 1:0] iconn_flr_aout[0:NLANE - 1];
    logic[ICONN_DATA_WIDTH - 1:0] iconn_flr_dout[0:NLANE - 1];
    logic[NLANE - 1:0] iconn_flr_dout_valid;
    logic[DATA_WIDTH - 1:0] pair_iconn[-1:NLANE];
    logic[DATA_WIDTH - 1:0] pair_mau[-1:NLANE];
    logic[$clog2(NELEMENT) - 1:0] shared_raddr;
    logic[$clog2(NELEMENT) - 1:0] shared_waddr;
    logic[TF_ADDR_WIDTH - 1:0] shared_tfaddr;
    logic rw_vrf_swap;
    logic alu_inout_swap;

    logic[DATA_WIDTH - 1:0] vl;
    logic[DATA_WIDTH - 1:0] mod_q;
    logic[$clog2(TF_ITEM_NUM) - 1:0] tf_item_id;
    logic ntt_idle;
    logic ntt_idle_reg;
    logic is_ntt_mode;
    logic is_ntt_mode_reg;

    genvar i;

    always_ff @(posedge clk) begin
        if(i_op_vld && (i_op_cfg == 'b01)) begin
            vl <= i_scalar_cfg;
        end
    end

    always_ff @(posedge clk) begin
        if(i_op_vld && (i_op_cfg == 'b10)) begin
            mod_q <= i_scalar_cfg;
            tf_item_id <= (i_scalar_cfg == 64'd576460825317867521) ? 'd0 :
                          (i_scalar_cfg == 64'd576460924102115329) ? 'd1 : 'd2;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ntt_idle_reg <= 'b1;
        end
        else if(i_op_vld) begin
            ntt_idle_reg <= i_op_ntt == 'b0;
        end
    end

    assign ntt_idle = i_op_vld ? (i_op_ntt == 'b0) : ntt_idle_reg;

    always_ff @(posedge clk) begin
        if(i_op_vld) begin
            if(i_op_ntt == 'b010) begin
                is_ntt_mode_reg <= 'b1;
            end
            else begin
                is_ntt_mode_reg <= 'b0;
            end
        end
    end

    assign is_ntt_mode = i_op_vld ? ((i_op_ntt == 'b010) ? 'b1 : 'b0) : is_ntt_mode_reg;

    iconn_top #(
        .NODE_ADDR_WIDTH($clog2(NLANE)),
        .DATA_WIDTH(ICONN_DATA_WIDTH)
    )i_iconn_top(
        .clk(clk),
        .rst_n(rst_n),
        .ain(iconn_ain),
        .din(iconn_din),
        .din_valid(iconn_din_valid),
        .aout(iconn_aout),
        .dout(iconn_dout),
        .dout_valid(iconn_dout_valid),
        .fl_mode(iconn_fl_mode[0]),
        .fl_aout(iconn_fl_aout),
        .fl_dout(iconn_fl_dout),
        .fl_dout_valid(iconn_fl_dout_valid),
        .flr_ain(iconn_flr_ain),
        .flr_din(iconn_flr_din),
        .flr_din_valid(iconn_flr_din_valid),
        .flr_aout(iconn_flr_aout),
        .flr_dout(iconn_flr_dout),
        .flr_dout_valid(iconn_flr_dout_valid)
    );

    ntt_fsm #(
        .NLANE(NLANE),
        .ADDR_WIDTH($clog2(NELEMENT)),
        .DATA_WIDTH(DATA_WIDTH),
        .TF_ITEM_NUM(TF_ITEM_NUM),
        .TF_ADDR_WIDTH(TF_ADDR_WIDTH),
        .VLMAX(VLMAX)
    )i_ntt_fsm(
        .clk(clk),
        .i_idle(ntt_idle),
        .i_ntt_mode(is_ntt_mode),
        .i_cnt(i_cnt),
        .i_vl(vl),
        .i_tf_item_id(tf_item_id),
        .o_shared_raddr(shared_raddr),
        .o_shared_waddr(shared_waddr),
        .o_shared_tfaddr(shared_tfaddr),
        .o_rw_vrf_swap(rw_vrf_swap),
        .o_alu_inout_swap(alu_inout_swap),
        .o_ntt_inst_std_cnt(o_ntt_inst_std_cnt)
    );

    generate
        for(i = 0;i < NLANE;i++) begin: vxu_lane_block
            vxu_lane #(
                .LANE_ID(i),
                .NLANE(NLANE),
                .CNT_WIDTH(CNT_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .RF_ADDR_WIDTH(RF_ADDR_WIDTH),
                .ALU_OP_WIDTH(ALU_OP_WIDTH),
                .ICONN_OP_WIDTH(ICONN_OP_WIDTH),
                .NTT_OP_WIDTH(NTT_OP_WIDTH),
                .MUX_O_WIDTH(MUX_O_WIDTH),
                .MUX_I_WIDTH(MUX_I_WIDTH),
                .NELEMENT(NELEMENT),
                .NTT_SWAP_LATENCY(NTT_SWAP_LATENCY),
                .ALU_MUL_LEVEL(ALU_MUL_LEVEL),
                .ALU_MUL_STAGE(ALU_MUL_STAGE),
                .ALU_LAST_STAGE(ALU_LAST_STAGE),
                .ALU_MODHALF_STAGE(ALU_MODHALF_STAGE),
                .INTT_SWAP_LATENCY(INTT_SWAP_LATENCY),
                .RF_READ_LATENCY(RF_READ_LATENCY),
                .SPM_LATENCY(SPM_LATENCY),
                .NODE_ADDR_WIDTH(NODE_ADDR_WIDTH),
                .ICONN_DATA_WIDTH(ICONN_DATA_WIDTH),
                .TF_ADDR_WIDTH(TF_ADDR_WIDTH),
                .TF_INIT_FILE(TF_INIT_FILE)
            )i_vxu_lane(
                .clk(clk),
                .rst_n(rst_n),
                .i_op_vld(i_op_vld && (i_op_cfg == 'b00)),
                .i_cnt(i_cnt),
                .i_comp_vld(i_comp_vld),
                .i_op_bk0_r(i_op_bk0_r),
                .i_op_bk0_w(i_op_bk0_w),
                .i_op_bk1_r(i_op_bk1_r),
                .i_op_bk1_w(i_op_bk1_w),
                .i_op_alu(i_op_alu),
                .i_scalar_alu(i_scalar_alu),
                .i_op_iconn(i_op_iconn),
                .i_scalar_iconn(i_scalar_iconn),
                .i_op_ntt(i_op_ntt),
                .i_mux_o(i_mux_o),
                .i_mux_i(i_mux_i),
                .i_vp_data(i_vp_data[i * DATA_WIDTH +: DATA_WIDTH]),
                .o_vp_data(o_vp_data[i * DATA_WIDTH +: DATA_WIDTH]),
                .i_vl(i_scalar_cfg),
                .i_vl_we(i_op_vld && (i_op_cfg == 'b01)),
                .i_mod_q(i_scalar_cfg),
                .i_mod_q_we(i_op_vld && (i_op_cfg == 'b10)),
                .i_mod_iq(i_scalar_cfg),
                .i_mod_iq_we(i_op_vld && (i_op_cfg == 'b11)),
                .o_iconn_addr(iconn_ain[i]),
                .o_iconn_data(iconn_din[i]),
                .o_iconn_valid(iconn_din_valid[i]),
                .i_iconn_addr(iconn_aout[i]),
                .i_iconn_data(iconn_dout[i]),
                .i_iconn_valid(iconn_dout_valid[i]),
                .o_iconn_fl_mode(iconn_fl_mode[i]),
                .i_iconn_fl_addr(iconn_fl_aout[i]),
                .i_iconn_fl_data(iconn_fl_dout[i]),
                .i_iconn_fl_valid(iconn_fl_dout_valid[i]),
                .o_iconn_flr_addr(iconn_flr_ain[i]),
                .o_iconn_flr_data(iconn_flr_din[i]),
                .o_iconn_flr_valid(iconn_flr_din_valid[i]),
                .i_iconn_flr_addr(iconn_flr_aout[i]),
                .i_iconn_flr_data(iconn_flr_dout[i]),
                .i_iconn_flr_valid(iconn_flr_dout_valid[i]),
                .i_pair_iconn(i[0] ? pair_iconn[i - 1] : pair_iconn[i + 1]),
                .i_pair_mau(i[0] ? pair_mau[i - 1] : pair_mau[i + 1]),
                .o_pair_iconn(pair_iconn[i]),
                .o_pair_mau(pair_mau[i]),
                .i_shared_raddr(shared_raddr),
                .i_shared_waddr(shared_waddr),
                .i_shared_tfaddr(shared_tfaddr),
                .i_rw_vrf_swap(rw_vrf_swap),
                .i_alu_inout_swap(alu_inout_swap)
            );
        end
    endgenerate
endmodule