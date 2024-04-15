`timescale 1ns/100ps

`define assert(condition) assert((condition)) else begin #10; $finish; end
`define assert_equal(_cycle, _expected, _actual) assert((_expected) === (_actual)) else begin $display("cycle = %0d, expected = %0x, actual = %0x", (_cycle), (_expected), (_actual)); assert_failed = 1; end
`define assert_equal_flag(_cycle, _expected, _actual, _flag) assert((_expected) === (_actual)) else begin $display("cycle = %0d, expected = %0x, actual = %0x", (_cycle), (_expected), (_actual)); _flag = 1; end

module top;
    parameter NLANE = 128;
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 64;
    parameter VLMAX = 1 << 22;
    parameter TF_ITEM_NUM = 3;
    parameter TF_ADDR_WIDTH = 16;
    localparam STAGE_CYC = VLMAX / DATA_WIDTH / 2 / (NLANE / 2);
    localparam NTT_LOGN = $clog2(VLMAX / DATA_WIDTH);
    localparam CNT_HB_WIDTH = $clog2(NTT_LOGN);
    localparam CNT_LB_WIDTH = $clog2(STAGE_CYC);
    localparam CNT_WIDTH = CNT_HB_WIDTH + CNT_LB_WIDTH;

    logic clk;

    logic i_idle;
    logic i_ntt_mode;
    logic[CNT_WIDTH - 1:0] i_cnt;
    logic[DATA_WIDTH - 1:0] i_vl;
    logic[ADDR_WIDTH - 1:0] o_shared_raddr;
    logic[ADDR_WIDTH - 1:0] o_shared_waddr;
    logic[TF_ADDR_WIDTH - 1:0] o_shared_tfaddr;
    logic o_rw_vrf_swap;
    logic o_alu_inout_swap;
    logic[CNT_WIDTH:0] o_ntt_inst_std_cnt;

    int i, j;
    int ntt_logn;
    int stage_cyc;
    logic[DATA_WIDTH - 1:0] cnt_hb;
    logic[DATA_WIDTH - 1:0] cnt_lb;
    logic[ADDR_WIDTH - 1:0] expected_raddr;
    logic[ADDR_WIDTH - 1:0] expected_waddr;
    logic[ADDR_WIDTH - 1:0] expected_tfaddr;
    logic expected_rw_vrf_swap;
    logic expected_alu_inout_swap;

    bit assert_failed = 0;
    bit display_sync = 0;

    ntt_fsm#(
        .NLANE(NLANE),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .TF_ADDR_WIDTH(TF_ADDR_WIDTH),
        .VLMAX(VLMAX)
    )i_ntt_fsm(
        .clk(clk),
        .i_idle(i_idle),
        .i_ntt_mode(i_ntt_mode),
        .i_cnt(i_cnt),
        .i_vl(i_vl),
        .i_tf_item_id($clog2(TF_ITEM_NUM)'(0)),
        .o_shared_raddr(o_shared_raddr),
        .o_shared_waddr(o_shared_waddr),
        .o_shared_tfaddr(o_shared_tfaddr),
        .o_rw_vrf_swap(o_rw_vrf_swap),
        .o_alu_inout_swap(o_alu_inout_swap),
        .o_ntt_inst_std_cnt(o_ntt_inst_std_cnt)
    );

    task wait_clk;
        @(posedge clk);
        #0.1;
    endtask

    task eval;
        #0.1;
    endtask

    task test_ntt(logic idle);
        $display("ntt test");
        i_idle = idle;
        i_ntt_mode = 1;

        for(i = 16;i <= 22;i++) begin
            i_vl = 1 << i;
            wait_clk();
            ntt_logn = unsigned'($clog2(i_vl / DATA_WIDTH));
            stage_cyc = i_vl / DATA_WIDTH / 2 / (NLANE / 2);
            //$display("i_vl = %0d, ntt_logn = %0d, stage_cyc = %0d", i_vl, ntt_logn, stage_cyc);

            for(j = 0;j <= (('d1 << ($clog2(ntt_logn) + $clog2(stage_cyc))) - 1);j++) begin
                i_cnt = j;
                cnt_hb = i_cnt >> $clog2(stage_cyc);
                cnt_lb = i_cnt & (stage_cyc - 'd1);
                expected_raddr = (cnt_lb >> 1) | (cnt_lb[0] << ($clog2(stage_cyc) - 1));
                expected_waddr = cnt_lb;

                if(cnt_hb < unsigned'($clog2(NLANE))) begin
                    expected_tfaddr = cnt_hb;
                end
                else begin
                    expected_tfaddr = ('d1 << (cnt_hb - unsigned'($clog2(NLANE / 2)))) + (cnt_lb & (('d1 << (cnt_hb - unsigned'($clog2(NLANE / 2)))) - 'd1)) + unsigned'($clog2(NLANE / 2)) - 'd1;
                end

                expected_rw_vrf_swap = idle ? 0 : cnt_hb[0];
                expected_alu_inout_swap = idle ? 0 : cnt_lb[0];
                eval();
                //$display("i_cnt = %0x, cnt_hb = %0x, cnt_lb = %0x, o_shared_raddr = %0x, o_shared_waddr = %0x, o_shared_tfaddr = %0x", i_cnt, cnt_hb, cnt_lb, o_shared_raddr, o_shared_waddr, o_shared_tfaddr);
                `assert_equal(i, expected_raddr, o_shared_raddr)
                `assert_equal(i, expected_waddr, o_shared_waddr)
                `assert_equal(i, expected_tfaddr, o_shared_tfaddr)
                `assert_equal(i, expected_rw_vrf_swap, o_rw_vrf_swap)
                `assert_equal(i, expected_alu_inout_swap, o_alu_inout_swap)
                `assert_equal(i, stage_cyc * ntt_logn, o_ntt_inst_std_cnt)
            end
        end
    endtask

    task test_intt(logic idle);
        $display("intt test");
        i_idle = idle;
        i_ntt_mode = 0;

        for(i = 16;i <= 22;i++) begin
            i_vl = 1 << i;
            wait_clk();
            ntt_logn = $clog2(i_vl / DATA_WIDTH);
            stage_cyc = i_vl / DATA_WIDTH / 2 / (NLANE / 2);
            $display("i_vl = %0d, ntt_logn = %0d, stage_cyc = %0d", i_vl, ntt_logn, stage_cyc);

            for(j = 0;j <= (('d1 << ($clog2(ntt_logn) + $clog2(stage_cyc))) - 1);j++) begin
                i_cnt = j;
                cnt_hb = i_cnt >> $clog2(stage_cyc);
                cnt_lb = i_cnt & (stage_cyc - 'd1);
                expected_raddr = stage_cyc - cnt_lb - 'd1;
                expected_waddr = (expected_raddr >> 1) | (expected_raddr[0] << ($clog2(stage_cyc) - 1));

                if((signed'(ntt_logn) - 'sb1 - signed'($clog2(NLANE / 2)) - signed'(cnt_hb) - 'sb1) >= 'sb0) begin
                    expected_tfaddr = ('d1 << (ntt_logn - 'd1 - unsigned'($clog2(NLANE / 2)) - cnt_hb)) + ((stage_cyc - cnt_lb - 'd1) & (('d1 << (ntt_logn - 'd1 - unsigned'($clog2(NLANE / 2)) - cnt_hb)) - 'd1)) + unsigned'($clog2(NLANE / 2)) - 'd1 + ('d1 << (TF_ADDR_WIDTH - 1 - $clog2(TF_ITEM_NUM)));
                end
                else begin
                    expected_tfaddr = ntt_logn - cnt_hb - 'd1 + ('d1 << (TF_ADDR_WIDTH - 1 - $clog2(TF_ITEM_NUM)));
                end

                expected_rw_vrf_swap = idle ? 0 : cnt_hb[0];
                expected_alu_inout_swap = idle ? 0 : cnt_lb[0];
                eval();
                //$display("i_cnt = %0x, cnt_hb = %0x, cnt_lb = %0x, o_shared_raddr = %0x, o_shared_waddr = %0x, o_shared_tfaddr = %0x", i_cnt, cnt_hb, cnt_lb, o_shared_raddr, o_shared_waddr, o_shared_tfaddr);
                `assert_equal(i, expected_raddr, o_shared_raddr)
                `assert_equal(i, expected_waddr, o_shared_waddr)
                `assert_equal(i, expected_tfaddr, o_shared_tfaddr)
                `assert_equal(i, expected_rw_vrf_swap, o_rw_vrf_swap)
                `assert_equal(i, expected_alu_inout_swap, o_alu_inout_swap)
                `assert_equal(i, stage_cyc * ntt_logn, o_ntt_inst_std_cnt)
            end
        end
    endtask

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        wait(display_sync == 1);
        test_ntt(0);
        test_intt(0);
        test_ntt(1);
        test_intt(1);
        #1000;

        if(assert_failed == 0) begin
            $display("TEST PASSED");
        end

        $finish;
    end

    `ifdef FSDB_DUMP
        initial begin
            $fsdbDumpfile("top.fsdb");
            $fsdbDumpvars(0, 0, "+all");
            $fsdbDumpMDA();
            display_sync = 1;
        end
    `else
        initial begin
            display_sync = 1;
        end
    `endif
endmodule