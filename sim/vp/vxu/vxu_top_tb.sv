//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: VP
// Module Name: vxu_top_tb
// Modify Date: 
//
// Description:
// VXU verification testbench
//////////////////////////////////////////////////

`timescale 1ns/100ps

`define assert(condition) assert((condition)) else begin #10; $finish; end
`define assert_equal(_cycle, _expected, _actual) assert((_expected) === (_actual)) else begin $display("cycle = %0d, expected = %0x, actual = %0x", (_cycle), (_expected), (_actual)); assert_failed = 1; end
`define assert_equal_flag(_cycle, _expected, _actual, _flag) assert((_expected) === (_actual)) else begin $display("cycle = %0d, expected = %0x, actual = %0x", (_cycle), (_expected), (_actual)); _flag = 1; end

//alu model
virtual class AluFunc #(int data_width_p = 64);

    static function logic [data_width_p-1:0] modadd (
        input logic [data_width_p-1:0] opa,
        input logic [data_width_p-1:0] opb,
        input logic [data_width_p-1:0] mod
    );
        logic [data_width_p:0] sum;
        logic [data_width_p-1:0] res;
        if(opa >= mod) opa -= mod;
        if(opb >= mod) opb -= mod;
        sum = opa + opb;
        if (sum >= mod) res = sum - mod;
        else res = sum[data_width_p-1:0];

        return res;
    endfunction

    static function logic [data_width_p-1:0] modsub (
        input logic [data_width_p-1:0] opa,
        input logic [data_width_p-1:0] opb,
        input logic [data_width_p-1:0] mod
    );
        logic [data_width_p:0] sum;
        logic [data_width_p-1:0] res;
        if(opa >= mod) opa -= mod;
        if(opb >= mod) opb -= mod;
        sum  = opa + mod;

        if (opa >= opb) res = opa - opb;
        else res = sum - opb;

        return res;
    endfunction

    static function logic [data_width_p-1:0] mod (
        input logic [data_width_p-1:0] opa,
        input logic [data_width_p-1:0] mod_i,
        input logic [data_width_p-1:0] imod_i
    );
        logic [data_width_p-1:0] opb, res;
        if(opa >= mod) opa -= mod;
        opb = data_width_p'(1);
        res = modmul(opa, opb, mod_i, imod_i);
        return res;
    endfunction

    static function logic [data_width_p-1:0] modmul (
        input logic [data_width_p-1:0] opa,
        input logic [data_width_p-1:0] opb,
        input logic [data_width_p-1:0] mod,
        input logic [data_width_p-1:0] imod
    );
        logic [2*data_width_p-1:0]prod;
        logic [data_width_p:0] prod_shift;
        logic [2*data_width_p+1:0] mid;
        logic [data_width_p:0] mid_shift;
        logic [2*data_width_p:0] estim;
        logic [data_width_p-1:0] diff;
        logic [data_width_p-1:0] res;
        logic [$clog2(data_width_p)-1:0] mod_width;
        logic [data_width_p-1:0] diff_X;
        logic [data_width_p-1:0] diff_Y;

        if(opa >= mod) opa -= mod;
        if(opb >= mod) opb -= mod;
        prod       = opa * opb;   
        prod_shift = prod >> (mod_width-2);
        mid        = prod_shift * imod; 
        mid_shift  = mid >> (mod_width+3);
        estim      = mid_shift * mod;
        diff_X     = prod & ((1<<(mod_width+1)) - 1);
        diff_Y     = estim & ((1<<(mod_width+1)) - 1);
        diff       = ((diff_X | (1<<(mod_width+1))) - diff_Y) & ((1<<mod_width+1) - 1);


        
        if (diff < mod) res = diff;
        else res = diff - mod;
        return res;
    endfunction

endclass

