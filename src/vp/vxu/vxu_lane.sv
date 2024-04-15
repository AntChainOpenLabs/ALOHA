//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: VP
// Module Name: vxu_top
// Modify Date: 
//
// Description:
// Vector Execution Unit Lane
//////////////////////////////////////////////////

module vxu_lane#(
        parameter LANE_ID = 0,
        parameter NLANE = 32,
        parameter CNT_WIDTH = 10,
        parameter DATA_WIDTH = 64,
        parameter RF_ADDR_WIDTH = 4,
        parameter ALU_OP_WIDTH = 5,
        parameter ICONN_OP_WIDTH = 3,
        parameter NTT_OP_WIDTH = 3,
        parameter MUX_O_WIDTH = 4,
        parameter MUX_I_WIDTH = 4,
        parameter NELEMENT = 256,
        parameter NTT_SWAP_LATENCY = 1,
        parameter ALU_MUL_LEVEL = 2,
        parameter ALU_MUL_STAGE = 1,
        parameter ALU_LAST_STAGE = 2,
        parameter ALU_MODHALF_STAGE = 1,
        parameter INTT_SWAP_LATENCY = 1,
        parameter RF_READ_LATENCY = 1,
        parameter SPM_LATENCY = 1,
        parameter NODE_ADDR_WIDTH = 5,
        parameter ICONN_DATA_WIDTH = 74,
        parameter TF_ADDR_WIDTH = 32,
        parameter TF_INIT_FILE = ""
    )(
        //System
        input logic clk,
        input logic rst_n,

        //Sequencer
        input logic i_op_vld,
        input logic[CNT_WIDTH - 1:0] i_cnt,
        input logic i_comp_vld,
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

        //SPM
        input logic[DATA_WIDTH - 1:0] i_vp_data,
        output logic[DATA_WIDTH - 1:0] o_vp_data,

        //Config
        input logic[DATA_WIDTH - 1:0] i_vl,
        input logic i_vl_we,
        input logic[DATA_WIDTH - 1:0] i_mod_q,
        input logic i_mod_q_we,
        input logic[DATA_WIDTH - 1:0] i_mod_iq,
        input logic i_mod_iq_we,

        //Iconn
        output logic[NODE_ADDR_WIDTH - 1:0] o_iconn_addr,
        output logic[ICONN_DATA_WIDTH - 1:0] o_iconn_data,
        output logic o_iconn_valid,
        input logic[NODE_ADDR_WIDTH - 1:0] i_iconn_addr,
        input logic[ICONN_DATA_WIDTH - 1:0] i_iconn_data,
        input logic i_iconn_valid,
        output logic o_iconn_fl_mode,
        input logic[NODE_ADDR_WIDTH - 1:0] i_iconn_fl_addr,
        input logic[ICONN_DATA_WIDTH - 1:0] i_iconn_fl_data,
        input logic i_iconn_fl_valid,
        output logic[NODE_ADDR_WIDTH - 1:0] o_iconn_flr_addr,
        output logic[ICONN_DATA_WIDTH - 1:0] o_iconn_flr_data,
        output logic o_iconn_flr_valid,
        input logic[NODE_ADDR_WIDTH - 1:0] i_iconn_flr_addr,
        input logic[ICONN_DATA_WIDTH - 1:0] i_iconn_flr_data,
        input logic i_iconn_flr_valid,

        //Pair
        input logic[DATA_WIDTH - 1:0] i_pair_iconn,
        input logic[DATA_WIDTH - 1:0] i_pair_mau,
        output logic[DATA_WIDTH - 1:0] o_pair_iconn,
        output logic[DATA_WIDTH - 1:0] o_pair_mau,

        //NTT
        input logic[$clog2(NELEMENT) - 1:0] i_shared_raddr,
        input logic[$clog2(NELEMENT) - 1:0] i_shared_waddr,
        input logic[TF_ADDR_WIDTH - 1:0] i_shared_tfaddr,
        input logic i_rw_vrf_swap,
        input logic i_alu_inout_swap
    );

    localparam RF_STAGE_NUM = RF_READ_LATENCY;
    localparam NTT_ICONN_READ_LATENCY = 1;
    localparam NTT_ICONN_WRITE_LATENCY = 1;
    localparam ALU_STAGE_NUM = 3 * ALU_MUL_STAGE + ALU_LAST_STAGE + ALU_MODHALF_STAGE + 1;
    localparam TOTAL_STAGE = RF_STAGE_NUM + NTT_ICONN_READ_LATENCY + NTT_SWAP_LATENCY + ALU_STAGE_NUM + INTT_SWAP_LATENCY + NTT_ICONN_WRITE_LATENCY;
    localparam ICONN_LATENCY = NODE_ADDR_WIDTH - 1;
    localparam NTT_ICONN_READ_INDEX = RF_STAGE_NUM;
    localparam NTT_SWAP_INDEX = RF_STAGE_NUM + NTT_ICONN_READ_LATENCY;
    localparam ALU_INPUT_INDEX = RF_STAGE_NUM + NTT_ICONN_READ_LATENCY + NTT_SWAP_LATENCY;
    localparam INTT_SWAP_INDEX = RF_STAGE_NUM + NTT_ICONN_READ_LATENCY + NTT_SWAP_LATENCY + ALU_STAGE_NUM;
    localparam NTT_ICONN_WRITE_INDEX = RF_STAGE_NUM + NTT_ICONN_READ_LATENCY + NTT_SWAP_LATENCY + ALU_STAGE_NUM + INTT_SWAP_LATENCY;
    localparam RF_WRITE_INDEX = RF_STAGE_NUM + NTT_ICONN_READ_LATENCY + NTT_SWAP_LATENCY + ALU_STAGE_NUM + INTT_SWAP_LATENCY + NTT_ICONN_WRITE_LATENCY;

    logic[DATA_WIDTH - 1:0] vl;
    logic[DATA_WIDTH - 1:0] mod_q;
    logic[DATA_WIDTH - 1:0] mod_iq;

    logic[RF_ADDR_WIDTH - 1:0] bk0_raddr;
    logic[DATA_WIDTH - 1:0] bk0_rdata;
    logic bk0_rvld;
    logic[$clog2(NELEMENT) - 1:0] bk0_roffset;
    logic[TOTAL_STAGE:0][RF_ADDR_WIDTH - 1:0] bk0_waddr;
    logic[DATA_WIDTH - 1:0] bk0_wdata;
    logic[TOTAL_STAGE:0] bk0_wvld;
    logic[$clog2(NELEMENT) - 1:0] bk0_woffset;

    logic[RF_ADDR_WIDTH - 1:0] bk1_raddr;
    logic[DATA_WIDTH - 1:0] bk1_rdata;
    logic bk1_rvld;
    logic[$clog2(NELEMENT) - 1:0] bk1_roffset;
    logic[TOTAL_STAGE:0][RF_ADDR_WIDTH - 1:0] bk1_waddr;
    logic[DATA_WIDTH - 1:0] bk1_wdata;
    logic[TOTAL_STAGE:0] bk1_wvld;
    logic[$clog2(NELEMENT) - 1:0] bk1_woffset;

    logic[TOTAL_STAGE:0] op_vld_p;
    logic[TOTAL_STAGE:0][CNT_WIDTH - 1:0] cnt_p;
    logic[ALU_INPUT_INDEX:0][ALU_OP_WIDTH - 1:0] op_alu_p;
    logic[ALU_INPUT_INDEX:0][DATA_WIDTH - 1:0] scalar_alu_p;
    logic[TOTAL_STAGE:0][ICONN_OP_WIDTH - 1:0] op_iconn_p;
    logic[TOTAL_STAGE:0][DATA_WIDTH - 1:0] scalar_iconn_p;
    logic[TOTAL_STAGE:0][NTT_OP_WIDTH - 1:0] op_ntt_p;
    logic[ALU_INPUT_INDEX:0][MUX_O_WIDTH - 1:0] mux_o_p;
    logic[TOTAL_STAGE:0][MUX_I_WIDTH - 1:0] mux_i_p;
    logic[TOTAL_STAGE:0][DATA_WIDTH - 1:0] i_vp_data_p;
    logic[TOTAL_STAGE:0][DATA_WIDTH - 1:0] o_vp_data_p;
    logic[ALU_INPUT_INDEX:0][DATA_WIDTH - 1:0] vl_p;
    logic[ALU_INPUT_INDEX:0][DATA_WIDTH - 1:0] mod_q_p;
    logic[ALU_INPUT_INDEX:0][DATA_WIDTH - 1:0] mod_iq_p;
    logic[TOTAL_STAGE:0][NODE_ADDR_WIDTH - 1:0] i_iconn_addr_p;
    logic[TOTAL_STAGE:0][ICONN_DATA_WIDTH - 1:0] i_iconn_data_p;
    logic[TOTAL_STAGE:0] i_iconn_valid_p;
    logic[TOTAL_STAGE:0][NODE_ADDR_WIDTH - 1:0] i_iconn_fl_addr_p;
    logic[TOTAL_STAGE:0][ICONN_DATA_WIDTH - 1:0] i_iconn_fl_data_p;
    logic[TOTAL_STAGE:0] i_iconn_fl_valid_p;
    logic[TOTAL_STAGE:0][NODE_ADDR_WIDTH - 1:0] i_iconn_flr_addr_p;
    logic[TOTAL_STAGE:0][ICONN_DATA_WIDTH - 1:0] i_iconn_flr_data_p;
    logic[TOTAL_STAGE:0] i_iconn_flr_valid_p;

    logic[ALU_INPUT_INDEX:0][DATA_WIDTH - 1:0] mux_o_opa_p;
    logic[ALU_INPUT_INDEX:0][DATA_WIDTH - 1:0] mux_o_opb_p;

    logic[TOTAL_STAGE:0][$clog2(NELEMENT) - 1:0] shared_raddr_p;
    logic[TOTAL_STAGE:0][$clog2(NELEMENT) - 1:0] shared_waddr_p;
    logic[TOTAL_STAGE:0][TF_ADDR_WIDTH - 1:0] shared_tfaddr_p;
    logic[TOTAL_STAGE:0] alu_inout_swap_p;

    logic[DATA_WIDTH - 1:0] opa_pre;
    logic[DATA_WIDTH - 1:0] opb_pre;
    logic[DATA_WIDTH - 1:0] opa;
    logic[DATA_WIDTH - 1:0] opb;
    logic[DATA_WIDTH - 1:0] ops;
    logic[TOTAL_STAGE:0][DATA_WIDTH - 1:0] res0_p;
    logic[TOTAL_STAGE:0][DATA_WIDTH - 1:0] res1_p;

    logic[TOTAL_STAGE:0][DATA_WIDTH - 1:0] mux_muxi_mau_p;
    logic[DATA_WIDTH - 1:0] mux_muxi_iconn;

    logic[RF_ADDR_WIDTH:0] s_op_bk0_r;
    logic[RF_ADDR_WIDTH:0] s_op_bk0_w;
    logic[RF_ADDR_WIDTH:0] s_op_bk1_r;
    logic[RF_ADDR_WIDTH:0] s_op_bk1_w;
    logic[ALU_OP_WIDTH - 1:0] s_op_alu;
    logic[DATA_WIDTH - 1:0] s_scalar_alu;
    logic[ICONN_OP_WIDTH - 1:0] s_op_iconn;
    logic[DATA_WIDTH - 1:0] s_scalar_iconn;
    logic[NTT_OP_WIDTH - 1:0] s_op_ntt;
    logic[MUX_O_WIDTH - 1:0] s_mux_o;
    logic[MUX_O_WIDTH - 1:0] s_mux_o_swap_ntt;
    logic[MUX_O_WIDTH - 1:0] s_mux_o_swap_intt;
    logic[MUX_O_WIDTH - 1:0] s_mux_o_swap_normal;
    logic[MUX_O_WIDTH - 1:0] s_mux_o_swap;
    logic[MUX_I_WIDTH - 1:0] s_mux_i;
    logic[MUX_I_WIDTH - 1:0] s_mux_i_swap_ntt;
    logic[MUX_I_WIDTH - 1:0] s_mux_i_swap_intt;
    logic[MUX_I_WIDTH - 1:0] s_mux_i_swap_normal;
    logic[MUX_I_WIDTH - 1:0] s_mux_i_swap;
    logic s_rw_vrf_swap;
    logic[RF_ADDR_WIDTH:0] c_op_bk0_r;
    logic[RF_ADDR_WIDTH:0] c_op_bk0_w;
    logic[RF_ADDR_WIDTH:0] c_op_bk1_r;
    logic[RF_ADDR_WIDTH:0] c_op_bk1_w;

    logic[TOTAL_STAGE:0] is_ntt_p;
    logic[TOTAL_STAGE:0] is_intt_p;

    logic[DATA_WIDTH - 1:0] iconn_preoutput_data;

    logic[DATA_WIDTH - 1:0] tf_mem[0:2 ** TF_ADDR_WIDTH];

    genvar i;

    initial begin
        if(TF_INIT_FILE != "") begin
            $readmemh($sformatf("%s.%0d", TF_INIT_FILE, LANE_ID), tf_mem);
        end
    end

    always_comb begin
        if(is_ntt_p[0]) begin
            if(i_op_bk0_w[RF_ADDR_WIDTH]) begin
                s_mux_o_swap_ntt = {i_mux_o[3:2], 1'b0, i_mux_o[0]};
            end
            else begin
                s_mux_o_swap_ntt = {i_mux_o[3:2], 1'b1, i_mux_o[0]};
            end

            if(i_op_bk0_r[RF_ADDR_WIDTH]) begin
                s_mux_i_swap_ntt = {2'b00, i_mux_i[1:0]};
            end
            else begin
                s_mux_i_swap_ntt = {i_mux_i[3:2], 2'b00};
            end
        end
        else begin
            s_mux_o_swap_ntt = 0;
            s_mux_i_swap_ntt = 0;
        end
    end

    always_comb begin
        if(is_intt_p[0]) begin
            if(i_op_bk0_w[RF_ADDR_WIDTH]) begin
                s_mux_o_swap_intt = {1'b0, i_mux_o[2:0]};
            end
            else begin
                s_mux_o_swap_intt = {1'b1, i_mux_o[2:0]};
            end

            if(i_op_bk0_r[RF_ADDR_WIDTH]) begin
                s_mux_i_swap_intt = {2'b01, i_mux_i[1:0]};
            end
            else begin
                s_mux_i_swap_intt = {i_mux_i[3:2], 2'b01};
            end
        end
        else begin
            s_mux_o_swap_intt = 0;
            s_mux_i_swap_intt = 0;
        end
    end

    assign s_mux_o_swap_normal = (is_ntt_p[0] || is_intt_p[0]) ? 'b0 : i_mux_o;
    assign s_mux_i_swap_normal = (is_ntt_p[0] || is_intt_p[0]) ? 'b0 : i_mux_i;

    always_ff @(posedge clk) begin
        if(i_op_vld) begin
            s_op_bk0_r <= i_op_bk0_r;
            s_op_bk0_w <= i_op_bk0_w;
            s_op_bk1_r <= i_op_bk1_r;
            s_op_bk1_w <= i_op_bk1_w;
            s_op_alu <= i_op_alu;
            s_scalar_alu <= i_scalar_alu;
            s_op_iconn <= i_op_iconn;
            s_scalar_iconn <= i_scalar_iconn;
            s_op_ntt <= i_op_ntt;
            s_mux_o <= i_mux_o;
            s_mux_i <= i_mux_i;
            s_rw_vrf_swap <= i_rw_vrf_swap;
            s_mux_o_swap <= s_mux_o_swap_ntt | s_mux_o_swap_intt | s_mux_o_swap_normal;
            s_mux_i_swap <= s_mux_i_swap_ntt | s_mux_i_swap_intt | s_mux_i_swap_normal;
        end
        else if(i_comp_vld && (s_rw_vrf_swap != i_rw_vrf_swap)) begin
            s_op_bk0_r <= s_op_bk0_w;
            s_op_bk0_w <= s_op_bk0_r;
            s_op_bk1_r <= s_op_bk1_w;
            s_op_bk1_w <= s_op_bk1_r;
            s_rw_vrf_swap <= i_rw_vrf_swap;
            s_mux_o <= s_mux_o_swap;
            s_mux_o_swap <= s_mux_o;
            s_mux_i <= s_mux_i_swap;
            s_mux_i_swap <= s_mux_i;
        end
    end

    always_ff @(posedge clk) begin
        if(i_vl_we) begin
            vl <= i_vl;
        end
    end

    always_ff @(posedge clk) begin
        if(i_mod_q_we) begin
            mod_q <= i_mod_q;
        end
    end

    always_ff @(posedge clk) begin
        if(i_mod_iq_we) begin
            mod_iq <= i_mod_iq;
        end
    end
    
    assign c_op_bk0_r = i_op_vld ? i_op_bk0_r : (i_comp_vld && (s_rw_vrf_swap != i_rw_vrf_swap)) ? s_op_bk0_w : s_op_bk0_r;
    assign c_op_bk0_w = i_op_vld ? i_op_bk0_w : (i_comp_vld && (s_rw_vrf_swap != i_rw_vrf_swap)) ? s_op_bk0_r : s_op_bk0_w;
    assign c_op_bk1_r = i_op_vld ? i_op_bk1_r : (i_comp_vld && (s_rw_vrf_swap != i_rw_vrf_swap)) ? s_op_bk1_w : s_op_bk1_r;
    assign c_op_bk1_w = i_op_vld ? i_op_bk1_w : (i_comp_vld && (s_rw_vrf_swap != i_rw_vrf_swap)) ? s_op_bk1_r : s_op_bk1_w;

    assign bk0_raddr = c_op_bk0_r[RF_ADDR_WIDTH - 1:0];
    assign bk0_rvld = c_op_bk0_r[RF_ADDR_WIDTH];
    assign bk0_waddr[0] = c_op_bk0_w[RF_ADDR_WIDTH - 1:0];
    assign bk0_wvld[0] = c_op_bk0_w[RF_ADDR_WIDTH];

    assign bk1_raddr = c_op_bk1_r[RF_ADDR_WIDTH - 1:0];
    assign bk1_rvld = c_op_bk1_r[RF_ADDR_WIDTH];
    assign bk1_waddr[0] = c_op_bk1_w[RF_ADDR_WIDTH - 1:0];
    assign bk1_wvld[0] = c_op_bk1_w[RF_ADDR_WIDTH];

    assign op_vld_p[0] = (i_vl_we | i_mod_q_we | i_mod_iq_we) ? 1'b0 : i_comp_vld;
    assign cnt_p[0] = i_cnt;
    assign op_alu_p[0] = i_op_vld ? i_op_alu : s_op_alu;
    assign scalar_alu_p[0] = i_op_vld ? i_scalar_alu : s_scalar_alu;
    assign op_iconn_p[0] = i_op_vld ? i_op_iconn : s_op_iconn;
    assign scalar_iconn_p[0] = i_op_vld ? i_scalar_iconn : s_scalar_iconn;
    assign op_ntt_p[0] = i_op_vld ? i_op_ntt : s_op_ntt;
    assign mux_o_p[0] = i_op_vld ? i_mux_o : (i_comp_vld && (s_rw_vrf_swap != i_rw_vrf_swap)) ? s_mux_o_swap : s_mux_o;
    assign mux_i_p[0] = i_op_vld ? i_mux_i : (i_comp_vld && (s_rw_vrf_swap != i_rw_vrf_swap)) ? s_mux_i_swap : s_mux_i;
    assign i_vp_data_p[SPM_LATENCY] = i_vp_data;
    assign o_vp_data_p[RF_STAGE_NUM] = mux_o_p[RF_STAGE_NUM][0] ? bk1_rdata : bk0_rdata;
    assign o_vp_data = o_vp_data_p[TOTAL_STAGE];
    assign vl_p[0] = vl;
    assign mod_q_p[0] = mod_q;
    assign mod_iq_p[0] = mod_iq;
    assign i_iconn_addr_p[RF_STAGE_NUM + ICONN_LATENCY] = i_iconn_addr;
    assign i_iconn_data_p[RF_STAGE_NUM + ICONN_LATENCY] = i_iconn_data;
    assign i_iconn_valid_p[RF_STAGE_NUM + ICONN_LATENCY] = i_iconn_valid;
    assign i_iconn_fl_addr_p[RF_STAGE_NUM] = i_iconn_fl_addr;
    assign i_iconn_fl_data_p[RF_STAGE_NUM] = i_iconn_fl_data;
    assign i_iconn_fl_valid_p[RF_STAGE_NUM] = i_iconn_fl_valid;
    assign i_iconn_flr_addr_p[NTT_ICONN_WRITE_INDEX] = i_iconn_flr_addr;
    assign i_iconn_flr_data_p[NTT_ICONN_WRITE_INDEX] = i_iconn_flr_data;
    assign i_iconn_flr_valid_p[NTT_ICONN_WRITE_INDEX] = i_iconn_flr_valid;
    assign shared_raddr_p[0] = i_shared_raddr;
    assign shared_waddr_p[0] = i_shared_waddr;
    assign shared_tfaddr_p[0] = i_shared_tfaddr;
    assign alu_inout_swap_p[0] = i_alu_inout_swap;
    generate
        for(i = 1;i <= ALU_INPUT_INDEX;i++) begin
            always_ff @(posedge clk) begin
                op_alu_p[i] <= op_alu_p[i - 1]; 
                scalar_alu_p[i] <= scalar_alu_p[i - 1];
                mux_o_p[i] <= mux_o_p[i - 1];  
                vl_p[i] <= vl_p[i - 1];
                mod_q_p[i] <= mod_q_p[i - 1];
                mod_iq_p[i] <= mod_iq_p[i - 1];
            end
        end

        for(i = 1;i <= TOTAL_STAGE;i++) begin
            always_ff @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    bk0_wvld[i] <= '0;
                    bk1_wvld[i] <= '0;
                    op_vld_p[i] <= '0;
                end
                else begin
                    bk0_wvld[i] <= bk0_wvld[i - 1];
                    bk1_wvld[i] <= bk1_wvld[i - 1];
                    op_vld_p[i] <= op_vld_p[i - 1];
                end
            end

            always_ff @(posedge clk) begin
                bk0_waddr[i] <= bk0_waddr[i - 1];
                bk1_waddr[i] <= bk1_waddr[i - 1];
                cnt_p[i] <= cnt_p[i - 1];
                mux_i_p[i] <= mux_i_p[i - 1];
                op_iconn_p[i] <= op_iconn_p[i - 1];
                scalar_iconn_p[i] <= scalar_iconn_p[i - 1];
                op_ntt_p[i] <= op_ntt_p[i - 1];
                shared_raddr_p[i] <= shared_raddr_p[i - 1];
                shared_waddr_p[i] <= shared_waddr_p[i - 1];
                shared_tfaddr_p[i] <= shared_tfaddr_p[i - 1];
                alu_inout_swap_p[i] <= alu_inout_swap_p[i - 1];
            end
        end

        for(i = SPM_LATENCY + 1;i <= TOTAL_STAGE;i++) begin
            always_ff @(posedge clk) begin
                i_vp_data_p[i] <= i_vp_data_p[i - 1];
            end
        end

        for(i = RF_STAGE_NUM + 1;i <= TOTAL_STAGE;i++) begin
            always_ff @(posedge clk) begin
                o_vp_data_p[i] <= o_vp_data_p[i - 1];
            end
        end

        for(i = RF_STAGE_NUM + ICONN_LATENCY + 1;i <= TOTAL_STAGE;i++) begin
            always_ff @(posedge clk) begin
                i_iconn_addr_p[i] <= i_iconn_addr_p[i - 1];
                i_iconn_data_p[i] <= i_iconn_data_p[i - 1];
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    i_iconn_valid_p[i] <= '0;
                end
                else begin
                    i_iconn_valid_p[i] <= i_iconn_valid_p[i - 1];
                end
            end
        end

        for(i = RF_STAGE_NUM + 1;i <= TOTAL_STAGE;i++) begin
            always_ff @(posedge clk) begin
                i_iconn_fl_addr_p[i] <= i_iconn_fl_addr_p[i - 1];
                i_iconn_fl_data_p[i] <= i_iconn_fl_data_p[i - 1];
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    i_iconn_fl_valid_p[i] <= '0;
                end
                else begin
                    i_iconn_fl_valid_p[i] <= i_iconn_fl_valid_p[i - 1];
                end
            end
        end

        for(i = NTT_ICONN_WRITE_INDEX + 1;i <= TOTAL_STAGE;i++) begin
            always_ff @(posedge clk) begin
                i_iconn_flr_addr_p[i] <= i_iconn_flr_addr_p[i - 1];
                i_iconn_flr_data_p[i] <= i_iconn_flr_data_p[i - 1];
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    i_iconn_flr_valid_p[i] <= '0;
                end
                else begin
                    i_iconn_flr_valid_p[i] <= i_iconn_flr_valid_p[i - 1];
                end
            end
        end

        for(i = RF_STAGE_NUM + 1;i <= ALU_INPUT_INDEX;i++) begin
            always_ff @(posedge clk) begin
                mux_o_opa_p[i] <= mux_o_opa_p[i - 1];
                mux_o_opb_p[i] <= mux_o_opb_p[i - 1];
            end
        end

        for(i = NTT_ICONN_WRITE_INDEX + 1;i <= TOTAL_STAGE;i++) begin
            always_ff @(posedge clk) begin
                res0_p[i] <= res0_p[i - 1];
                res1_p[i] <= res1_p[i - 1];
                mux_muxi_mau_p[i] = mux_muxi_mau_p[i - 1];
            end
        end
    endgenerate

    assign bk0_roffset = (is_ntt_p[0] | is_intt_p[0]) ? shared_raddr_p[0] : i_cnt[$clog2(NELEMENT) - 1:0];
    assign bk1_roffset = (is_ntt_p[0] | is_intt_p[0]) ? shared_raddr_p[0] : i_cnt[$clog2(NELEMENT) - 1:0];

    //rf bank0
    vxu_rfbank #(
        .ADDR_WIDTH(RF_ADDR_WIDTH + $clog2(NELEMENT)),
        .DATA_WIDTH(DATA_WIDTH),
        .READ_LATENCY(RF_READ_LATENCY)
    )i_vxu_rfbank_0(
        .clk(clk),
        .rst_n(rst_n),
        .raddr({bk0_raddr, bk0_roffset}),
        .rdata(bk0_rdata),
        .re(bk0_rvld & op_vld_p[0]),
        .waddr({bk0_waddr[TOTAL_STAGE], bk0_woffset}),
        .wdata(bk0_wdata),
        .we(bk0_wvld[TOTAL_STAGE] & op_vld_p[TOTAL_STAGE])
    );

    //rf bank1
    vxu_rfbank #(
        .ADDR_WIDTH(RF_ADDR_WIDTH + $clog2(NELEMENT)),
        .DATA_WIDTH(DATA_WIDTH),
        .READ_LATENCY(RF_READ_LATENCY)
    )i_vxu_rfbank_1(
        .clk(clk),
        .rst_n(rst_n),
        .raddr({bk1_raddr, bk1_roffset}),
        .rdata(bk1_rdata),
        .re(bk1_rvld & op_vld_p[0]),
        .waddr({bk1_waddr[TOTAL_STAGE], bk1_woffset}),
        .wdata(bk1_wdata),
        .we(bk1_wvld[TOTAL_STAGE] & op_vld_p[TOTAL_STAGE])
    );

    ntt_swap #(
        .DATA_WIDTH(DATA_WIDTH),
        .LATENCY(NTT_SWAP_LATENCY)
    )i_ntt_swap(
        .clk(clk),
        .i_alu_inout_swap(is_ntt_p[NTT_SWAP_INDEX] && alu_inout_swap_p[NTT_SWAP_INDEX]),
        .i_data0(opa_pre),
        .i_data1(opb_pre),
        .o_data0(opa),
        .o_data1(opb)
    );

    //alu
    modalu #(
        .data_width_p(DATA_WIDTH),
        .mul_level_p(ALU_MUL_LEVEL),
        .mul_stage_p(ALU_MUL_STAGE),
        .last_stage_p(ALU_LAST_STAGE),
        .modhalf_stage_p(ALU_MODHALF_STAGE)
    )i_modalu(
        .clk_i(clk),
        .rst_n(rst_n),
        .valid_i(op_vld_p[ALU_INPUT_INDEX] & (bk0_wvld[ALU_INPUT_INDEX] | bk1_wvld[ALU_INPUT_INDEX])),
        .opcode_i(op_alu_p[ALU_INPUT_INDEX]),
        .opa_i(opa),
        .opb_i(opb),
        .ops_i(ops),
        .mod_i(mod_q_p[ALU_INPUT_INDEX]),
        .imod_i(mod_iq_p[ALU_INPUT_INDEX]),
        .mod_width(6'd60),
        .res0_o(res0_p[INTT_SWAP_INDEX]),
        .res1_o(res1_p[INTT_SWAP_INDEX])
    );

    ntt_swap #(
        .DATA_WIDTH(DATA_WIDTH),
        .LATENCY(INTT_SWAP_LATENCY)
    )i_intt_swap(
        .clk(clk),
        .i_alu_inout_swap(is_intt_p[INTT_SWAP_INDEX] && alu_inout_swap_p[INTT_SWAP_INDEX]),
        .i_data0(res1_p[INTT_SWAP_INDEX]),
        .i_data1(res0_p[INTT_SWAP_INDEX]),
        .o_data0(res1_p[NTT_ICONN_WRITE_INDEX]),
        .o_data1(res0_p[NTT_ICONN_WRITE_INDEX])
    );

    generate
        for(i = 0;i <= TOTAL_STAGE;i++) begin
            assign is_ntt_p[i] = op_ntt_p[i] == 'b010;
            assign is_intt_p[i] = op_ntt_p[i] == 'b011;
        end
    endgenerate

    //mux_o
    assign mux_o_opa_p[RF_STAGE_NUM] = mux_o_p[RF_STAGE_NUM][3] ? bk1_rdata : bk0_rdata;
    assign mux_o_opb_p[RF_STAGE_NUM] = mux_o_p[RF_STAGE_NUM][2] ? bk1_rdata : bk0_rdata;

    //mux_mau_opa
    assign opa_pre = is_ntt_p[NTT_SWAP_INDEX] ? i_iconn_fl_data_p[NTT_SWAP_INDEX] : mux_o_opa_p[NTT_SWAP_INDEX];
    //mux_mau_opb
    assign opb_pre = (is_ntt_p[NTT_SWAP_INDEX] || is_intt_p[NTT_SWAP_INDEX]) ? i_pair_iconn : mux_o_opb_p[NTT_SWAP_INDEX];
    //mux_mau_ops
    assign ops = (is_ntt_p[ALU_INPUT_INDEX] || is_intt_p[ALU_INPUT_INDEX]) ? tf_mem[shared_tfaddr_p[ALU_INPUT_INDEX]] : scalar_alu_p[ALU_INPUT_INDEX];
    //mux_muxi_mau
    assign mux_muxi_mau_p[NTT_ICONN_WRITE_INDEX] = ((is_ntt_p[NTT_ICONN_WRITE_INDEX] || is_intt_p[NTT_ICONN_WRITE_INDEX]) && LANE_ID[0]) ? i_pair_mau : res0_p[NTT_ICONN_WRITE_INDEX];
    assign o_pair_mau = res1_p[NTT_ICONN_WRITE_INDEX];
    //mux_iconnbank2pair
    assign o_pair_iconn = is_ntt_p[NTT_SWAP_INDEX] ? i_iconn_fl_data_p[NTT_SWAP_INDEX][DATA_WIDTH - 1:0] : mux_o_opa_p[NTT_SWAP_INDEX];
    //mux_muxi_iconn
    assign mux_muxi_iconn = is_intt_p[TOTAL_STAGE] ? i_iconn_flr_data_p[TOTAL_STAGE][DATA_WIDTH - 1:0] : i_iconn_data_p[TOTAL_STAGE][DATA_WIDTH - 1:0];

    //mux_i
    assign bk0_wdata = (((mux_i_p[TOTAL_STAGE][3:2] == 'b00) && bk0_wvld[TOTAL_STAGE] && op_vld_p[TOTAL_STAGE]) ? mux_muxi_mau_p[TOTAL_STAGE] : '0) |
                       (((mux_i_p[TOTAL_STAGE][3:2] == 'b11) && bk0_wvld[TOTAL_STAGE] && op_vld_p[TOTAL_STAGE]) ? i_vp_data_p[TOTAL_STAGE] : '0) |
                       (((mux_i_p[TOTAL_STAGE][3:2] == 'b01) && bk0_wvld[TOTAL_STAGE] && op_vld_p[TOTAL_STAGE]) ? mux_muxi_iconn : '0);
    assign bk1_wdata = (((mux_i_p[TOTAL_STAGE][1:0] == 'b00) && bk1_wvld[TOTAL_STAGE] && op_vld_p[TOTAL_STAGE]) ? mux_muxi_mau_p[TOTAL_STAGE] : '0) |
                       (((mux_i_p[TOTAL_STAGE][1:0] == 'b11) && bk1_wvld[TOTAL_STAGE] && op_vld_p[TOTAL_STAGE]) ? i_vp_data_p[TOTAL_STAGE] : '0) |
                       (((mux_i_p[TOTAL_STAGE][1:0] == 'b01) && bk1_wvld[TOTAL_STAGE] && op_vld_p[TOTAL_STAGE]) ? mux_muxi_iconn : '0); 

    assign bk0_woffset = (is_ntt_p[TOTAL_STAGE] | is_intt_p[TOTAL_STAGE]) ? shared_waddr_p[TOTAL_STAGE] : (mux_i_p[TOTAL_STAGE][3:2] == 'b01) ? i_iconn_data_p[TOTAL_STAGE][ICONN_DATA_WIDTH - 1:DATA_WIDTH] : cnt_p[TOTAL_STAGE][$clog2(NELEMENT) - 1:0];
    assign bk1_woffset = (is_ntt_p[TOTAL_STAGE] | is_intt_p[TOTAL_STAGE]) ? shared_waddr_p[TOTAL_STAGE] : (mux_i_p[TOTAL_STAGE][1:0] == 'b01) ? i_iconn_data_p[TOTAL_STAGE][ICONN_DATA_WIDTH - 1:DATA_WIDTH] : cnt_p[TOTAL_STAGE][$clog2(NELEMENT) - 1:0];

    assign iconn_preoutput_data = mux_o_p[RF_STAGE_NUM][1] ? bk1_rdata : bk0_rdata;

    assign o_iconn_addr = (op_iconn_p[RF_STAGE_NUM] == 'b001 ? NODE_ADDR_WIDTH'((unsigned'(LANE_ID) * scalar_iconn_p[RF_STAGE_NUM][$clog2(NELEMENT * NLANE) - 1:0]) & ((vl_p[RF_STAGE_NUM] >> $clog2(DATA_WIDTH)) - 1)) : 'b0) |
                          (op_iconn_p[RF_STAGE_NUM] == 'b010 ? NODE_ADDR_WIDTH'(unsigned'(LANE_ID) + unsigned'(NLANE) - scalar_iconn_p[RF_STAGE_NUM]) : 'b0);
    assign o_iconn_data = {(op_iconn_p[RF_STAGE_NUM] == 'b001 ? $clog2(NELEMENT)'((((unsigned'(LANE_ID) + cnt_p[RF_STAGE_NUM] * unsigned'(NLANE)) * scalar_iconn_p[RF_STAGE_NUM][$clog2(NELEMENT * NLANE) - 1:0]) & ((vl_p[RF_STAGE_NUM] >> $clog2(DATA_WIDTH)) - 1)) >> $clog2(NLANE)) : 'b0) | 
                           (op_iconn_p[RF_STAGE_NUM] == 'b010 ? $clog2(NELEMENT)'(((unsigned'(LANE_ID) + cnt_p[RF_STAGE_NUM] * unsigned'(NLANE) + (vl_p[RF_STAGE_NUM] >> $clog2(DATA_WIDTH)) - scalar_iconn_p[RF_STAGE_NUM]) & ((vl_p[RF_STAGE_NUM] >> $clog2(DATA_WIDTH)) - 1)) >> $clog2(NLANE)) : 'b0)
                           , ((op_iconn_p[RF_STAGE_NUM] == 'b001) && ((((unsigned'(LANE_ID) + cnt_p[RF_STAGE_NUM] * unsigned'(NLANE)) * scalar_iconn_p[RF_STAGE_NUM][$clog2(NELEMENT * NLANE) - 1:0]) & ((vl_p[RF_STAGE_NUM] >> ($clog2(DATA_WIDTH) - 1)) - 1))) >= (vl_p[RF_STAGE_NUM] >> $clog2(DATA_WIDTH))) ? (mod_q_p[RF_STAGE_NUM] - iconn_preoutput_data) : iconn_preoutput_data};
    assign o_iconn_valid = op_vld_p[RF_STAGE_NUM] && (bk0_wvld[RF_STAGE_NUM] || bk1_wvld[RF_STAGE_NUM]) && (op_iconn_p[RF_STAGE_NUM] != 'b0);
    assign o_iconn_fl_mode = op_iconn_p[RF_STAGE_NUM] == 'b100;
    assign o_iconn_flr_addr = 0;
    assign o_iconn_flr_data = LANE_ID[0] ? i_pair_mau : res0_p[NTT_ICONN_WRITE_INDEX];
    assign o_iconn_flr_valid = op_vld_p[NTT_ICONN_WRITE_INDEX] && (op_iconn_p[NTT_ICONN_WRITE_INDEX] == 'b101);
endmodule