`timescale 1ns/100ps

`define assert(condition) assert((condition)) else begin #10; $finish; end
`define assert_equal(_cycle, _expected, _actual) assert((_expected) === (_actual)) else begin $display("cycle = %0d, expected = %0x, actual = %0x", (_cycle), (_expected), (_actual)); assert_failed = 1; end
`define assert_equal_flag(_cycle, _expected, _actual, _flag) assert((_expected) === (_actual)) else begin $display("cycle = %0d, expected = %0x, actual = %0x", (_cycle), (_expected), (_actual)); _flag = 1; end

module top;
    parameter DATA_WIDTH = 64;
    parameter LATENCY = 1;

    logic clk;
    logic i_alu_inout_swap;
    logic[DATA_WIDTH - 1:0] i_data0;
    logic[DATA_WIDTH - 1:0] i_data1;
    logic[DATA_WIDTH - 1:0] o_data0;
    logic[DATA_WIDTH - 1:0] o_data1;

    bit assert_failed = 0;
    bit display_sync = 0;
    bit test_swap_sync;
    bit test_noswap_sync;

    int i;
    genvar j;

    logic[LATENCY + 1:0] expected_data_valid; 
    logic[DATA_WIDTH - 1:0] expected_data0_pipe[0:LATENCY];
    logic[DATA_WIDTH - 1:0] expected_data1_pipe[0:LATENCY + 1];

    ntt_swap#(
        .DATA_WIDTH(DATA_WIDTH),
        .LATENCY(LATENCY)
    )i_ntt_fsm(
        .clk(clk),
        .i_alu_inout_swap(i_alu_inout_swap),
        .i_data0(i_data0),
        .i_data1(i_data1),
        .o_data0(o_data0),
        .o_data1(o_data1)
    );

    task wait_clk;
        @(posedge clk);
        #0.1;
    endtask

    task eval;
        #0.1;
    endtask

    generate
        for(j = 1;j <= LATENCY;j++) begin
            always_ff @(posedge clk) begin
                expected_data0_pipe[j] <= expected_data0_pipe[j - 1];
            end
        end

        for(j = 1;j <= LATENCY + 1;j++) begin
            always_ff @(posedge clk) begin
                expected_data1_pipe[j] <= expected_data1_pipe[j - 1];
                expected_data_valid[j] <= expected_data_valid[j - 1];
            end
        end
    endgenerate

    task test_swap;
        for(i = 0;i < 100000;i++) begin
            i_data0 = $urandom_range(0, 2 ** DATA_WIDTH - 1);
            i_data1 = $urandom_range(0, 2 ** DATA_WIDTH - 1);
            /*i_data0 = i * 2;
            i_data1 = i * 2 + 1;*/
            expected_data_valid[0] = 1;
            expected_data0_pipe[0] = i_data0;
            expected_data1_pipe[0] = i_data1;
            //$display("i_data0 = %x, i_data1 = %x", i_data0, i_data1);
            wait_clk();
        end

        expected_data_valid[0] = 0;
        repeat(LATENCY + 1) wait_clk();
        wait(expected_data_valid[LATENCY + 1] === 'b0);
        test_swap_sync = 1;
    endtask

    task test_swap_generate;
        i_alu_inout_swap = 0;

        while(!test_swap_sync) begin
            wait_clk();
            i_alu_inout_swap = !i_alu_inout_swap;
        end
    endtask

    task test_swap_check;
        longint unsigned cnt = 0;

        while(!test_swap_sync) begin
            wait_clk();
            eval();//wait combinational logic propagation

            if(!cnt[0] && (expected_data_valid[LATENCY] === 'b1)) begin
                //$display("o_data0 = %x, o_data1 = %x", o_data0, o_data1);
                `assert_equal(cnt, expected_data0_pipe[LATENCY], o_data0)
                `assert_equal(cnt, expected_data0_pipe[LATENCY - 1], o_data1)
                cnt++;
            end
            else if(cnt[0] && (expected_data_valid[LATENCY + 1] === 'b1)) begin
                //$display("o_data0 = %x, o_data1 = %x", o_data0, o_data1);
                `assert_equal(cnt, expected_data1_pipe[LATENCY + 1], o_data0)
                `assert_equal(cnt, expected_data1_pipe[LATENCY], o_data1)
                cnt++;
            end
        end
    endtask

    task test_noswap;
        for(i = 0;i < 100000;i++) begin
            i_data0 = $urandom_range(0, 2 ** DATA_WIDTH - 1);
            i_data1 = $urandom_range(0, 2 ** DATA_WIDTH - 1);
            /*i_data0 = i * 2;
            i_data1 = i * 2 + 1;*/
            expected_data_valid[0] = 1;
            expected_data0_pipe[0] = i_data0;
            expected_data1_pipe[0] = i_data1;
            //$display("i_data0 = %x, i_data1 = %x", i_data0, i_data1);
        end

        expected_data_valid[0] = 0;
        repeat(LATENCY) wait_clk();
        wait(expected_data_valid[LATENCY] === 'b0);
        test_noswap_sync = 1;
    endtask

    task test_noswap_generate;
        i_alu_inout_swap = 0;
    endtask

    task test_noswap_check;
        longint unsigned cnt = 0;

        while(!test_noswap_sync) begin
            wait_clk();
            eval();//wait combinational logic propagation

            if(expected_data_valid[LATENCY] === 'b1) begin
                //$display("o_data0 = %x, o_data1 = %x", o_data0, o_data1);
                `assert_equal(cnt, expected_data0_pipe[LATENCY], o_data0)
                `assert_equal(cnt, expected_data1_pipe[LATENCY], o_data1)
                cnt++;
            end
        end
    endtask

    initial begin
        wait(display_sync == 1);

        begin
            test_swap_sync = 0;

            fork
                test_swap();
                test_swap_generate();
                test_swap_check();
            join
        end

        begin
            test_noswap_sync = 0;

            fork
                test_noswap();
                test_noswap_generate();
                test_noswap_check();
            join
        end

        #1000;

        if(assert_failed == 0) begin
            $display("TEST PASSED");
        end

        $finish;
    end

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
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