module top;
    parameter VLMAX = 1 << 16;
    parameter OP_WIDTH = 2;
    parameter DATA_WIDTH = 64;
    parameter RF_ADDR_WIDTH = 4;
    parameter ALU_OP_WIDTH = 5;
    parameter ICONN_OP_WIDTH = 3;
    parameter NTT_OP_WIDTH = 3;
    parameter MUX_O_WIDTH = 4;
    parameter MUX_I_WIDTH = 4;
    parameter NLANE = 32;
    parameter NTT_SWAP_LATENCY = 2;
    parameter ALU_MUL_LEVEL = 2;
    parameter ALU_MUL_STAGE = 2;
    parameter ALU_LAST_STAGE = 2;
    parameter ALU_MODHALF_STAGE = 1;
    parameter INTT_SWAP_LATENCY = 1;
    parameter RF_READ_LATENCY = 3;
    parameter SPM_LATENCY = 0;
    parameter CNT_WIDTH = i_vxu_top.CNT_WIDTH;
    parameter NELEMENT = i_vxu_top.NELEMENT;
    parameter NODE_ADDR_WIDTH = $clog2(NLANE);
    parameter TF_ITEM_NUM = 3;
    parameter TF_ADDR_WIDTH = 16;

    localparam RF_WRITE_LATENCY = 1;
    localparam RF_STAGE_NUM = RF_READ_LATENCY;
    localparam NTT_ICONN_READ_LATENCY = 1;
    localparam NTT_ICONN_WRITE_LATENCY = 1;
    localparam ALU_STAGE_NUM = 3 * ALU_MUL_STAGE + ALU_LAST_STAGE + ALU_MODHALF_STAGE + 1;
    localparam TOTAL_STAGE = RF_STAGE_NUM + NTT_ICONN_READ_LATENCY + NTT_SWAP_LATENCY + ALU_STAGE_NUM + INTT_SWAP_LATENCY + NTT_ICONN_WRITE_LATENCY + RF_WRITE_LATENCY;

    typedef struct packed
    {
        longint unsigned id;

        logic i_op_vld;
        logic[OP_WIDTH - 1:0] i_op_cfg;
        logic[DATA_WIDTH - 1:0] i_scalar_cfg;
        logic[CNT_WIDTH - 1:0] i_cnt;
        logic[RF_ADDR_WIDTH:0] i_op_bk0_r;
        logic[RF_ADDR_WIDTH:0] i_op_bk0_w;
        logic[RF_ADDR_WIDTH:0] i_op_bk1_r;
        logic[RF_ADDR_WIDTH:0] i_op_bk1_w;
        logic[ALU_OP_WIDTH - 1:0] i_op_alu;
        logic[DATA_WIDTH - 1:0] i_scalar_alu;
        logic[ICONN_OP_WIDTH - 1:0] i_op_iconn;
        logic[DATA_WIDTH - 1:0] i_scalar_iconn;
        logic[NTT_OP_WIDTH - 1:0] i_op_ntt;
        logic[MUX_O_WIDTH - 1:0] i_mux_o;
        logic[MUX_I_WIDTH - 1:0] i_mux_i;

        logic[NLANE * DATA_WIDTH - 1:0] i_vp_data;

        logic[$clog2(NELEMENT) - 1:0] woffset;
        logic iconn_need_minus;
        logic[NODE_ADDR_WIDTH - 1:0] target_lane_id;

        longint unsigned latency;
        longint unsigned timestamp;
        bit op_alu;
        bit op_vle;
        bit op_vse;
        bit op_iconn;

        logic[DATA_WIDTH - 1:0] vl;
        logic[DATA_WIDTH - 1:0] mod_q;
        logic[DATA_WIDTH - 1:0] mod_iq;
    }op_pack_t;

    logic clk;
    logic rst_n;
    
    logic i_op_vld;
    logic[CNT_WIDTH - 1:0] i_cnt;
    logic i_comp_vld;
    logic[OP_WIDTH - 1:0] i_op_cfg;
    logic[DATA_WIDTH - 1:0] i_scalar_cfg;
    logic[RF_ADDR_WIDTH:0] i_op_bk0_r;
    logic[RF_ADDR_WIDTH:0] i_op_bk0_w;
    logic[RF_ADDR_WIDTH:0] i_op_bk1_r;
    logic[RF_ADDR_WIDTH:0] i_op_bk1_w;
    logic[ALU_OP_WIDTH - 1:0] i_op_alu;
    logic[DATA_WIDTH - 1:0] i_scalar_alu;
    logic[ICONN_OP_WIDTH - 1:0] i_op_iconn;
    logic[DATA_WIDTH - 1:0] i_scalar_iconn;
    logic[NTT_OP_WIDTH - 1:0] i_op_ntt;
    logic[MUX_O_WIDTH - 1:0] i_mux_o;
    logic[MUX_I_WIDTH - 1:0] i_mux_i;
    logic[CNT_WIDTH:0] o_ntt_inst_std_cnt;

    logic[NLANE * DATA_WIDTH - 1:0] i_vp_data;
    logic[NLANE * DATA_WIDTH - 1:0] o_vp_data;

    logic[DATA_WIDTH - 1:0] rfbank0_q[0:NLANE - 1][$];
    logic[DATA_WIDTH - 1:0] rfbank1_q[0:NLANE - 1][$];
    logic[DATA_WIDTH - 1:0] rfbank0_vse_q[0:NLANE - 1][$];
    logic[DATA_WIDTH - 1:0] rfbank1_vse_q[0:NLANE - 1][$];
    logic[DATA_WIDTH - 1:0] rfbank0_iconn_q[0:NLANE - 1][$];
    logic[DATA_WIDTH - 1:0] rfbank1_iconn_q[0:NLANE - 1][$];
    logic rfbank0_re_last[0:NLANE - 1][0:RF_READ_LATENCY];
    logic rfbank1_re_last[0:NLANE - 1][0:RF_READ_LATENCY];
    longint unsigned cur_cycle;
    genvar i, j;
    int k;
    logic[DATA_WIDTH - 1:0] t_data;

    longint unsigned total_op;
    longint unsigned passed_op;
    longint unsigned failed_op;
    longint unsigned ignored_op;
    bit assert_failed;
    bit ignored;

    mailbox#(op_pack_t) lane_mb[0:NLANE - 1];
    mailbox#(op_pack_t) lane_cfg_mb[0:NLANE - 1];
    mailbox#(op_pack_t) lane_vse_mb[0:NLANE - 1];
    mailbox#(op_pack_t) lane_iconn_mb[0:NLANE - 1];
    op_pack_t lane_cur_op[0:NLANE - 1];
    longint unsigned lane_assert_failed[0:NLANE - 1];
    longint unsigned lane_ignored[0:NLANE - 1];
    longint unsigned lane_op_cmp_result[0:NLANE - 1][$];
    longint unsigned lane_op_ignored_result[0:NLANE - 1][$];
    logic[DATA_WIDTH - 1:0] lane_opa[0:NLANE - 1];
    logic[DATA_WIDTH - 1:0] lane_opb[0:NLANE - 1];
    logic[DATA_WIDTH - 1:0] lane_res[0:NLANE - 1];

    op_pack_t cur_op_p[0:NLANE - 1][0:TOTAL_STAGE];

    vxu_top#(
        .VLMAX(VLMAX),
        .OP_WIDTH(OP_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .RF_ADDR_WIDTH(RF_ADDR_WIDTH),
        .ALU_OP_WIDTH(ALU_OP_WIDTH),
        .ICONN_OP_WIDTH(ICONN_OP_WIDTH),
        .NTT_OP_WIDTH(NTT_OP_WIDTH),
        .MUX_O_WIDTH(MUX_O_WIDTH),
        .MUX_I_WIDTH(MUX_I_WIDTH),
        .NLANE(NLANE),
        .NTT_SWAP_LATENCY(NTT_SWAP_LATENCY),
        .ALU_MUL_LEVEL(ALU_MUL_LEVEL),
        .ALU_MUL_STAGE(ALU_MUL_STAGE),
        .ALU_LAST_STAGE(ALU_LAST_STAGE),
        .ALU_MODHALF_STAGE(ALU_MODHALF_STAGE),
        .INTT_SWAP_LATENCY(INTT_SWAP_LATENCY),
        .RF_READ_LATENCY(RF_READ_LATENCY),
        .SPM_LATENCY(SPM_LATENCY),
        .TF_ITEM_NUM(TF_ITEM_NUM),
        .TF_ADDR_WIDTH(TF_ADDR_WIDTH)
    )i_vxu_top(
        .*
    );

    task wait_clk;
        @(posedge clk);
        #0.1;
    endtask

    task eval;
        #0.1;
    endtask

    task reset;
        rst_n = 0;
        i_op_vld = '0;
        i_comp_vld = '0;
        i_cnt = '0;
        i_op_cfg = 'x;
        i_scalar_cfg = 'x;
        i_op_bk0_r = 'x;
        i_op_bk0_w = 'x;
        i_op_bk1_r = 'x;
        i_op_bk1_w = 'x;
        i_op_alu = 'x;
        i_scalar_alu = 'x;
        i_op_iconn = 'x;
        i_scalar_iconn = 'x;
        i_op_ntt = 'x;
        i_mux_o = 'x;
        i_mux_i = 'x;
        i_vp_data = 'x;
        wait_clk();
        rst_n = 1;
        eval();
    endtask

    function op_pack_t get_default_pack();
        op_pack_t pack;
        pack.i_op_vld = 'b0;
        pack.i_cnt = 'b0;
        pack.i_op_cfg = 'b00;
        pack.i_scalar_cfg = 'x;
        pack.i_op_bk0_r = '0;
        pack.i_op_bk0_w = '0;
        pack.i_op_bk1_r = '0;
        pack.i_op_bk1_w = '0;
        pack.i_op_alu = '0;
        pack.i_scalar_alu = 'x;
        pack.i_op_iconn = '0;
        pack.i_scalar_iconn = '0;
        pack.i_op_ntt = '0;
        pack.i_mux_o = 'x;
        pack.i_mux_i = 'x;
        pack.i_vp_data = 'x;
        pack.latency = 0;
        pack.op_alu = 0;
        pack.op_vle = 0;
        pack.op_vse = 0;
        pack.op_iconn = 0;
        return pack;
    endfunction;

    //emit functions
    function op_pack_t emit_vsetvl(input logic[DATA_WIDTH - 1:0] value);
        op_pack_t pack;
        pack = get_default_pack();
        pack.i_op_vld = 'b1;
        pack.i_op_cfg = 'b01;
        pack.i_scalar_cfg = value;
        pack.i_op_bk0_r = '0;
        pack.i_op_bk0_w = '0;
        pack.i_op_bk1_r = '0;
        pack.i_op_bk1_w = '0;
        pack.i_op_alu = '0;
        pack.i_scalar_alu = 'x;
        pack.i_mux_o = 'x;
        pack.i_mux_i = 'x;
        pack.i_vp_data = 'x;
        pack.latency = 1;
        pack.op_alu = 0;
        pack.op_vle = 0;
        pack.op_vse = 0;
        return pack;
    endfunction

    function op_pack_t emit_vsetq(logic[DATA_WIDTH - 1:0] value);
        op_pack_t pack;
        pack = get_default_pack();
        pack.i_op_vld = 'b1;
        pack.i_op_cfg = 'b10;
        pack.i_scalar_cfg = value;
        pack.i_op_bk0_r = '0;
        pack.i_op_bk0_w = '0;
        pack.i_op_bk1_r = '0;
        pack.i_op_bk1_w = '0;
        pack.i_op_alu = '0;
        pack.i_scalar_alu = 'x;
        pack.i_mux_o = 'x;
        pack.i_mux_i = 'x;
        pack.i_vp_data = 'x;
        pack.latency = 1;
        pack.op_alu = 0;
        pack.op_vle = 0;
        pack.op_vse = 0;
        return pack;
    endfunction

    function op_pack_t emit_vsetiq(logic[DATA_WIDTH - 1:0] value);
        op_pack_t pack;
        pack = get_default_pack();
        pack.i_op_vld = 'b1;
        pack.i_op_cfg = 'b11;
        pack.i_scalar_cfg = value;
        pack.i_op_bk0_r = '0;
        pack.i_op_bk0_w = '0;
        pack.i_op_bk1_r = '0;
        pack.i_op_bk1_w = '0;
        pack.i_op_alu = '0;
        pack.i_scalar_alu = 'x;
        pack.i_mux_o = 'x;
        pack.i_mux_i = 'x;
        pack.i_vp_data = 'x;
        pack.latency = 1;
        return pack;
    endfunction

    function op_pack_t emit_vv(logic[ALU_OP_WIDTH - 1:0] alu_op, logic[RF_ADDR_WIDTH:0] rs1, logic[RF_ADDR_WIDTH:0] rs2, logic[RF_ADDR_WIDTH:0] rd);
        op_pack_t pack;
        pack = get_default_pack();
        pack.i_op_vld = 'b1;
        pack.i_op_cfg = 'b00;
        pack.i_scalar_cfg = 'x;
        pack.i_op_bk0_r = rs1[0] ? {1'b1, rs2[RF_ADDR_WIDTH:1]} : {1'b1, rs1[RF_ADDR_WIDTH:1]};
        pack.i_op_bk0_w = rd[0] ? '0 : {1'b1, rd[RF_ADDR_WIDTH:1]};
        pack.i_op_bk1_r = rs1[0] ? {1'b1, rs1[RF_ADDR_WIDTH:1]} : {1'b1, rs2[RF_ADDR_WIDTH:1]};
        pack.i_op_bk1_w = rd[0] ? {1'b1, rd[RF_ADDR_WIDTH:1]} : '0;
        pack.i_op_alu = alu_op;
        pack.i_scalar_alu = 'x;
        pack.i_mux_o = {rs1[0], rs2[0], 2'bxx};
        pack.i_mux_i = rd[0] ? 4'bxx00 : 4'b00xx;
        pack.i_vp_data = 'x;
        pack.latency = TOTAL_STAGE;
        pack.op_alu = 1;
        return pack;
    endfunction

    function op_pack_t emit_vs(logic[ALU_OP_WIDTH - 1:0] alu_op, logic[RF_ADDR_WIDTH:0] rs1, logic[DATA_WIDTH - 1:0] scalar, logic[RF_ADDR_WIDTH:0] rd);
        op_pack_t pack;
        pack = get_default_pack();
        pack.i_op_vld = 'b1;
        pack.i_op_cfg = 'b00;
        pack.i_scalar_cfg = 'x;
        pack.i_op_bk0_r = rs1[0] ? '0 : {1'b1, rs1[RF_ADDR_WIDTH:1]};
        pack.i_op_bk0_w = rd[0] ? '0 : {1'b1, rd[RF_ADDR_WIDTH:1]};
        pack.i_op_bk1_r = rs1[0] ? {1'b1, rs1[RF_ADDR_WIDTH:1]} : '0;
        pack.i_op_bk1_w = rd[0] ? {1'b1, rd[RF_ADDR_WIDTH:1]} : '0;
        pack.i_op_alu = alu_op;
        pack.i_scalar_alu = scalar;
        pack.i_mux_o = {rs1[0], 3'bxxx};
        pack.i_mux_i = rd[0] ? 4'bxx00 : 4'b00xx;
        pack.i_vp_data = 'x;
        pack.latency = TOTAL_STAGE;
        pack.op_alu = 1;
        return pack;
    endfunction

    function op_pack_t emit_v(logic[ALU_OP_WIDTH - 1:0] alu_op, logic[RF_ADDR_WIDTH:0] rs1, logic[RF_ADDR_WIDTH:0] rd);
        op_pack_t pack;
        pack = get_default_pack();
        pack.i_op_vld = 'b1;
        pack.i_op_cfg = 'b00;
        pack.i_scalar_cfg = 'x;
        pack.i_op_bk0_r = rs1[0] ? '0 : {1'b1, rs1[RF_ADDR_WIDTH:1]};
        pack.i_op_bk0_w = rd[0] ? '0 : {1'b1, rd[RF_ADDR_WIDTH:1]};
        pack.i_op_bk1_r = rs1[0] ? {1'b1, rs1[RF_ADDR_WIDTH:1]} : '0;
        pack.i_op_bk1_w = rd[0] ? {1'b1, rd[RF_ADDR_WIDTH:1]} : '0;
        pack.i_op_alu = alu_op;
        pack.i_scalar_alu = 'x;
        pack.i_mux_o = {rs1[0], 3'bxxx};
        pack.i_mux_i = rd[0] ? 4'bxx00 : 4'b00xx;
        pack.i_vp_data = 'x;
        pack.latency = TOTAL_STAGE;
        pack.op_alu = 1;
        return pack;
    endfunction

    function op_pack_t emit_vfqmul_vv(logic[RF_ADDR_WIDTH:0] rs1, logic[RF_ADDR_WIDTH:0] rs2, logic[RF_ADDR_WIDTH:0] rd);
        return emit_vv('b00000, rs1, rs2, rd);
    endfunction

    function op_pack_t emit_vfqmul_vs(logic[RF_ADDR_WIDTH:0] rs1, logic[DATA_WIDTH - 1:0] scalar, logic[RF_ADDR_WIDTH:0] rd);
        return emit_vs('b00100, rs1, scalar, rd);
    endfunction

    function op_pack_t emit_vfqadd_vv(logic[RF_ADDR_WIDTH:0] rs1, logic[RF_ADDR_WIDTH:0] rs2, logic[RF_ADDR_WIDTH:0] rd);
        return emit_vv('b00001, rs1, rs2, rd);
    endfunction

    function op_pack_t emit_vfqadd_vs(logic[RF_ADDR_WIDTH:0] rs1, logic[DATA_WIDTH - 1:0] scalar, logic[RF_ADDR_WIDTH:0] rd);
        return emit_vs('b00101, rs1, scalar, rd);
    endfunction

    function op_pack_t emit_vfqsub_vv(logic[RF_ADDR_WIDTH:0] rs1, logic[RF_ADDR_WIDTH:0] rs2, logic[RF_ADDR_WIDTH:0] rd);
        return emit_vv('b00010, rs1, rs2, rd);
    endfunction

    function op_pack_t emit_vfqsub_vs(logic[RF_ADDR_WIDTH:0] rs1, logic[DATA_WIDTH - 1:0] scalar, logic[RF_ADDR_WIDTH:0] rd);
        return emit_vs('b00110, rs1, scalar, rd);
    endfunction

    function op_pack_t emit_vfqsub_sv(logic[RF_ADDR_WIDTH:0] rs1, logic[DATA_WIDTH - 1:0] scalar, logic[RF_ADDR_WIDTH:0] rd);
        return emit_vs('b01010, rs1, scalar, rd);
    endfunction

    function op_pack_t emit_vfqmod_v(logic[RF_ADDR_WIDTH:0] rs1, logic[RF_ADDR_WIDTH:0] rd);
        return emit_v('b00011, rs1, rd);
    endfunction

    function op_pack_t emit_vcp(logic[RF_ADDR_WIDTH:0] rs1, logic[RF_ADDR_WIDTH:0] rd);
        return emit_vs('b00101, rs1, '0, rd);
    endfunction

    function op_pack_t emit_vle(logic[RF_ADDR_WIDTH:0] rd, logic[NLANE * DATA_WIDTH - 1:0] vp_data);
        op_pack_t pack;
        pack = get_default_pack();
        pack.i_op_vld = 'b1;
        pack.i_op_cfg = 'b00;
        pack.i_scalar_cfg = 'x;
        pack.i_op_bk0_r = '0;
        pack.i_op_bk0_w = rd[0] ? '0 : {1'b1, rd[RF_ADDR_WIDTH:1]};
        pack.i_op_bk1_r = '0;
        pack.i_op_bk1_w = rd[0] ? {1'b1, rd[RF_ADDR_WIDTH:1]} : '0;
        pack.i_op_alu = 'x;
        pack.i_scalar_alu = 'x;
        pack.i_mux_o = 'x;
        pack.i_mux_i = rd[0] ? 4'bxx11 : 4'b11xx;
        pack.i_vp_data = vp_data;
        pack.latency = TOTAL_STAGE;
        pack.op_vle = 1;
        return pack;
    endfunction

    function op_pack_t emit_vse(logic[RF_ADDR_WIDTH:0] rs1);
        op_pack_t pack;
        pack = get_default_pack();
        pack.i_op_vld = 'b1;
        pack.i_op_cfg = 'b00;
        pack.i_scalar_cfg = 'x;
        pack.i_op_bk0_r = rs1[0] ? '0 : {1'b1, rs1[RF_ADDR_WIDTH:1]};
        pack.i_op_bk0_w = '0;
        pack.i_op_bk1_r = rs1[0] ? {1'b1, rs1[RF_ADDR_WIDTH:1]} : '0;
        pack.i_op_bk1_w = '0;
        pack.i_op_alu = '0;
        pack.i_scalar_alu = 'x;
        pack.i_mux_o = {3'bxxx, rs1[0]};
        pack.i_mux_i = 'x;
        pack.i_vp_data = 'x;
        pack.latency = TOTAL_STAGE - 1;
        pack.op_vse = 1;
        return pack;
    endfunction

    function op_pack_t emit_iconn(logic[ICONN_OP_WIDTH - 1:0] iconn_op, logic[RF_ADDR_WIDTH:0] rs1, logic[DATA_WIDTH - 1:0] scalar, logic[RF_ADDR_WIDTH:0] rd);
        op_pack_t pack;
        pack = get_default_pack();
        pack.i_op_vld = 'b1;
        pack.i_op_cfg = 'b00;
        pack.i_scalar_cfg = 'x;
        pack.i_op_bk0_r = rs1[0] ? '0 : {1'b1, rs1[RF_ADDR_WIDTH:1]};
        pack.i_op_bk0_w = rd[0] ? '0 : {1'b1, rd[RF_ADDR_WIDTH:1]};
        pack.i_op_bk1_r = rs1[0] ? {1'b1, rs1[RF_ADDR_WIDTH:1]} : '0;
        pack.i_op_bk1_w = rd[0] ? {1'b1, rd[RF_ADDR_WIDTH:1]} : '0;
        pack.i_op_alu = 'x;
        pack.i_scalar_alu = 'x;
        pack.i_op_iconn = iconn_op;
        pack.i_scalar_iconn = scalar;
        pack.i_mux_o = {2'bx, rs1[0], 1'bx};
        pack.i_mux_i = rd[0] ? 4'bxx01 : 4'b01xx;
        pack.i_vp_data = 'x;
        pack.latency = TOTAL_STAGE;
        pack.op_iconn = 1;
        return pack;
    endfunction

    function op_pack_t emit_vroli(logic[RF_ADDR_WIDTH:0] rs1, logic[DATA_WIDTH - 1:0] scalar, logic[RF_ADDR_WIDTH:0] rd);
        return emit_iconn('b010, rs1, scalar, rd);
    endfunction

    function op_pack_t emit_vaut(logic[RF_ADDR_WIDTH:0] rs1, logic[DATA_WIDTH - 1:0] scalar, logic[RF_ADDR_WIDTH:0] rd);
        return emit_iconn('b001, rs1, scalar, rd);
    endfunction

    function op_pack_t emit_none();
        op_pack_t pack;
        pack.i_op_vld = 'b0;
        pack.i_op_cfg = 'x;
        pack.i_scalar_cfg = 'x;
        pack.i_op_bk0_r = 'x;
        pack.i_op_bk0_w = 'x;
        pack.i_op_bk1_r = 'x;
        pack.i_op_bk1_w = 'x;
        pack.i_op_alu = 'x;
        pack.i_scalar_alu = 'x;
        pack.i_op_iconn = '0;
        pack.i_scalar_iconn = 'x;
        pack.i_op_ntt = '0;
        pack.i_mux_o = 'x;
        pack.i_mux_i = 'x;
        pack.i_vp_data = 'x;
        pack.latency = 0;
        pack.op_alu = 0;
        pack.op_vle = 0;
        pack.op_vse = 0;
        pack.op_iconn = 0;
        return pack;
    endfunction

    task fill_op_port(input op_pack_t op_pack);
        i_op_vld = op_pack.i_op_vld;
        i_comp_vld = op_pack.i_op_vld;
        i_cnt = op_pack.i_cnt;
        i_op_cfg = op_pack.i_op_cfg;
        i_scalar_cfg = op_pack.i_scalar_cfg;
        i_op_bk0_r = op_pack.i_op_bk0_r;
        i_op_bk0_w = op_pack.i_op_bk0_w;
        i_op_bk1_r = op_pack.i_op_bk1_r;
        i_op_bk1_w = op_pack.i_op_bk1_w;
        i_op_alu = op_pack.i_op_alu;
        i_scalar_alu = op_pack.i_scalar_alu;
        i_op_iconn = op_pack.i_op_iconn;
        i_scalar_iconn = op_pack.i_scalar_iconn;
        i_op_ntt = op_pack.i_op_ntt;
        i_mux_o = op_pack.i_mux_o;
        i_mux_i = op_pack.i_mux_i;
        i_vp_data = op_pack.i_vp_data;
    endtask

    logic[DATA_WIDTH - 1:0] cur_vl;

    task emit_op(input int unsigned id, input op_pack_t op_pack);
        op_pack_t t_pack;
        logic[$clog2(NELEMENT) - 1:0] woffset[0:NLANE - 1];
        logic iconn_need_minus[0:NLANE - 1];
        logic need_minus;
        logic[NODE_ADDR_WIDTH - 1:0] target_lane_id[0:NLANE - 1];
        logic[NODE_ADDR_WIDTH - 1:0] target;
        logic[$clog2(NELEMENT) - 1:0] rowaddr;

        op_pack.i_scalar_iconn = op_pack.i_scalar_iconn % (cur_vl / DATA_WIDTH);
        t_pack = op_pack;
        fill_op_port(op_pack);
        t_pack.id = id;
        t_pack.timestamp = cur_cycle;
        t_pack.vl = i_vxu_top.vxu_lane_block[0].i_vxu_lane.vl;
        t_pack.mod_q = i_vxu_top.vxu_lane_block[0].i_vxu_lane.mod_q;
        t_pack.mod_iq = i_vxu_top.vxu_lane_block[0].i_vxu_lane.mod_iq;

        if(op_pack.i_op_vld && op_pack.op_iconn) begin
            for(k = 0;k < NLANE;k++) begin
                if(op_pack.i_op_iconn == 'b001) begin
                    target = (k * op_pack.i_scalar_iconn) % (cur_vl / DATA_WIDTH) % NLANE;
                    rowaddr = (((k + op_pack.i_cnt * NLANE) * op_pack.i_scalar_iconn) % (cur_vl / DATA_WIDTH)) / NLANE;
                    need_minus = (((k + op_pack.i_cnt * NLANE) * op_pack.i_scalar_iconn) % (DATA_WIDTH'(2) * cur_vl / DATA_WIDTH)) >= (cur_vl / DATA_WIDTH);
                end
                else begin
                    target = (k + NLANE - op_pack.i_scalar_iconn) % NLANE;
                    rowaddr = ((k + op_pack.i_cnt * NLANE + (cur_vl / DATA_WIDTH) - op_pack.i_scalar_iconn) % (cur_vl / DATA_WIDTH)) / NLANE;
                    need_minus = 1'b0;
                end

                woffset[target] = rowaddr;
                iconn_need_minus[target] = need_minus;
                //$display("woffset[%0d -> %0d] = %0x", k, target, rowaddr);
                target_lane_id[k] = target;
            end
        end

        if(op_pack.i_op_vld) begin
            if(op_pack.i_op_cfg == 'b01) begin
                cur_vl = op_pack.i_scalar_cfg;
            end

            for(k = 0;k < NLANE;k++) begin
                if(t_pack.i_op_cfg == 2'b00) begin
                    if(t_pack.op_vse) begin
                        lane_vse_mb[k].put(t_pack);
                        //$display("emit vse at %0d", cur_cycle);
                    end
                    else if(t_pack.op_iconn) begin
                        t_pack.woffset = woffset[k];
                        t_pack.iconn_need_minus = iconn_need_minus[k];
                        t_pack.target_lane_id = target_lane_id[k];
                        lane_iconn_mb[k].put(t_pack);
                        //$display("emit iconn at %0d", cur_cycle);
                    end
                    else begin
                        lane_mb[k].put(t_pack);
                        //$display("emit other at %0d", cur_cycle);
                    end
                end
                else begin
                    lane_cfg_mb[k].put(t_pack);
                    //$display("emit cfg at %0d", cur_cycle);
                end

                cur_op_p[k][0] = t_pack;
            end

            total_op++;
        end

        wait_clk();
        fill_op_port(emit_none());

        for(k = 0;k < NLANE;k++) begin
            cur_op_p[k][0] = emit_none();
        end
    endtask

    function logic[DATA_WIDTH - 1:0] get_alu_res(logic[ALU_OP_WIDTH - 1:0] opcode,
                                                 logic[DATA_WIDTH - 1:0] opa,
                                                 logic[DATA_WIDTH - 1:0] opb,
                                                 logic[DATA_WIDTH - 1:0] ops,
                                                 logic[DATA_WIDTH - 1:0] mod,
                                                 logic[DATA_WIDTH - 1:0] imod);
        logic[DATA_WIDTH - 1:0] res;

        case (opcode)
            5'b00000: res = AluFunc #(DATA_WIDTH)::modmul(opa, opb, mod, imod); // modmul.vv
            5'b00100: res = AluFunc #(DATA_WIDTH)::modmul(opa, ops, mod, imod); // modmul.vs
            5'b00001: res = AluFunc #(DATA_WIDTH)::modadd(opa, opb, mod);       // modadd.vv
            5'b00101: res = AluFunc #(DATA_WIDTH)::modadd(opa, ops, mod);       // modadd.vs
            5'b00010: res = AluFunc #(DATA_WIDTH)::modsub(opa, opb, mod);       // modsub.vv
            5'b00110: res = AluFunc #(DATA_WIDTH)::modsub(opa, ops, mod);       // modsub.vs
            5'b01010: res = AluFunc #(DATA_WIDTH)::modsub(ops, opa, mod);       // modsub.sv
            5'b00011: res = AluFunc #(DATA_WIDTH)::mod(opa, mod, imod);         // mod
            5'b10101: res = AluFunc #(DATA_WIDTH)::modadd(AluFunc #(DATA_WIDTH)::modmul(opa, opb, mod, imod), ops, mod); // madd.vs
            5'b10110: res = AluFunc #(DATA_WIDTH)::modsub(AluFunc #(DATA_WIDTH)::modmul(opa, opb, mod, imod), ops, mod); // msub.vs
            5'b11010: res = AluFunc #(DATA_WIDTH)::modsub(ops, AluFunc #(DATA_WIDTH)::modmul(opa, opb, mod, imod), mod); // msub.sv
            default:  res = '0;
        endcase

        return res;
    endfunction

    task dump_op_pack(input op_pack_t op_pack);
        if(op_pack.i_op_vld) begin
            case(op_pack.i_op_cfg)
                2'b01: $display("vsetvl");
                2'b10: $display("vsetq");
                2'b11: $display("vsetiq");
                default: begin
                    //疑似vcs bug，当case的值为全X时，所有分支全部执行
                    if($isunknown(op_pack.i_op_alu)) begin
                        $display("<unknown alu op>");
                    end
                    else begin
                        case(op_pack.i_op_alu)
                            5'b00000: $display("vfqmul.vv");
                            5'b00100: $display("vfqmul.vs");
                            5'b00001: $display("vfqadd.vv");
                            5'b00101: $display("vfqadd.vs/vcp");
                            5'b00010: $display("vfqsub.vv");
                            5'b00110: $display("vfqsub.vs");
                            5'b01010: $display("vfqsub.sv");
                            5'b00011: $display("vfqmod.v");
                            default: $display("<unknown alu op>");
                        endcase
                    end
                end
            endcase

            $display("scalar_cfg = %0x", op_pack.i_scalar_cfg);
            $display("op_bk0_r = %0x", op_pack.i_op_bk0_r);
            $display("op_bk0_w = %0x", op_pack.i_op_bk0_w);
            $display("op_bk1_r = %0x", op_pack.i_op_bk1_r);
            $display("op_bk1_w = %0x", op_pack.i_op_bk1_w);
            $display("scalar_alu = %0x", op_pack.i_scalar_alu);
            $display("op_iconn = %0x", op_pack.i_op_iconn);
            $display("scalar_iconn = %0x", op_pack.i_scalar_iconn);
            $display("mux_o = %0b", op_pack.i_mux_o);
            $display("mux_i = %0b", op_pack.i_mux_i);
            $display("mod_q = %0x", op_pack.mod_q);
            $display("mod_iq = %0x", op_pack.mod_iq);
            $display("op_alu = %x", op_pack.op_alu);
            $display("op_vle = %x", op_pack.op_vle);
            $display("op_vse = %x", op_pack.op_vse);
            $display("op_iconn = %x", op_pack.op_iconn);
            $display("timestamp = %0d", op_pack.timestamp);
            $display("latency = %0d", op_pack.latency);
            $display("vl = %0d", op_pack.vl);
            $display("target_lane_id = %0d", op_pack.target_lane_id);
            $display("woffset = %0d", op_pack.woffset);
            $display("iconn_need_minus = %0d", op_pack.iconn_need_minus);
        end
        else begin
            $display("<none>");
        end
    endtask

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //global cycle
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cur_cycle <= '0;
        end
        else begin
            cur_cycle <= cur_cycle + 'b1;
        end
    end

    generate
        for(i = 0;i < NLANE;i++) begin
            for(j = 1;j <= TOTAL_STAGE;j++) begin
                always_ff @(posedge clk) begin
                    cur_op_p[i][j] <= cur_op_p[i][j - 1];
                end
            end
        end
    endgenerate

    generate
        for(i = 0;i < NLANE;i++) begin
            //rfbank data capture
            assert property(@(posedge clk) i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_modalu.valid_o |-> ##(INTT_SWAP_LATENCY + NTT_ICONN_WRITE_LATENCY) i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.we || i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_1.we) else $finish;
            assert property(@(posedge clk) !((i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.we === 'b1) && (i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_1.we === 'b1))) else $finish;
            assign rfbank0_re_last[i][0] = i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.re;
            assign rfbank1_re_last[i][0] = i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_1.re;

            for(j = 1;j <= RF_READ_LATENCY;j++) begin
                always_ff @(posedge clk or negedge rst_n) begin
                    if(!rst_n) begin
                        rfbank0_re_last[i][j] <= '0;
                        rfbank1_re_last[i][j] <= '0;
                    end
                    else begin
                        rfbank0_re_last[i][j] <= rfbank0_re_last[i][j - 1];
                        rfbank1_re_last[i][j] <= rfbank1_re_last[i][j - 1];
                    end
                end
            end

            initial begin
                forever begin
                    wait_clk();

                    if(rfbank0_re_last[i][RF_READ_LATENCY]) begin
                        if(cur_op_p[i][RF_STAGE_NUM].op_vse) begin
                            rfbank0_vse_q[i].push_back(i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.rdata);
                        end
                        else if(cur_op_p[i][RF_STAGE_NUM].op_iconn) begin
                            rfbank0_iconn_q[cur_op_p[i][RF_STAGE_NUM].target_lane_id].push_back(i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.rdata);
                        end
                        else begin
                            rfbank0_q[i].push_back(i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.rdata);
                        end
                    end

                    if(rfbank1_re_last[i][RF_READ_LATENCY]) begin
                        if(cur_op_p[i][RF_STAGE_NUM].op_vse) begin
                            rfbank1_vse_q[i].push_back(i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_1.rdata);
                        end
                        else if(cur_op_p[i][RF_STAGE_NUM].op_iconn) begin
                            rfbank1_iconn_q[cur_op_p[i][RF_STAGE_NUM].target_lane_id].push_back(i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_1.rdata);
                        end
                        else begin
                            rfbank1_q[i].push_back(i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_1.rdata);
                        end
                    end
                end
            end

            //check op result(skip modmul when opa or opb/s[DATA_WIDTH - 1] == 1'b1)
            initial begin
                forever begin
                    wait_clk();

                    //一个mb内的所有指令latency必须一致（否则会出现多条检测时间点的指令只有一条能被检测）
                    if(lane_iconn_mb[i].try_peek(lane_cur_op[i])) begin
                        if((lane_cur_op[i].timestamp + lane_cur_op[i].latency) == cur_cycle) begin
                            lane_assert_failed[i] = '0;
                            lane_ignored[i] = '1;

                            if(lane_cur_op[i].i_op_cfg == 2'b00) begin
                                lane_ignored[i] = '0;
                                
                                if(lane_cur_op[i].i_op_bk0_r[RF_ADDR_WIDTH]) begin
                                    lane_res[i] = rfbank0_iconn_q[i][0];
                                    rfbank0_iconn_q[i].pop_front();
                                end

                                if(lane_cur_op[i].i_op_bk1_r[RF_ADDR_WIDTH]) begin
                                    lane_res[i] = rfbank1_iconn_q[i][0];
                                    rfbank1_iconn_q[i].pop_front();
                                end

                                if(lane_cur_op[i].iconn_need_minus) begin
                                    lane_res[i] = lane_cur_op[i].mod_q - lane_res[i];
                                end

                                if(lane_cur_op[i].i_op_bk0_w[RF_ADDR_WIDTH]) begin
                                    `assert_equal_flag(cur_cycle, lane_res[i], i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.rf[{lane_cur_op[i].i_op_bk0_w[RF_ADDR_WIDTH - 1:0], $clog2(NELEMENT)'(lane_cur_op[i].woffset)}], lane_assert_failed[i]);
                                end
                                else begin
                                    `assert_equal_flag(cur_cycle, 1'b1, lane_cur_op[i].i_op_bk1_w[RF_ADDR_WIDTH], lane_assert_failed[i]);
                                    `assert_equal_flag(cur_cycle, lane_res[i], i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_1.rf[{lane_cur_op[i].i_op_bk1_w[RF_ADDR_WIDTH - 1:0], $clog2(NELEMENT)'(lane_cur_op[i].woffset)}], lane_assert_failed[i]);
                                end
                            end

                            lane_iconn_mb[i].get(lane_cur_op[i]);
                            lane_op_cmp_result[i].push_back(lane_assert_failed[i]);
                            lane_op_ignored_result[i].push_back(lane_ignored[i]);

                            if(lane_assert_failed[i]) begin
                                $display("failed_op_id = %0d", lane_cur_op[i].id);
                                dump_op_pack(lane_cur_op[i]);
                            end
                        end
                    end

                    if(lane_mb[i].try_peek(lane_cur_op[i])) begin
                        if((lane_cur_op[i].timestamp + lane_cur_op[i].latency) == cur_cycle) begin
                            lane_assert_failed[i] = '0;
                            lane_ignored[i] = '1;

                            if(lane_cur_op[i].i_op_cfg == 2'b00) begin
                                if(lane_cur_op[i].op_vle) begin
                                    lane_ignored[i] = '0;
                                    //`assert_equal_flag(cur_cycle, 1'b0, lane_cur_op[i].i_vp_data[i * DATA_WIDTH +: DATA_WIDTH] >> (DATA_WIDTH - 1), lane_assert_failed[i]);

                                    if(lane_cur_op[i].i_op_bk0_w[RF_ADDR_WIDTH]) begin
                                        `assert_equal_flag(cur_cycle, lane_cur_op[i].i_vp_data[i * DATA_WIDTH +: DATA_WIDTH], i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.rf[{lane_cur_op[i].i_op_bk0_w[RF_ADDR_WIDTH - 1:0], $clog2(NELEMENT)'(lane_cur_op[i].i_cnt)}], lane_assert_failed[i]);
                                    end
                                    else begin
                                        `assert_equal_flag(cur_cycle, 1'b1, lane_cur_op[i].i_op_bk1_w[RF_ADDR_WIDTH], lane_assert_failed[i]);
                                        `assert_equal_flag(cur_cycle, lane_cur_op[i].i_vp_data[i * DATA_WIDTH +: DATA_WIDTH], i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_1.rf[{lane_cur_op[i].i_op_bk1_w[RF_ADDR_WIDTH - 1:0], $clog2(NELEMENT)'(lane_cur_op[i].i_cnt)}], lane_assert_failed[i]);
                                    end
                                end
                                else begin
                                    lane_ignored[i] = '0;
                                    lane_opa[i] = 'x;
                                    lane_opb[i] = 'x;

                                    if(lane_cur_op[i].i_op_bk0_r[RF_ADDR_WIDTH]) begin
                                        if(lane_cur_op[i].i_mux_o[3] === 1'b0) begin
                                            lane_opa[i] = rfbank0_q[i][0];
                                        end
                                        
                                        if(lane_cur_op[i].i_mux_o[2] === 1'b0) begin
                                            lane_opb[i] = rfbank0_q[i][0];
                                        end

                                        rfbank0_q[i].pop_front();
                                    end

                                    if(lane_cur_op[i].i_op_bk1_r[RF_ADDR_WIDTH]) begin
                                        if(lane_cur_op[i].i_mux_o[3] === 1'b1) begin
                                            lane_opa[i] = rfbank1_q[i][0];
                                        end
                                        
                                        if(lane_cur_op[i].i_mux_o[2] === 1'b1) begin
                                            lane_opb[i] = rfbank1_q[i][0];
                                        end

                                        rfbank1_q[i].pop_front();
                                    end

                                    lane_res[i] = get_alu_res(lane_cur_op[i].i_op_alu, lane_opa[i], lane_opb[i], lane_cur_op[i].i_scalar_alu, lane_cur_op[i].mod_q, lane_cur_op[i].mod_iq);
                                    
                                    if(!$isunknown(lane_res[i]) && 
                                      ((lane_cur_op[i].i_op_alu != 'b00000) || ((lane_opa[i][DATA_WIDTH - 1] == 1'b0) && (lane_opa[i][DATA_WIDTH - 1] == 1'b0))) &&
                                      ((lane_cur_op[i].i_op_alu != 'b00100) || ((lane_opa[i][DATA_WIDTH - 1] == 1'b0) && (lane_cur_op[i].i_scalar_alu[DATA_WIDTH - 1] == 1'b0)))) begin
                                        //`assert_equal_flag(cur_cycle, 1'b0, lane_res[i][DATA_WIDTH - 1], lane_assert_failed[i]);

                                        if(lane_cur_op[i].i_op_bk0_w[RF_ADDR_WIDTH]) begin
                                            `assert_equal_flag(cur_cycle, lane_res[i], i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.rf[{lane_cur_op[i].i_op_bk0_w[RF_ADDR_WIDTH - 1:0], $clog2(NELEMENT)'(lane_cur_op[i].i_cnt)}], lane_assert_failed[i]);
                                        end
                                        else begin
                                            `assert_equal_flag(cur_cycle, 1'b1, lane_cur_op[i].i_op_bk1_w[RF_ADDR_WIDTH], lane_assert_failed[i]);
                                            `assert_equal_flag(cur_cycle, lane_res[i], i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_1.rf[{lane_cur_op[i].i_op_bk1_w[RF_ADDR_WIDTH - 1:0], $clog2(NELEMENT)'(lane_cur_op[i].i_cnt)}], lane_assert_failed[i]);
                                        end
                                    end
                                end
                            end

                            lane_mb[i].get(lane_cur_op[i]);
                            lane_op_cmp_result[i].push_back(lane_assert_failed[i]);
                            lane_op_ignored_result[i].push_back(lane_ignored[i]);

                            if(lane_assert_failed[i]) begin
                                $display("failed_op_id = %0d", lane_cur_op[i].id);
                                dump_op_pack(lane_cur_op[i]);
                                $display("opa = %0x", lane_opa[i]);
                                $display("opb = %0x", lane_opb[i]);
                            end
                        end
                    end

                    if(lane_cfg_mb[i].try_peek(lane_cur_op[i])) begin
                        if((lane_cur_op[i].timestamp + lane_cur_op[i].latency) == cur_cycle) begin
                            lane_assert_failed[i] = '0;
                            lane_ignored[i] = '0;

                            if(lane_cur_op[i].i_op_cfg == 2'b01) begin
                                `assert_equal_flag(cur_cycle, lane_cur_op[i].i_scalar_cfg, i_vxu_top.vxu_lane_block[i].i_vxu_lane.vl, lane_assert_failed[i]);
                            end
                            else if(lane_cur_op[i].i_op_cfg == 2'b10) begin
                                `assert_equal_flag(cur_cycle, lane_cur_op[i].i_scalar_cfg, i_vxu_top.vxu_lane_block[i].i_vxu_lane.mod_q, lane_assert_failed[i]);
                            end
                            else if(lane_cur_op[i].i_op_cfg == 2'b11) begin
                                `assert_equal_flag(cur_cycle, lane_cur_op[i].i_scalar_cfg, i_vxu_top.vxu_lane_block[i].i_vxu_lane.mod_iq, lane_assert_failed[i]);
                            end
                            else begin
                                lane_ignored[i] = '1;
                            end

                            lane_cfg_mb[i].get(lane_cur_op[i]);
                            lane_op_cmp_result[i].push_back(lane_assert_failed[i]);
                            lane_op_ignored_result[i].push_back(lane_ignored[i]);

                            if(lane_assert_failed[i]) begin
                                $display("failed_op_id = %0d", lane_cur_op[i].id);
                                dump_op_pack(lane_cur_op[i]);
                            end
                        end
                    end

                    if(lane_vse_mb[i].try_peek(lane_cur_op[i])) begin
                        if((lane_cur_op[i].timestamp + lane_cur_op[i].latency) == cur_cycle) begin
                            lane_assert_failed[i] = '0;
                            lane_ignored[i] = '1;

                            if(lane_cur_op[i].i_op_cfg == 2'b00) begin
                                if(lane_cur_op[i].op_vse) begin
                                    lane_ignored[i] = '0;
                                    if(lane_cur_op[i].i_op_bk0_r[RF_ADDR_WIDTH]) begin
                                        `assert_equal_flag(cur_cycle, rfbank0_vse_q[i][0], o_vp_data[i * DATA_WIDTH +: DATA_WIDTH], lane_assert_failed[i]);
                                        rfbank0_vse_q[i].pop_front();
                                    end
                                    else begin
                                        `assert_equal_flag(cur_cycle, 1'b1, lane_cur_op[i].i_op_bk1_r[RF_ADDR_WIDTH], lane_assert_failed[i]);
                                        `assert_equal_flag(cur_cycle, rfbank1_vse_q[i][0], o_vp_data[i * DATA_WIDTH +: DATA_WIDTH], lane_assert_failed[i]);
                                        rfbank1_vse_q[i].pop_front();
                                    end
                                end
                            end

                            lane_vse_mb[i].get(lane_cur_op[i]);
                            lane_op_cmp_result[i].push_back(lane_assert_failed[i]);
                            lane_op_ignored_result[i].push_back(lane_ignored[i]);

                            if(lane_assert_failed[i]) begin
                                $display("failed_op_id = %0d", lane_cur_op[i].id);
                                dump_op_pack(lane_cur_op[i]);
                            end
                        end
                    end
                end
            end
        end
    endgenerate

    task wait_job_finish;
        bit found_job;

        while(1) begin
            wait_clk();
            found_job = 0;

            for(k = 0;k < NLANE;k++) begin
                if((lane_mb[k].num() > 0) || (lane_cfg_mb[k].num() > 0) || (lane_vse_mb[k].num() > 0) || (lane_iconn_mb[k].num() > 0)) begin
                    found_job = 1;
                    break;
                end
            end

            if(!found_job) begin
                break;
            end
        end
    endtask

    task basic_test;
        $display("basic test start");
        emit_op(0, emit_vsetvl(4096));
        emit_op(1, emit_vsetvl(8192));
        emit_op(2, emit_vsetq(64'd576460825317867521));
        emit_op(3, emit_vsetiq(64'd2305842717155954811));
        emit_op(4, emit_vsetq(64'd576460924102115329));
        emit_op(5, emit_vsetiq(64'd2305842322019131387));
        emit_op(6, emit_vsetq(64'd576462951330889729));
        emit_op(7, emit_vsetiq(64'd2305834213137383420));
        emit_op(8, emit_vle(0, 1024'h12345678abcdef0012345678abcdef0012345678abcdef0012345678abcdef0012345678abcdef0012345678abcdef0012345678abcdef0012345678abcdef0012345678abcdef0012345678abcdef0012345678abcdef0012345678abcdef0012345678abcdef0012345678abcdef0012345678abcdef0012345678abcdef00));
        emit_op(9, emit_vle(5, 1024'h1af5dbb11cab0ae46fa61fc9668c2d8caae3d250d485d3be2035ec847a1081d9c4417bfa963c8020f63b0c8a425c520ca61a83c1374511905239bc19dbeeb1bf2048163cc66fbe25391b9f6337fc75ed690e9324a6883b178e0ea97d5708ca08f2e0c16da68a171225a7ce309e5623c579137103324834acaeff18a850f3bf6f));
        emit_op(10, emit_vle(31, 1024'h0b4b3f9ca2e2eed9fe908a9d2dc9f185f64ee62a92c050fc571db804badeb4c17eba44a92d20ff740100ec794d28cbdab3265d16e93b479dd8a7cf4fe55366039d468886d6f315cef08dafacbf6bb5cd0710b52487c62e62c33a518c73c5c87f8facf62da67ba992be8c64422c1e8d2362b8ef6bf1c01272798df5e2d9c0d510));
        emit_op(11, emit_vle(2, 1024'h1ab8131697645cfdddd1404843ed4dee5a554233560439beba87cac6a68b8472dff7a60f314b3861758cb9d0336af14b6be959762cc31fb3b14ac0d7d1e5b83c59d3e1dc9d63677ee849bd1c114629855c6d6f8e09a4073364eb4bd9754c18be4bca0342d24b21b92ba754f411f7b6d6f0b93d5aff006ecbb7ca9733ee3b2c25));
        wait_job_finish();
        emit_op(12, emit_vcp(2, 3));
        wait_job_finish();
        emit_op(13, emit_vfqadd_vs(3, 5, 3));
        wait_job_finish();
        emit_op(14, emit_vse(3));
        wait_job_finish();
        $display("basic test finish");
    endtask

    //random op generation
    class random_op;
        rand bit[RF_ADDR_WIDTH:0] rs1;
        rand bit[RF_ADDR_WIDTH:0] rs2;
        rand bit[RF_ADDR_WIDTH:0] rd;
        rand bit[DATA_WIDTH - 1:0] ops;
        rand bit[DATA_WIDTH - 1:0] iconn_ops;
        rand bit[NLANE * DATA_WIDTH - 1:0] i_vp_data;
        rand int unsigned op;
        rand bit[CNT_WIDTH - 1:0] i_cnt;

        constraint random_op
        {
            (rs1[0] ^ rs2[0]) == 1'b1;
            ops[DATA_WIDTH - 1] == 1'b0;

            foreach(i_vp_data[i])
            {
                if((i % DATA_WIDTH) == (DATA_WIDTH - 1))
                {
                    i_vp_data[i] == 1'b0;
                }
            }
            
            (op <= 16);

            if(op == 0)
                (ops > 0) && ((ops % DATA_WIDTH) == 0) && (ops <= DATA_WIDTH * NELEMENT * NLANE);
            else if(op < 3)
                ops > 0;

            if(op == 15)
                iconn_ops[0] == 'b1;

            i_cnt < NELEMENT;
        }
    endclass

    class random_vp_data;
        rand bit[NLANE * DATA_WIDTH - 1:0] vp_data;
    endclass

    function op_pack_t emit_random(random_op rop);
        case(rop.op)
            0: return emit_vsetvl(rop.ops);
            1: return emit_vsetq(rop.ops);
            2: return emit_vsetiq(rop.ops);
            3: return emit_vfqmul_vv(rop.rs1, rop.rs2, rop.rd);
            4: return emit_vfqmul_vs(rop.rs1, rop.ops, rop.rd);
            5: return emit_vfqadd_vv(rop.rs1, rop.rs2, rop.rd);
            6: return emit_vfqadd_vs(rop.rs1, rop.ops, rop.rd);
            7: return emit_vfqsub_vv(rop.rs1, rop.rs2, rop.rd);
            8: return emit_vfqsub_vs(rop.rs1, rop.ops, rop.rd);
            9: return emit_vfqsub_sv(rop.rs1, rop.ops, rop.rd);
            10: return emit_vfqmod_v(rop.rs1, rop.rd);
            11: return emit_vcp(rop.rs1, rop.rd);
            12: return emit_vle(rop.rd, rop.i_vp_data);
            13: return emit_vse(rop.rs1);
            14: return emit_vroli(rop.rs1, rop.iconn_ops, rop.rd);
            15: return emit_vaut(rop.rs1, rop.iconn_ops, rop.rd);
            default: return emit_none();
        endcase
    endfunction

    random_op rop;
    random_vp_data rvp;

    task random_test;
        longint unsigned random_k;
        longint unsigned random_i;
        
        op_pack_t rop_pack;
        $display("random test start");
        rop = new();
        rop.srandom(1);
        rvp = new();
        rvp.srandom(1);

        $display("random initializing...");
        emit_op(0, emit_vsetvl(DATA_WIDTH * NELEMENT * NLANE));

        for(random_k = 0;random_k < NELEMENT;random_k++) begin
            for(random_i = 0;random_i < 2 ** (RF_ADDR_WIDTH + 1);random_i++) begin
                assert(rvp.randomize());
                emit_op(random_k * (2 ** (RF_ADDR_WIDTH + 1)) + random_i, emit_vle(random_i, rvp.vp_data));
            end
        end

        wait_job_finish();
        $display("random initialized");

        for(random_k = 0;random_k < 100000;random_k++) begin
            assert(rop.randomize());
            rop_pack = emit_random(rop);
            rop_pack.i_cnt = rop.i_cnt;
            //dump_op_pack(rop_pack);
            emit_op(random_k, rop_pack);
        end

        wait_job_finish();
        $display("random test finish");
    endtask

    int x;

    initial begin
        total_op = 0;
        passed_op = 0;
        failed_op = 0;
        ignored_op = 0;

        for(k = 0;k < NLANE;k++) begin
            lane_mb[k] = new();
            lane_cfg_mb[k] = new();
            lane_vse_mb[k] = new();
            lane_iconn_mb[k] = new();
        end

        reset();
        basic_test();
        random_test();
        #1000;

        while(lane_op_cmp_result[0].size() > 0) begin
            assert_failed = 0;
            ignored = 0;

            for(k = 0;k < NLANE;k++) begin
                assert_failed |= lane_op_cmp_result[k].pop_front();
                ignored |= lane_op_ignored_result[k].pop_front();
            end

            if(assert_failed) begin
                failed_op++;
            end
            else if(ignored) begin
                ignored_op++;
            end
            else begin
                passed_op++;
            end
        end

        $display("total_op = %0d, passed_op = %0d, failed_op = %0d, ignored_op = %0d", total_op, passed_op, failed_op, ignored_op);
        $finish;
    end

    `ifdef FSDB_DUMP
        initial begin
            $fsdbDumpfile("top.fsdb");
            $fsdbDumpvars(0, 0, "+all");
            $fsdbDumpMDA();
        end
    `endif
endmodule