//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: VP
// Module Name: vp_top_tb
// Modify Date: 
//
// Description:
// VP integrated verification testbench
//////////////////////////////////////////////////

`timescale 1ns/100ps
`include "tdb_reader.svh"
`include "vp_defines.vh"
`include "common_defines.vh"

import tdb_reader::*;

import "DPI-C" function string getenv(input string env_name);

`define assert(condition) assert((condition)) else begin #10; $finish; end
`define assert_equal(_row, _expected, _actual) assert((_expected) === (_actual)) else begin $display("row = %0d, expected = %0x, actual = %0x", (_row), (_expected), (_actual)); assert_failed = 1; end
`define assert_equal_flag(_row, _expected, _actual, _flag) assert((_expected) === (_actual)) else begin $display("row = %0d, expected = %0x, actual = %0x", (_row), (_expected), (_actual)); _flag = 1; end

module top;
    tdb_reader tdb_issue;
    tdb_reader tdb_exe;

    logic clk;
    logic rst_n;
    logic i_start_vp;
    logic o_done_vp;
    logic o_pc_vld;
    logic[`PC_WIDTH - 1:0] o_pc_addr;
    logic[`INST_WIDTH - 1:0] i_inst;
    logic o_vp_rden;
    logic o_vp_wren;
    logic[`SYS_SPM_ADDR_WIDTH - 1:0] o_vp_rdaddr;
    logic[`SYS_SPM_ADDR_WIDTH - 1:0] o_vp_wraddr;
    logic[`SYS_NUM_LANE * `LANE_DATA_WIDTH - 1:0] i_vp_data;
    logic[`SYS_NUM_LANE * `LANE_DATA_WIDTH - 1:0] o_vp_data;
    logic[`SCALAR_WIDTH - 1:0] i_csr_vp_src0_ptr;
    logic[`SCALAR_WIDTH - 1:0] i_csr_vp_src1_ptr;
    logic[`SCALAR_WIDTH - 1:0] i_csr_vp_rslt_ptr;
    logic[`SCALAR_WIDTH - 1:0] i_csr_vp_ksk_ptr;
    logic[`SCALAR_WIDTH - 1:0] i_csr_vp_step;

    parameter VLMAX = `SYS_VLMAX;
    parameter OP_WIDTH = `CONFIG_OP_WIDTH;
    parameter DATA_WIDTH = `LANE_DATA_WIDTH;
    parameter RF_ADDR_WIDTH = `RW_OP_WIDTH - 2;
    parameter ALU_OP_WIDTH = `ALU_OP_WIDTH;
    parameter ICONN_OP_WIDTH = `ICONN_OP_WIDTH;
    parameter NTT_OP_WIDTH = `NTT_OP_WIDTH;
    parameter MUX_O_WIDTH = `MUXO_OP_WIDTH;
    parameter MUX_I_WIDTH = `MUXI_OP_WIDTH;
    parameter NLANE = `SYS_NUM_LANE;
    parameter NTT_SWAP_LATENCY = `VXU_NTT_SWAP_LATENCY;
    parameter ALU_MUL_LEVEL = `VXU_ALU_MUL_LEVEL;
    parameter ALU_MUL_STAGE = `VXU_ALU_MUL_STAGE;
    parameter ALU_LAST_STAGE = `VXU_ALU_LAST_STAGE;
    parameter ALU_MODHALF_STAGE = `VXU_ALU_MODHALF_STAGE;
    parameter INTT_SWAP_LATENCY = `VXU_INTT_SWAP_LATENCY;
    parameter RF_READ_LATENCY = `VXU_RF_READ_LATENCY;
    parameter CNT_WIDTH = `CNT_WIDTH;
    parameter NELEMENT = VLMAX / DATA_WIDTH / NLANE;
    parameter TF_ITEM_NUM = `TF_ITEM_NUM;
    parameter TF_ADDR_WIDTH = `TF_ADDR_WIDTH;
    localparam RF_WRITE_LATENCY = 1;
    localparam RF_STAGE_NUM = RF_READ_LATENCY;
    localparam NTT_ICONN_READ_LATENCY = 1;
    localparam NTT_ICONN_WRITE_LATENCY = 1;
    localparam ALU_STAGE_NUM = 3 * ALU_MUL_STAGE + ALU_LAST_STAGE + ALU_MODHALF_STAGE + 1;
    localparam TOTAL_STAGE = RF_STAGE_NUM + NTT_ICONN_READ_LATENCY + NTT_SWAP_LATENCY + ALU_STAGE_NUM + INTT_SWAP_LATENCY + NTT_ICONN_WRITE_LATENCY + RF_WRITE_LATENCY;
    localparam NTT_ICONN_READ_INDEX = RF_STAGE_NUM;
    localparam NTT_SWAP_INDEX = RF_STAGE_NUM + NTT_ICONN_READ_LATENCY;
    localparam ALU_INPUT_INDEX = RF_STAGE_NUM + NTT_ICONN_READ_LATENCY + NTT_SWAP_LATENCY;
    localparam INTT_SWAP_INDEX = RF_STAGE_NUM + NTT_ICONN_READ_LATENCY + NTT_SWAP_LATENCY + ALU_STAGE_NUM;
    localparam NTT_ICONN_WRITE_INDEX = RF_STAGE_NUM + NTT_ICONN_READ_LATENCY + NTT_SWAP_LATENCY + ALU_STAGE_NUM + INTT_SWAP_LATENCY;
    localparam RF_WRITE_INDEX = RF_STAGE_NUM + NTT_ICONN_READ_LATENCY + NTT_SWAP_LATENCY + ALU_STAGE_NUM + INTT_SWAP_LATENCY + NTT_ICONN_WRITE_LATENCY;
    localparam ICONN_LATENCY = $clog2(NLANE) - 1;

    typedef struct packed
    {
        longint unsigned id;

        logic i_op_vld;
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

        logic[NLANE * DATA_WIDTH - 1:0] i_vp_data;

        logic[CNT_WIDTH - 1:0] i_cnt;

        longint unsigned latency;
        longint unsigned timestamp;
        bit op_alu;
        bit op_vle;
        bit op_vse;
        bit op_iconn;
        bit op_ntt;
        bit op_intt;

        logic[DATA_WIDTH - 1:0] vl;
        logic[DATA_WIDTH - 1:0] mod_q;
        logic[DATA_WIDTH - 1:0] mod_iq;

        longint unsigned ref_row;
        logic[DATA_WIDTH - 1:0] ref_vl;
        logic[DATA_WIDTH - 1:0] ref_mod_q;
        logic[DATA_WIDTH - 1:0] ref_mod_iq;
        logic ref_config_valid;
        logic ref_bank0_rvld;
        logic[RF_ADDR_WIDTH + $clog2(NELEMENT) - 1:0] ref_bank0_raddr;
        logic[DATA_WIDTH - 1:0] ref_bank0_rdata;
        logic ref_bank1_rvld;
        logic[RF_ADDR_WIDTH + $clog2(NELEMENT) - 1:0] ref_bank1_raddr;
        logic[DATA_WIDTH - 1:0] ref_bank1_rdata;
        logic[DATA_WIDTH - 1:0] ref_spm_rdata;
        logic ref_spm_rvld;
        logic[DATA_WIDTH - 1:0] ref_spm_wdata;
        logic ref_spm_wvld;
        logic[DATA_WIDTH - 1:0] ref_alu_0i;
        logic[DATA_WIDTH - 1:0] ref_alu_1i;
        logic[DATA_WIDTH - 1:0] ref_alu_o;
        logic ref_bank0_wvld;
        logic[RF_ADDR_WIDTH + $clog2(NELEMENT) - 1:0] ref_bank0_waddr;
        logic[DATA_WIDTH - 1:0] ref_bank0_wdata;
        logic ref_bank1_wvld;
        logic[RF_ADDR_WIDTH + $clog2(NELEMENT) - 1:0] ref_bank1_waddr;
        logic[DATA_WIDTH - 1:0] ref_bank1_wdata;
        logic[DATA_WIDTH - 1:0] ref_iconn_read_data;
        logic[RF_ADDR_WIDTH + $clog2(NELEMENT) - 1:0] ref_ntt_raddr0;
        logic[DATA_WIDTH - 1:0] ref_ntt_rdata0;
        logic[RF_ADDR_WIDTH + $clog2(NELEMENT) - 1:0] ref_ntt_raddr1;
        logic[DATA_WIDTH - 1:0] ref_ntt_rdata1;
        logic[RF_ADDR_WIDTH + $clog2(NELEMENT) - 1:0] ref_ntt_waddr0;
        logic[DATA_WIDTH - 1:0] ref_ntt_wdata0;
        logic[RF_ADDR_WIDTH + $clog2(NELEMENT) - 1:0] ref_ntt_waddr1;
        logic[DATA_WIDTH - 1:0] ref_ntt_wdata1;
        logic[DATA_WIDTH - 1:0] ref_ntt_alu_0i;
        logic[DATA_WIDTH - 1:0] ref_ntt_alu_1i;
        logic[DATA_WIDTH - 1:0] ref_ntt_alu_s;
        logic[DATA_WIDTH - 1:0] ref_ntt_alu_0o;
        logic[DATA_WIDTH - 1:0] ref_ntt_alu_1o;
    }op_pack_t;

    mailbox#(op_pack_t) lane_mb[0:NLANE - 1];
    mailbox#(op_pack_t) lane_cfg_mb[0:NLANE - 1];
    mailbox#(op_pack_t) lane_vse_mb[0:NLANE - 1];
    mailbox#(op_pack_t) lane_iconn_mb[0:NLANE - 1];
    mailbox#(op_pack_t) lane_ntt_mb[0:NLANE - 1];
    mailbox#(op_pack_t) lane_intt_mb[0:NLANE - 1];
    op_pack_t /*sparse*/  lane_cur_op[0:NLANE - 1];
    longint unsigned lane_assert_failed[0:NLANE - 1];
    longint unsigned lane_ignored[0:NLANE - 1];
    longint unsigned lane_op_cmp_result[0:NLANE - 1][$];
    longint unsigned lane_op_ignored_result[0:NLANE - 1][$];
    logic[DATA_WIDTH - 1:0] lane_opa[0:NLANE - 1];
    logic[DATA_WIDTH - 1:0] lane_opb[0:NLANE - 1];
    logic[DATA_WIDTH - 1:0] lane_ops[0:NLANE - 1];
    logic[DATA_WIDTH - 1:0] lane_res[0:NLANE - 1];
    logic[DATA_WIDTH - 1:0] lane_res2[0:NLANE - 1];

    op_pack_t /*sparse*/ cur_op_p[0:NLANE - 1][0:TOTAL_STAGE];
    op_pack_t /*sparse*/ cur_op_p_input[0:NLANE - 1];

    logic[DATA_WIDTH - 1:0] rfbank0_q[0:NLANE - 1][$];
    logic[DATA_WIDTH - 1:0] rfbank1_q[0:NLANE - 1][$];
    logic[DATA_WIDTH - 1:0] rfbank0_vse_q[0:NLANE - 1][$];
    logic[DATA_WIDTH - 1:0] rfbank1_vse_q[0:NLANE - 1][$];
    logic[DATA_WIDTH - 1:0] rfbank0_iconn_q[0:NLANE - 1][$];
    logic[DATA_WIDTH - 1:0] rfbank1_iconn_q[0:NLANE - 1][$];
    logic[DATA_WIDTH - 1:0] iconn_read_q[0:NLANE - 1][$];
    logic rfbank0_re_last[0:NLANE - 1][0:RF_READ_LATENCY];
    logic rfbank1_re_last[0:NLANE - 1][0:RF_READ_LATENCY];
    
    logic[DATA_WIDTH - 1:0] ntt_alu_0i_q[0:NLANE - 1][$];
    logic[DATA_WIDTH - 1:0] ntt_alu_1i_q[0:NLANE - 1][$];
    logic[DATA_WIDTH - 1:0] ntt_alu_s_q[0:NLANE - 1][$];
    logic[DATA_WIDTH - 1:0] ntt_alu_0o_q[0:NLANE - 1][$];
    logic[DATA_WIDTH - 1:0] ntt_alu_1o_q[0:NLANE - 1][$];

    longint unsigned cur_cycle;
    longint unsigned total_op;
    longint unsigned passed_op;
    longint unsigned failed_op;
    longint unsigned ignored_op;
    bit assert_failed;
    bit ignored;
    bit reg_dump_enable = 0;
    genvar i, j;
    int k;
    int spm_k;

    op_pack_t pack;
    longint unsigned issue_row;
    longint unsigned exe_row;
    int inst_id;
    longint unsigned last_cycle;

    int t;

    vp_top i_vp_top(.*);

    task wait_clk;
        @(posedge clk);
        #0.1;
    endtask

    task eval;
        #0.1;
    endtask

    task reset;
        rst_n = 0;
        i_start_vp = 0;
        repeat(1) wait_clk();
        rst_n = 1;
    endtask

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //virtual isram
    localparam ISRAM_ADDR_WIDTH = $clog2(`IRAM_DEPTH);
    logic[`INST_WIDTH - 1:0] isram[0:`IRAM_DEPTH - 1];
    logic[`INST_WIDTH - 1:0] inst_shift[0:`COMMON_BRAM_DELAY];

    assign inst_shift[0] = (o_pc_vld && (o_pc_addr < `IRAM_DEPTH)) ? isram[o_pc_addr[ISRAM_ADDR_WIDTH - 1:0]] : 'x;

    generate
        for(i = 1;i <= `COMMON_BRAM_DELAY;i++) begin
            always_ff @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    inst_shift[i] <= 'b0;
                end
                else begin
                    inst_shift[i] <= inst_shift[i - 1];
                end
            end
        end
    endgenerate

    assign i_inst = inst_shift[`COMMON_BRAM_DELAY];

    //virtual spm
    localparam SPM_SIZE = 2 ** `SYS_SPM_ADDR_WIDTH;
    logic /*sparse*/ [`SYS_NUM_LANE * DATA_WIDTH - 1:0] spm[0:SPM_SIZE - 1];
    logic /*sparse*/ [`SYS_NUM_LANE * DATA_WIDTH - 1:0] spm_init[0:SPM_SIZE - 1];
    logic /*sparse*/ [`SYS_NUM_LANE * DATA_WIDTH - 1:0] spm_read_shift[0:`COMMON_MEMR_DELAY];

    assign spm_read_shift[0] = o_vp_rden ? spm[o_vp_rdaddr] : 'x;

    generate
        for(i = 1;i <= `COMMON_MEMR_DELAY;i++) begin
            always_ff @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    spm_read_shift[i] <= 'b0;
                end
                else begin
                    spm_read_shift[i] <= spm_read_shift[i - 1];
                end
            end
        end
    endgenerate

    assign i_vp_data = spm_read_shift[`COMMON_MEMR_DELAY];

    //global cycle
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cur_cycle <= '0;
        end
        else begin
            cur_cycle <= cur_cycle + 'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for(spm_k = 0;spm_k < SPM_SIZE;spm_k++) begin
                spm[spm_k] <= $isunknown(spm_init[spm_k]) ? 'b0 : spm_init[spm_k];
            end
        end
        else if(o_vp_wren) begin
            spm[o_vp_wraddr] <= o_vp_data;
        end
    end

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
        pack.op_ntt = 0;
        pack.op_intt = 0;
        return pack;
    endfunction

    task dump_op_pack(input op_pack_t op_pack);
        $display("cur_cycle = %0d", cur_cycle);

        if(op_pack.i_op_vld) begin
            case(op_pack.i_op_cfg)
                2'b01: $display("vsetvl");
                2'b10: $display("vsetq");
                2'b11: $display("vsetiq");
                default: begin
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
            endcase

            $display("scalar_cfg = %0x", op_pack.i_scalar_cfg);
            $display("op_bk0_r = %0x", op_pack.i_op_bk0_r);
            $display("op_bk0_w = %0x", op_pack.i_op_bk0_w);
            $display("op_bk1_r = %0x", op_pack.i_op_bk1_r);
            $display("op_bk1_w = %0x", op_pack.i_op_bk1_w);
            $display("scalar_alu = %0x", op_pack.i_scalar_alu);
            $display("op_iconn = %0x", op_pack.i_op_iconn);
            $display("scalar_iconn = %0x", op_pack.i_scalar_iconn);
            $display("mux_o = %0x", op_pack.i_mux_o);
            $display("mux_i = %0x", op_pack.i_mux_i);
            $display("mod_q = %0x", op_pack.mod_q);
            $display("mod_iq = %0x", op_pack.mod_iq);
            $display("op_alu = %x", op_pack.op_alu);
            $display("op_vle = %x", op_pack.op_vle);
            $display("op_vse = %x", op_pack.op_vse);
            $display("op_iconn = %x", op_pack.op_iconn);
            $display("op_ntt = %x", op_pack.op_ntt);
            $display("op_intt = %x", op_pack.op_intt);
            $display("timestamp = %0d", op_pack.timestamp);
            $display("latency = %0d", op_pack.latency);
            $display("vl = %0d", op_pack.vl);
            $display("cnt = %0x", op_pack.i_cnt);
            $display("ref_alu_0i = %0x", op_pack.ref_alu_0i);
            $display("ref_alu_1i = %0x", op_pack.ref_alu_1i);
            $display("ref_alu_o = %0x", op_pack.ref_alu_o);
            $display("ref_ntt_raddr0 = %0x", op_pack.ref_ntt_raddr0);
            $display("ref_ntt_rdata0 = %0x", op_pack.ref_ntt_rdata0);
            $display("ref_ntt_raddr1 = %0x", op_pack.ref_ntt_raddr1);
            $display("ref_ntt_rdata1 = %0x", op_pack.ref_ntt_rdata1);
            $display("ref_ntt_waddr0 = %0x", op_pack.ref_ntt_waddr0);
            $display("ref_ntt_wdata0 = %0x", op_pack.ref_ntt_wdata0);
            $display("ref_ntt_waddr1 = %0x", op_pack.ref_ntt_waddr1);
            $display("ref_ntt_wdata1 = %0x", op_pack.ref_ntt_wdata1);
            $display("ref_ntt_alu_0i = %0x", op_pack.ref_ntt_alu_0i);
            $display("ref_ntt_alu_1i = %0x", op_pack.ref_ntt_alu_1i);
            $display("ref_ntt_alu_s = %0x", op_pack.ref_ntt_alu_s);
            $display("ref_ntt_alu_0o = %0x", op_pack.ref_ntt_alu_0o);
            $display("ref_ntt_alu_1o = %0x", op_pack.ref_ntt_alu_1o);
        end
        else begin
            $display("<none>");
        end
    endtask

    generate
        for(i = 0;i < NLANE;i++) begin
            assign cur_op_p[i][0] = cur_op_p_input[i];

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
            assert property(@(posedge clk) i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_modalu.valid_o |-> ##(INTT_SWAP_LATENCY + NTT_ICONN_WRITE_LATENCY) i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.we || i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_1.we) else $finish;
            assert property(@(posedge clk) !((i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.we === 'b1) && (i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_1.we === 'b1))) else $finish;
            assign rfbank0_re_last[i][0] = i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.re;
            assign rfbank1_re_last[i][0] = i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_1.re;

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
                            rfbank0_vse_q[i].push_back(i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.rdata);
                        end
                        else if(cur_op_p[i][RF_STAGE_NUM].op_iconn) begin
                            rfbank0_iconn_q[i].push_back(i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.rdata);
                        end
                        else if(cur_op_p[i][RF_STAGE_NUM].op_ntt || cur_op_p[i][RF_STAGE_NUM].op_intt) begin

                        end
                        else begin
                            rfbank0_q[i].push_back(i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.rdata);
                        end
                    end

                    if(rfbank1_re_last[i][RF_READ_LATENCY]) begin
                        if(cur_op_p[i][RF_STAGE_NUM].op_vse) begin
                            rfbank1_vse_q[i].push_back(i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_1.rdata);
                        end
                        else if(cur_op_p[i][RF_STAGE_NUM].op_iconn) begin
                            rfbank1_iconn_q[i].push_back(i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.rdata);
                        end
                        else if(cur_op_p[i][RF_STAGE_NUM].op_ntt || cur_op_p[i][RF_STAGE_NUM].op_intt) begin

                        end
                        else begin
                            rfbank1_q[i].push_back(i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_1.rdata);
                        end
                    end

                    if(cur_op_p[i][RF_STAGE_NUM + ICONN_LATENCY].op_iconn) begin
                        iconn_read_q[i].push_back(i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_iconn_data);
                    end

                    if(!i[0]) begin
                        if(cur_op_p[i][ALU_INPUT_INDEX].op_ntt || cur_op_p[i][ALU_INPUT_INDEX].op_intt) begin
                            ntt_alu_0i_q[i].push_back(i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_modalu.opa_i);
                            ntt_alu_1i_q[i].push_back(i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_modalu.opb_i);
                            ntt_alu_s_q[i].push_back(i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_modalu.ops_i);
                        end

                        if(cur_op_p[i][INTT_SWAP_INDEX].op_ntt || cur_op_p[i][INTT_SWAP_INDEX].op_intt) begin
                            ntt_alu_0o_q[i].push_back(i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_modalu.res0_o);
                            ntt_alu_1o_q[i].push_back(i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_modalu.res1_o);
                        end
                    end
                end
            end

            //check op result
            initial begin
                forever begin
                    wait_clk();

                    if(lane_ntt_mb[i].try_peek(lane_cur_op[i])) begin
                        if((lane_cur_op[i].timestamp + lane_cur_op[i].latency) == cur_cycle) begin
                            lane_assert_failed[i] = '0;
                            lane_ignored[i] = '1;

                            if(lane_cur_op[i].i_op_cfg == 2'b00) begin
                                lane_ignored[i] = '0;

                                if(!i[0]) begin
                                    lane_opa[i] = ntt_alu_0i_q[i][0];
                                    ntt_alu_0i_q[i].pop_front();
                                    lane_opb[i] = ntt_alu_1i_q[i][0];
                                    ntt_alu_1i_q[i].pop_front();
                                    lane_ops[i] = ntt_alu_s_q[i][0];
                                    ntt_alu_s_q[i].pop_front();
                                    lane_res[i] = ntt_alu_0o_q[i][0];
                                    ntt_alu_0o_q[i].pop_front();
                                    lane_res2[i] = ntt_alu_1o_q[i][0];
                                    ntt_alu_1o_q[i].pop_front();

                                    `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_ntt_alu_0i, lane_opa[i], lane_assert_failed[i])
                                    `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_ntt_alu_1i, lane_opb[i], lane_assert_failed[i])
                                    `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_ntt_alu_s, lane_ops[i], lane_assert_failed[i])
                                    `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_ntt_alu_0o, lane_res[i], lane_assert_failed[i])
                                    `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_ntt_alu_1o, lane_res2[i], lane_assert_failed[i])
                                end
                            end

                            lane_ntt_mb[i].get(lane_cur_op[i]);
                            lane_op_cmp_result[i].push_back(lane_assert_failed[i]);
                            lane_op_ignored_result[i].push_back(lane_ignored[i]);

                            if(lane_assert_failed[i]) begin
                                $display("failed_op_id = %0d", lane_cur_op[i].id);
                                dump_op_pack(lane_cur_op[i]);
                            end
                        end
                    end

                    if(lane_intt_mb[i].try_peek(lane_cur_op[i])) begin
                        if((lane_cur_op[i].timestamp + lane_cur_op[i].latency) == cur_cycle) begin
                            lane_assert_failed[i] = '0;
                            lane_ignored[i] = '1;

                            if(lane_cur_op[i].i_op_cfg == 2'b00) begin
                                lane_ignored[i] = '0;

                                if(!i[0]) begin
                                    lane_opa[i] = ntt_alu_0i_q[i][0];
                                    ntt_alu_0i_q[i].pop_front();
                                    lane_opb[i] = ntt_alu_1i_q[i][0];
                                    ntt_alu_1i_q[i].pop_front();
                                    lane_ops[i] = ntt_alu_s_q[i][0];
                                    ntt_alu_s_q[i].pop_front();
                                    lane_res[i] = ntt_alu_0o_q[i][0];
                                    ntt_alu_0o_q[i].pop_front();
                                    lane_res2[i] = ntt_alu_1o_q[i][0];
                                    ntt_alu_1o_q[i].pop_front();

                                    `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_ntt_alu_0i, lane_opa[i], lane_assert_failed[i])
                                    `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_ntt_alu_1i, lane_opb[i], lane_assert_failed[i])
                                    `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_ntt_alu_s, lane_ops[i], lane_assert_failed[i])
                                    `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_ntt_alu_0o, lane_res[i], lane_assert_failed[i])
                                    `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_ntt_alu_1o, lane_res2[i], lane_assert_failed[i])
                                end
                            end

                            lane_intt_mb[i].get(lane_cur_op[i]);
                            lane_op_cmp_result[i].push_back(lane_assert_failed[i]);
                            lane_op_ignored_result[i].push_back(lane_ignored[i]);

                            if(lane_assert_failed[i]) begin
                                $display("failed_op_id = %0d", lane_cur_op[i].id);
                                dump_op_pack(lane_cur_op[i]);
                            end
                        end
                    end

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

                                `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_iconn_read_data, iconn_read_q[i][0], lane_assert_failed[i])
                                iconn_read_q[i].pop_front();

                                `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_bank0_wvld, i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.we, lane_assert_failed[i])
                                `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_bank1_wvld, i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_1.we, lane_assert_failed[i])

                                if(lane_cur_op[i].i_op_bk0_w[RF_ADDR_WIDTH]) begin
                                    `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_bank0_waddr, i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.waddr, lane_assert_failed[i]);
                                    `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_bank0_wdata, i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.wdata, lane_assert_failed[i]);
                                end
                                else begin
                                    `assert_equal_flag(lane_cur_op[i].ref_row, 1'b1, lane_cur_op[i].i_op_bk1_w[RF_ADDR_WIDTH], lane_assert_failed[i]);
                                    `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_bank1_waddr, i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_1.waddr, lane_assert_failed[i]);
                                    `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_bank1_wdata, i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_1.wdata, lane_assert_failed[i]);
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

                                    if(lane_cur_op[i].i_op_bk0_w[RF_ADDR_WIDTH]) begin
                                        `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_spm_rdata, i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.rf[{lane_cur_op[i].i_op_bk0_w[RF_ADDR_WIDTH - 1:0], lane_cur_op[i].i_cnt[$clog2(NELEMENT) - 1:0]}], lane_assert_failed[i]);
                                    end
                                    else begin
                                        `assert_equal_flag(lane_cur_op[i].ref_row, 1'b1, lane_cur_op[i].i_op_bk1_w[RF_ADDR_WIDTH], lane_assert_failed[i]);
                                        `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_spm_rdata, i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_1.rf[{lane_cur_op[i].i_op_bk1_w[RF_ADDR_WIDTH - 1:0], lane_cur_op[i].i_cnt[$clog2(NELEMENT) - 1:0]}], lane_assert_failed[i]);
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

                                    `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_alu_0i, lane_opa[i], lane_assert_failed[i])
                                    
                                    if(lane_cur_op[i].i_op_bk0_w[RF_ADDR_WIDTH]) begin
                                        `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_alu_o, i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.rf[{lane_cur_op[i].i_op_bk0_w[RF_ADDR_WIDTH - 1:0], lane_cur_op[i].i_cnt[$clog2(NELEMENT) - 1:0]}], lane_assert_failed[i]);
                                    end
                                    else begin
                                        `assert_equal_flag(lane_cur_op[i].ref_row, 1'b1, lane_cur_op[i].i_op_bk1_w[RF_ADDR_WIDTH], lane_assert_failed[i]);
                                        `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_alu_o, i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_1.rf[{lane_cur_op[i].i_op_bk1_w[RF_ADDR_WIDTH - 1:0], lane_cur_op[i].i_cnt[$clog2(NELEMENT) - 1:0]}], lane_assert_failed[i]);
                                    end
                                end

                                lane_mb[i].get(lane_cur_op[i]);
                                lane_op_cmp_result[i].push_back(lane_assert_failed[i]);
                                lane_op_ignored_result[i].push_back(lane_ignored[i]);

                                if(lane_assert_failed[i]) begin
                                    $display("failed_op_id = %0d", lane_cur_op[i].id);
                                    dump_op_pack(lane_cur_op[i]);
                                end
                            end
                        end
                    end

                    if(lane_cfg_mb[i].try_peek(lane_cur_op[i])) begin
                        if((lane_cur_op[i].timestamp + lane_cur_op[i].latency) == cur_cycle) begin
                            lane_assert_failed[i] = '0;
                            lane_ignored[i] = '0;
                            `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_config_valid, 1'b1, lane_assert_failed[i])

                            if(lane_cur_op[i].i_op_cfg == 2'b01) begin
                                `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_vl, i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.vl, lane_assert_failed[i])
                            end
                            else if(lane_cur_op[i].i_op_cfg == 2'b10) begin
                                `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_mod_q, i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.mod_q, lane_assert_failed[i])
                            end
                            else if(lane_cur_op[i].i_op_cfg == 2'b11) begin
                                `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_mod_iq, i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.mod_iq, lane_assert_failed[i])
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
                                        `assert_equal_flag(cur_cycle, lane_cur_op[i].ref_spm_wdata, rfbank0_vse_q[i][0], lane_assert_failed[i]);
                                        rfbank0_vse_q[i].pop_front();
                                    end
                                    else begin
                                        `assert_equal_flag(cur_cycle, 1'b1, lane_cur_op[i].i_op_bk1_r[RF_ADDR_WIDTH], lane_assert_failed[i]);
                                        `assert_equal_flag(cur_cycle, lane_cur_op[i].ref_spm_wdata, rfbank1_vse_q[i][0], lane_assert_failed[i]);
                                        rfbank1_vse_q[i].pop_front();
                                    end

                                    `assert_equal_flag(lane_cur_op[i].ref_row, lane_cur_op[i].ref_spm_wdata, o_vp_data[i * DATA_WIDTH +: DATA_WIDTH], lane_assert_failed[i]);
                                    `assert_equal_flag(lane_cur_op[i].ref_row, 1'b1, o_vp_wren, lane_assert_failed[i]);
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

    //tf mem fill
    function automatic longint unsigned ntt_tf_index(longint unsigned i, longint unsigned j);
        return (1 << i) + (j % (1 << i));
    endfunction

    function automatic longint unsigned powerMod(longint unsigned a, longint unsigned b, longint unsigned c);
        longint unsigned ans = 1;
        a = a % c;

        while(b > 0) begin
            if(b[0]) begin
                ans = (128'(ans)) * (128'(a)) % c;
            end

            b = b >> 1;
            a = (128'(a)) * (128'(a)) % c;
        end

        return ans;
    endfunction

    //don't use longint unsigned as type of len, otherwise vcs will crash
    function automatic longint unsigned BitReverse(longint unsigned aNum, int unsigned len);
        longint unsigned Num = 0;
        int unsigned i = 0;

        for(i = 0;i < len;i++) begin
            Num |= aNum[0] << ((len - 1) - i);
            aNum >>= 1;
        end

        return Num;
    endfunction

    function automatic longint unsigned intt_invtf_index(longint unsigned i, longint unsigned j, longint unsigned ntt_logn);
        return (1 << (ntt_logn - 1 - i)) + BitReverse((j / (1 << i)) % (1 << (ntt_logn - 1 - i)), ntt_logn - 1 - i);
    endfunction

    longint unsigned tf_vl = 524288;
    longint unsigned tf_stage_cyc = tf_vl / DATA_WIDTH / 2 / (NLANE / 2);
    longint unsigned tf_ntt_logn = $clog2(tf_vl / DATA_WIDTH);
    longint unsigned tf_item_id;
    longint unsigned tf_stage;
    longint unsigned tf_instage;
    longint unsigned tf_raddr;
    longint unsigned tf_raddr_m1;
    bit[TF_ADDR_WIDTH - 1:0] tf_tfaddr;
    longint unsigned tf_tfaddr2;
    longint unsigned tf_w_base[TF_ITEM_NUM] = '{64'd3825716582911, 64'd79932510954937, 64'd101017252977188};
    longint unsigned tf_reverse_w_base[TF_ITEM_NUM] = '{64'd264250557364078134, 64'd101614808487310449, 64'd106746493840490977};
    longint unsigned tf_mod_q[TF_ITEM_NUM] = {64'd576460825317867521, 64'd576460924102115329, 64'd576462951330889729};
    longint unsigned tf_w_index;
    longint unsigned tf_w;

    generate
        for(i = 0;i < NLANE / 2;i++) begin
            initial begin
                for(tf_item_id = 0;tf_item_id < TF_ITEM_NUM;tf_item_id++) begin
                    for(tf_stage = 0;tf_stage < tf_ntt_logn;tf_stage++) begin
                        for(tf_instage = 0;tf_instage < tf_stage_cyc;tf_instage++) begin
                            tf_raddr = (tf_instage >> 1) | (tf_instage[0] << ($clog2(tf_stage_cyc) - 1));
                            tf_raddr_m1 = ((tf_instage - 1) >> 1) | (((tf_instage - 1) & 'b1) << ($clog2(tf_stage_cyc) - 1));

                            if(tf_stage < $clog2(NLANE / 2)) begin
                                tf_tfaddr = tf_stage;
                                tf_tfaddr2 = tf_stage;
                            end
                            else begin
                                tf_tfaddr = (1 << (tf_stage - $clog2(NLANE / 2))) + (tf_instage & ((1 << (tf_stage - $clog2(NLANE / 2))) - 1)) + $clog2(NLANE / 2) - 1;
                                tf_tfaddr2 = (1 << (tf_stage - $clog2(NLANE / 2))) + (tf_instage & ((1 << (tf_stage - $clog2(NLANE / 2))) - 1)) + $clog2(NLANE / 2) - 1;
                            end

                            tf_tfaddr |= (tf_item_id << (TF_ADDR_WIDTH - $clog2(TF_ITEM_NUM)));
                            tf_tfaddr2 |= (tf_item_id << (TF_ADDR_WIDTH - $clog2(TF_ITEM_NUM)));

                            if(!tf_instage[0]) begin
                                tf_w_index = ntt_tf_index(tf_stage, tf_raddr * NLANE + unsigned'(i));
                            end
                            else begin
                                tf_w_index = ntt_tf_index(tf_stage, tf_raddr_m1 * NLANE + unsigned'(i) + NLANE / 2);
                            end

                            tf_w = powerMod(tf_w_base[tf_item_id], BitReverse(tf_w_index, tf_ntt_logn), tf_mod_q[tf_item_id]);

                            if(tf_tfaddr == 'h100) begin
                                //$display("stage = %0d, instage = %0d, i = %0d, w_index = %0d, tfaddr = %0d, w = %0x, tfaddr2 = %0d, TF_ADDR_WIDTH = %0d, raddr = %0d, raddr_m1 = %0d, i = %0d", tf_stage, tf_instage, i, tf_w_index, tf_tfaddr, tf_w, tf_tfaddr2, TF_ADDR_WIDTH, tf_raddr, tf_raddr_m1, i);
                            end

                            if($isunknown(i_vp_top.i_vxu_top.vxu_lane_block[i * 2].i_vxu_lane.tf_mem[tf_tfaddr])) begin
                                i_vp_top.i_vxu_top.vxu_lane_block[i * 2].i_vxu_lane.tf_mem[tf_tfaddr] = tf_w;
                            end
                            else if(i_vp_top.i_vxu_top.vxu_lane_block[i * 2].i_vxu_lane.tf_mem[tf_tfaddr] !== tf_w) begin
                                $display("error: ntt: tf_item_id = %0d, tfaddr = %0d, w_index = %0d - %0x !== %0x", tf_item_id, tf_tfaddr, tf_w_index, i_vp_top.i_vxu_top.vxu_lane_block[i * 2].i_vxu_lane.tf_mem[tf_tfaddr], tf_w);
                            end

                            if(tf_tfaddr != tf_tfaddr2) begin
                                $display("error: ntt: tf_item_id = %0d, tfaddr = %0x and tfaddr2 = %0x aren't equal!", tf_item_id, tf_tfaddr, tf_tfaddr2);
                            end

                            //$display("stage = %0d, instage = %0d, i = %0d, tfaddr = %0x", tf_stage, tf_instage, i, tf_tfaddr);

                            tf_raddr = tf_stage_cyc - 1 - tf_instage;

                            if(tf_stage >= (tf_ntt_logn - $clog2(NLANE / 2))) begin
                                tf_tfaddr = tf_ntt_logn - tf_stage - 1;
                                tf_tfaddr2 = tf_ntt_logn - tf_stage - 1;
                            end
                            else begin
                                tf_tfaddr = (1 << (tf_ntt_logn - 1 - $clog2(NLANE / 2) - tf_stage)) + ((tf_stage_cyc - tf_instage - 1) & ((1 << (tf_ntt_logn - 1 - $clog2(NLANE / 2) - tf_stage)) - 1)) + $clog2(NLANE / 2) - 1;
                                tf_tfaddr2 = (1 << (tf_ntt_logn - 1 - $clog2(NLANE / 2) - tf_stage)) + ((tf_stage_cyc - tf_instage - 1) & ((1 << (tf_ntt_logn - 1 - $clog2(NLANE / 2) - tf_stage)) - 1)) + $clog2(NLANE / 2) - 1;
                            end

                            tf_tfaddr |= 1 << (TF_ADDR_WIDTH - 1 - $clog2(TF_ITEM_NUM));
                            tf_tfaddr2 |= 1 << (TF_ADDR_WIDTH - 1 - $clog2(TF_ITEM_NUM));

                            tf_tfaddr |= (tf_item_id << (TF_ADDR_WIDTH - $clog2(TF_ITEM_NUM)));
                            tf_tfaddr2 |= (tf_item_id << (TF_ADDR_WIDTH - $clog2(TF_ITEM_NUM)));

                            tf_w_index = intt_invtf_index(tf_stage, BitReverse(tf_raddr * NLANE + 2 * unsigned'(i), tf_ntt_logn), tf_ntt_logn);
                            tf_w = powerMod(tf_reverse_w_base[tf_item_id], BitReverse(tf_w_index, tf_ntt_logn), tf_mod_q[tf_item_id]);

                            if($isunknown(i_vp_top.i_vxu_top.vxu_lane_block[i * 2].i_vxu_lane.tf_mem[tf_tfaddr])) begin
                                i_vp_top.i_vxu_top.vxu_lane_block[i * 2].i_vxu_lane.tf_mem[tf_tfaddr] = tf_w;
                            end
                            else if(i_vp_top.i_vxu_top.vxu_lane_block[i * 2].i_vxu_lane.tf_mem[tf_tfaddr] !== tf_w) begin
                                $display("error: intt: tf_item_id = %0d, tfaddr = %0d, w_index = %0d - %0x !== %0x", tf_item_id, tf_tfaddr, tf_w_index, i_vp_top.i_vxu_top.vxu_lane_block[i * 2].i_vxu_lane.tf_mem[tf_tfaddr], tf_w);
                            end

                            if(tf_tfaddr != tf_tfaddr2) begin
                                $display("error: intt: tf_item_id = %0d, tfaddr = %0x and tfaddr2 = %0x aren't equal!", tf_item_id, tf_tfaddr, tf_tfaddr2);
                            end
                        end
                    end
                end
            end
        end
    endgenerate

    initial begin
        tdb_issue = new;
        tdb_exe = new;

        for(k = 0;k < NLANE;k++) begin
            lane_mb[k] = new();
            lane_cfg_mb[k] = new();
            lane_vse_mb[k] = new();
            lane_iconn_mb[k] = new();
            lane_ntt_mb[k] = new();
            lane_intt_mb[k] = new();
        end

        tdb_issue.open({getenv("TDB_PATH"), "/issue.tdb"});
        tdb_exe.open({getenv("TDB_PATH"), "/exe.tdb"});
        //$readmemh("../../../cmodel/code/ISRAM_mul_plain.mem", isram);
        //$readmemh("../../../cmodel/code/ISRAM_homo_add.mem", isram);
        //$readmemh("../../../cmodel/code/ISRAM_vroli_1.mem", isram);
        //$readmemh("../../../cmodel/code/ISRAM_vroli_10.mem", isram);
        //$readmemh("../../../cmodel/code/ISRAM_vroli_32.mem", isram);
        //$readmemh("../../../cmodel/code/ISRAM_vaut_1.mem", isram);
        //$readmemh("../../../cmodel/code/ISRAM_vaut_3.mem", isram);
        //$readmemh("../../../cmodel/code/ISRAM_ntt_intt_8192.mem", isram);
        //$readmemh("../../../cmodel/code/ISRAM_combine.mem", isram);
        $readmemh(getenv("ISRAM_FILE"), isram);
        //$readmemh("../../../cmodel/SPM_seq.mem", spm_init);
        //$readmemh("../../../cmodel/SPM_random.mem", spm_init);
        $readmemh(getenv("SPM_FILE"), spm_init);
        t = $sscanf(getenv("SRC0_PTR"), "%h", i_csr_vp_src0_ptr);
        t = $sscanf(getenv("SRC1_PTR"), "%h", i_csr_vp_src1_ptr);
        t = $sscanf(getenv("RSLT_PTR"), "%h", i_csr_vp_rslt_ptr);
        t = $sscanf(getenv("KSK_PTR"), "%h", i_csr_vp_ksk_ptr);
        t = $sscanf(getenv("STEP"), "%h", i_csr_vp_step);

        reset();
        wait_clk();
        i_start_vp = 'b1;
        wait_clk();
        `assert(tdb_issue.read_cur_row())
        `assert(tdb_exe.read_cur_row())
        issue_row = tdb_issue.get_cur_row();
        exe_row = tdb_exe.get_cur_row();

        inst_id = 0;
        
        while(1) begin
            if(i_vp_top.o_seq_vxu_issue_vld) begin
                total_op++;
                /*if(inst_id >= 5) begin
                    break;
                end*/

                $display("found vxu seq: %0d", inst_id);
                $display("vmu_opls0 = %0d", i_vp_top.o_seq_vmu_op_ls[0]);
                $display("cur_cycle = %0d, diff_cycle = %0d", cur_cycle, cur_cycle - last_cycle);
                last_cycle = cur_cycle;
                `assert_equal(issue_row, 1'b1, i_vp_top.o_seq_vmu_issue_vld)
                `assert_equal(issue_row, tdb_issue.get_uint8(DOMAIN_OUTPUT, "vxu_opconfig", 0), i_vp_top.o_seq_vxu_op_config)

                if(i_vp_top.o_seq_vxu_op_config != '0) begin
                    `assert_equal(issue_row, tdb_issue.get_uint64(DOMAIN_OUTPUT, "vxu_scalarconfig", 0), i_vp_top.o_seq_vxu_scalar_config)
                end
                
                `assert_equal(issue_row, tdb_issue.get_uint8(DOMAIN_OUTPUT, "vxu_opb0r", 0), i_vp_top.o_seq_vxu_op_b0r)
                `assert_equal(issue_row, tdb_issue.get_uint8(DOMAIN_OUTPUT, "vxu_opb0w", 0), i_vp_top.o_seq_vxu_op_b0w)
                `assert_equal(issue_row, tdb_issue.get_uint8(DOMAIN_OUTPUT, "vxu_opb1r", 0), i_vp_top.o_seq_vxu_op_b1r)
                `assert_equal(issue_row, tdb_issue.get_uint8(DOMAIN_OUTPUT, "vxu_opb1w", 0), i_vp_top.o_seq_vxu_op_b1w)
                `assert_equal(issue_row, tdb_issue.get_uint8(DOMAIN_OUTPUT, "vxu_opalu", 0), i_vp_top.o_seq_vxu_op_alu)
                `assert_equal(issue_row, tdb_issue.get_uint64(DOMAIN_OUTPUT, "vxu_scalaralu", 0), i_vp_top.o_seq_vxu_scalar_alu)
                `assert_equal(issue_row, tdb_issue.get_uint8(DOMAIN_OUTPUT, "vxu_opiconn", 0), i_vp_top.o_seq_vxu_op_iconn)
                `assert_equal(issue_row, tdb_issue.get_uint64(DOMAIN_OUTPUT, "vxu_scalariconn", 0), i_vp_top.o_seq_vxu_scalar_iconn)
                `assert_equal(issue_row, tdb_issue.get_uint8(DOMAIN_OUTPUT, "vxu_opntt", 0), i_vp_top.o_seq_vxu_op_ntt)
                `assert_equal(issue_row, tdb_issue.get_uint8(DOMAIN_OUTPUT, "vxu_muxo", 0), i_vp_top.o_seq_vxu_op_muxo)
                `assert_equal(issue_row, tdb_issue.get_uint8(DOMAIN_OUTPUT, "vxu_muxi", 0), i_vp_top.o_seq_vxu_op_muxi)
                `assert_equal(issue_row, tdb_issue.get_uint8(DOMAIN_OUTPUT, "vmu_opconfig", 0), i_vp_top.o_seq_vmu_op_config)

                if(i_vp_top.o_seq_vmu_op_config != '0) begin
                    `assert_equal(issue_row, tdb_issue.get_uint64(DOMAIN_OUTPUT, "vmu_scalarconfig", 0), i_vp_top.o_seq_vmu_scalar_config)
                end

                `assert_equal(issue_row, tdb_issue.get_uint8(DOMAIN_OUTPUT, "vmu_opls0", 0), i_vp_top.o_seq_vmu_op_ls[0])
                `assert_equal(issue_row, tdb_issue.get_uint64(DOMAIN_OUTPUT, "vmu_scalarls0", 0), i_vp_top.o_seq_vmu_scalar_ls[0])
                
                pack.i_op_vld = 1'b1;
                pack.i_cnt = '0;
                pack.i_op_cfg = i_vp_top.o_seq_vxu_op_config;
                pack.i_scalar_cfg = i_vp_top.o_seq_vxu_scalar_config;
                pack.i_op_bk0_r = {i_vp_top.o_seq_vxu_op_b0r[0], i_vp_top.o_seq_vxu_op_b0r[`RW_OP_WIDTH - 1:2]};
                pack.i_op_bk0_w = {i_vp_top.o_seq_vxu_op_b0w[0], i_vp_top.o_seq_vxu_op_b0w[`RW_OP_WIDTH - 1:2]};
                pack.i_op_bk1_r = {i_vp_top.o_seq_vxu_op_b1r[0], i_vp_top.o_seq_vxu_op_b1r[`RW_OP_WIDTH - 1:2]};
                pack.i_op_bk1_w = {i_vp_top.o_seq_vxu_op_b1w[0], i_vp_top.o_seq_vxu_op_b1w[`RW_OP_WIDTH - 1:2]};
                pack.i_op_alu = i_vp_top.o_seq_vxu_op_alu;
                pack.i_scalar_alu = i_vp_top.o_seq_vxu_scalar_alu;
                pack.i_op_iconn = i_vp_top.o_seq_vxu_op_iconn;
                pack.i_scalar_iconn = i_vp_top.o_seq_vxu_scalar_iconn;
                pack.i_op_ntt = i_vp_top.o_seq_vxu_op_ntt;
                pack.i_mux_o = i_vp_top.o_seq_vxu_op_muxo;
                pack.i_mux_i = i_vp_top.o_seq_vxu_op_muxi;
                pack.latency = (i_vp_top.o_seq_vxu_op_config != '0) ? 'd1 : ((i_vp_top.o_seq_vmu_op_ls[0] == 2'b10) || (i_vp_top.o_seq_vxu_op_iconn != '0)) ? (TOTAL_STAGE - 1) : TOTAL_STAGE;
                pack.op_vle = (i_vp_top.o_seq_vmu_op_ls[0] == 2'b01) && ((i_vp_top.o_seq_vxu_op_muxi[1:0] === 2'b11) || (i_vp_top.o_seq_vxu_op_muxi[3:2] == 2'b11));
                pack.op_vse = (i_vp_top.o_seq_vmu_op_ls[0] == 2'b10);
                pack.op_alu = (i_vp_top.o_seq_vxu_op_config === '0) && !pack.op_vle && !pack.op_vse && (i_vp_top.o_seq_vxu_op_iconn === '0) && (i_vp_top.o_seq_vxu_op_ntt === '0);
                pack.op_ntt = (i_vp_top.o_seq_vxu_op_ntt == 'b010);
                pack.op_intt = (i_vp_top.o_seq_vxu_op_ntt == 'b011);
                pack.op_iconn = (i_vp_top.o_seq_vxu_op_iconn != '0) && !pack.op_ntt && !pack.op_intt; 
                pack.id = inst_id;
                pack.timestamp = cur_cycle;
                pack.mod_q = i_vp_top.i_vxu_top.vxu_lane_block[0].i_vxu_lane.mod_q;
                pack.mod_iq = i_vp_top.i_vxu_top.vxu_lane_block[0].i_vxu_lane.mod_iq;
                pack.vl = i_vp_top.i_vxu_top.vxu_lane_block[0].i_vxu_lane.vl;
                pack.ref_row = exe_row;
                pack.ref_vl = tdb_exe.get_uint64(DOMAIN_OUTPUT, "vl", 0);
                pack.ref_mod_q = tdb_exe.get_uint64(DOMAIN_OUTPUT, "mod_q", 0);
                pack.ref_mod_iq = tdb_exe.get_uint64(DOMAIN_OUTPUT, "mod_iq", 0);
                pack.ref_config_valid = tdb_exe.get_uint8(DOMAIN_OUTPUT, "config_valid", 0);

                for(k = 0;k < NLANE;k++) begin
                    pack.ref_bank0_rvld = tdb_exe.get_uint8(DOMAIN_OUTPUT, "bank0_rvld", k);
                    pack.ref_bank0_raddr = tdb_exe.get_uint32(DOMAIN_OUTPUT, "bank0_raddr", k) >> 1;
                    pack.ref_bank0_rdata = tdb_exe.get_uint64(DOMAIN_OUTPUT, "bank0_rdata", k);
                    pack.ref_bank1_rvld = tdb_exe.get_uint8(DOMAIN_OUTPUT, "bank1_rvld", k);
                    pack.ref_bank1_raddr = tdb_exe.get_uint32(DOMAIN_OUTPUT, "bank1_raddr", k) >> 1;
                    pack.ref_bank1_rdata = tdb_exe.get_uint64(DOMAIN_OUTPUT, "bank1_rdata", k);
                    pack.ref_spm_rdata = tdb_exe.get_uint64(DOMAIN_OUTPUT, "spm_rdata", k);
                    pack.ref_spm_rvld = tdb_exe.get_uint8(DOMAIN_OUTPUT, "spm_rvld", k);
                    pack.ref_spm_wdata = tdb_exe.get_uint64(DOMAIN_OUTPUT, "spm_wdata", k);
                    pack.ref_spm_wvld = tdb_exe.get_uint8(DOMAIN_OUTPUT, "spm_wvld", k);
                    pack.ref_alu_0i = tdb_exe.get_uint64(DOMAIN_OUTPUT, "alu_0i", k);
                    pack.ref_alu_1i = tdb_exe.get_uint64(DOMAIN_OUTPUT, "alu_1i", k);
                    pack.ref_alu_o = tdb_exe.get_uint64(DOMAIN_OUTPUT, "alu_o", k);
                    pack.ref_bank0_wvld = tdb_exe.get_uint8(DOMAIN_OUTPUT, "bank0_wvld", k);
                    pack.ref_bank0_waddr = tdb_exe.get_uint32(DOMAIN_OUTPUT, "bank0_waddr", k);
                    pack.ref_bank0_wdata = tdb_exe.get_uint64(DOMAIN_OUTPUT, "bank0_wdata", k);
                    pack.ref_bank1_wvld = tdb_exe.get_uint8(DOMAIN_OUTPUT, "bank1_wvld", k);
                    pack.ref_bank1_waddr = tdb_exe.get_uint32(DOMAIN_OUTPUT, "bank1_waddr", k);
                    pack.ref_bank1_wdata = tdb_exe.get_uint64(DOMAIN_OUTPUT, "bank1_wdata", k);
                    pack.ref_iconn_read_data = tdb_exe.get_uint64(DOMAIN_OUTPUT, "iconn_read_data", k);
                    pack.ref_ntt_raddr0 = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_raddr0", k);
                    pack.ref_ntt_rdata0 = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_rdata0", k);
                    pack.ref_ntt_raddr1 = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_raddr1", k);
                    pack.ref_ntt_rdata1 = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_rdata1", k);
                    pack.ref_ntt_waddr0 = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_waddr0", k);
                    pack.ref_ntt_wdata0 = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_wdata0", k);
                    pack.ref_ntt_waddr1 = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_waddr1", k);
                    pack.ref_ntt_wdata1 = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_wdata1", k);
                    pack.ref_ntt_alu_0i = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_alu_0i", k);
                    pack.ref_ntt_alu_1i = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_alu_1i", k);
                    pack.ref_ntt_alu_s = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_alu_s", k);
                    pack.ref_ntt_alu_0o = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_alu_0o", k);
                    pack.ref_ntt_alu_1o = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_alu_1o", k);

                    if(pack.i_op_cfg == 2'b00) begin
                        if(pack.op_vse) begin
                            lane_vse_mb[k].put(pack);
                        end
                        else if(pack.op_iconn) begin
                            lane_iconn_mb[k].put(pack);
                        end
                        else if(pack.op_ntt) begin
                            lane_ntt_mb[k].put(pack);
                        end
                        else if(pack.op_intt) begin
                            lane_intt_mb[k].put(pack);
                        end
                        else begin
                            lane_mb[k].put(pack);
                        end
                    end
                    else begin
                        lane_cfg_mb[k].put(pack);
                    end

                    cur_op_p_input[k] = pack;
                end

                if(assert_failed) begin
                    $finish;
                end

                if(i_vp_top.i_seq_top.is_nxt_state != i_vp_top.i_seq_top.IS_WAIT) begin
                    tdb_issue.move_to_next_row();
                    t = tdb_issue.read_cur_row();
                    issue_row = tdb_issue.get_cur_row();
                    inst_id++;
                end
                
                tdb_exe.move_to_next_row();

                if(!tdb_exe.read_cur_row() || o_done_vp) begin
                    break;
                end

                exe_row = tdb_exe.get_cur_row();
            end
            else if(i_vp_top.o_seq_comp_vld) begin
                total_op++;
                pack.i_cnt = i_vp_top.o_seq_cnt;
                pack.timestamp = cur_cycle;
                pack.ref_row = exe_row;
                pack.ref_vl = tdb_exe.get_uint64(DOMAIN_OUTPUT, "vl", 0);
                pack.ref_mod_q = tdb_exe.get_uint64(DOMAIN_OUTPUT, "mod_q", 0);
                pack.ref_mod_iq = tdb_exe.get_uint64(DOMAIN_OUTPUT, "mod_iq", 0);
                pack.ref_config_valid = tdb_exe.get_uint8(DOMAIN_OUTPUT, "config_valid", 0);

                for(k = 0;k < NLANE;k++) begin
                    pack.ref_bank0_rvld = tdb_exe.get_uint8(DOMAIN_OUTPUT, "bank0_rvld", k);
                    pack.ref_bank0_raddr = tdb_exe.get_uint32(DOMAIN_OUTPUT, "bank0_raddr", k) >> 1;
                    pack.ref_bank0_rdata = tdb_exe.get_uint64(DOMAIN_OUTPUT, "bank0_rdata", k);
                    pack.ref_bank1_rvld = tdb_exe.get_uint8(DOMAIN_OUTPUT, "bank1_rvld", k);
                    pack.ref_bank1_raddr = tdb_exe.get_uint32(DOMAIN_OUTPUT, "bank1_raddr", k) >> 1;
                    pack.ref_bank1_rdata = tdb_exe.get_uint64(DOMAIN_OUTPUT, "bank1_rdata", k);
                    pack.ref_spm_rdata = tdb_exe.get_uint64(DOMAIN_OUTPUT, "spm_rdata", k);
                    pack.ref_spm_rvld = tdb_exe.get_uint8(DOMAIN_OUTPUT, "spm_rvld", k);
                    pack.ref_spm_wdata = tdb_exe.get_uint64(DOMAIN_OUTPUT, "spm_wdata", k);
                    pack.ref_spm_wvld = tdb_exe.get_uint8(DOMAIN_OUTPUT, "spm_wvld", k);
                    pack.ref_alu_0i = tdb_exe.get_uint64(DOMAIN_OUTPUT, "alu_0i", k);
                    pack.ref_alu_1i = tdb_exe.get_uint64(DOMAIN_OUTPUT, "alu_1i", k);
                    pack.ref_alu_o = tdb_exe.get_uint64(DOMAIN_OUTPUT, "alu_o", k);
                    pack.ref_bank0_wvld = tdb_exe.get_uint8(DOMAIN_OUTPUT, "bank0_wvld", k);
                    pack.ref_bank0_waddr = tdb_exe.get_uint32(DOMAIN_OUTPUT, "bank0_waddr", k);
                    pack.ref_bank0_wdata = tdb_exe.get_uint64(DOMAIN_OUTPUT, "bank0_wdata", k);
                    pack.ref_bank1_wvld = tdb_exe.get_uint8(DOMAIN_OUTPUT, "bank1_wvld", k);
                    pack.ref_bank1_waddr = tdb_exe.get_uint32(DOMAIN_OUTPUT, "bank1_waddr", k);
                    pack.ref_bank1_wdata = tdb_exe.get_uint64(DOMAIN_OUTPUT, "bank1_wdata", k);
                    pack.ref_iconn_read_data = tdb_exe.get_uint64(DOMAIN_OUTPUT, "iconn_read_data", k);
                    pack.ref_ntt_raddr0 = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_raddr0", k);
                    pack.ref_ntt_rdata0 = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_rdata0", k);
                    pack.ref_ntt_raddr1 = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_raddr1", k);
                    pack.ref_ntt_rdata1 = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_rdata1", k);
                    pack.ref_ntt_waddr0 = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_waddr0", k);
                    pack.ref_ntt_wdata0 = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_wdata0", k);
                    pack.ref_ntt_waddr1 = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_waddr1", k);
                    pack.ref_ntt_wdata1 = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_wdata1", k);
                    pack.ref_ntt_alu_0i = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_alu_0i", k);
                    pack.ref_ntt_alu_1i = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_alu_1i", k);
                    pack.ref_ntt_alu_s = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_alu_s", k);
                    pack.ref_ntt_alu_0o = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_alu_0o", k);
                    pack.ref_ntt_alu_1o = tdb_exe.get_uint64(DOMAIN_OUTPUT, "ntt_alu_1o", k);

                    if(pack.i_op_cfg == 2'b00) begin
                        if(pack.op_vse) begin
                            lane_vse_mb[k].put(pack);
                        end
                        else if(pack.op_iconn) begin
                            lane_iconn_mb[k].put(pack);
                        end
                        else if(pack.op_ntt) begin
                            lane_ntt_mb[k].put(pack);
                        end
                        else if(pack.op_intt) begin
                            lane_intt_mb[k].put(pack);
                        end
                        else begin
                            lane_mb[k].put(pack);
                        end
                    end
                    else begin
                        lane_cfg_mb[k].put(pack);
                    end

                    cur_op_p_input[k] = pack;
                end

                if(assert_failed) begin
                    $finish;
                end

                if(i_vp_top.i_seq_top.is_nxt_state != i_vp_top.i_seq_top.IS_WAIT) begin
                    tdb_issue.move_to_next_row();
                    t = tdb_issue.read_cur_row();
                    issue_row = tdb_issue.get_cur_row();
                    inst_id++;
                end
                
                tdb_exe.move_to_next_row();

                if(!tdb_exe.read_cur_row() || o_done_vp) begin
                    break;
                end

                exe_row = tdb_exe.get_cur_row();
            end
            else begin
                for(k = 0;k < NLANE;k++) begin
                    cur_op_p_input[k] = emit_none();
                end
            end

            wait_clk();
        end

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

        #100;
        $display("total_op = %0d, passed_op = %0d, failed_op = %0d, ignored_op = %0d", total_op, passed_op, failed_op, ignored_op);
        #100;
        $writememh({getenv("RUN_PATH"), "/spm_out.mem"}, spm);
        $system("mkdir -p vrf_dump");
        reg_dump_enable = 1;
        #100;
        $finish;
    end

    generate
        for(i = 0;i < 2 ** (`RW_OP_WIDTH - 1);i++) begin
            if(!i[0]) begin
                initial begin
                    wait(reg_dump_enable == 1);
                    $writememh({getenv("RUN_PATH"), "/vrf_dump/", $sformatf("%0d", i), ".mem"}, i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_0.rf);
                end
            end
            else begin
                initial begin
                    wait(reg_dump_enable == 1);
                    $writememh({getenv("RUN_PATH"), "/vrf_dump/", $sformatf("%0d", i), ".mem"}, i_vp_top.i_vxu_top.vxu_lane_block[i].i_vxu_lane.i_vxu_rfbank_1.rf);
                end
            end
        end
    endgenerate

    `ifdef FSDB_DUMP
        initial begin
            $fsdbDumpfile("top.fsdb");
            $fsdbDumpvars(0, 0, "+all");
            $fsdbDumpMDA();
        end
    `endif
endmodule