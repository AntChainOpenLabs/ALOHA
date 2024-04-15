
//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: VP
// Module Name: modmul_tb
// Modify Date: 
//
// Description:
//   Testbench of modmul, generates random operands.
//////////////////////////////////////////////////
class ModMul #(int data_width_p = 64);
    rand bit [data_width_p-1:0] opa;
    rand bit [data_width_p-1:0] opb;
    rand bit [data_width_p-1:0] mod;
    rand bit [data_width_p-1:0] imod;
    rand bit [$clog2(data_width_p)-1:0] mod_width;

    constraint val_range {
        mod_width == clz(mod);
        opa [data_width_p-1] == 1'b0;
        opb [data_width_p-1] == 1'b0;
        mod inside {'d576460825317867521, 'd576460924102115329, 'd576462951330889729};
        opa < (1<<mod_width);
        opb < (1<<mod_width);
        mod_width == clz(mod);
        imod == cal_imod(mod, mod_width);
    }

    function logic[data_width_p-1:0] cal_imod(input logic[data_width_p-1:0] mod, input [$clog2(data_width_p)-1:0] mod_width);
        logic [2*data_width_p-1:0] pow;
        logic [data_width_p-1:0] imod;
        pow = (1<<(2*mod_width+1));
        imod = pow / mod;
        return imod;
    endfunction

    // count leading zeros
    function logic [$clog2(data_width_p)-1:0] clz(input logic[data_width_p-1:0] N);
        logic [$clog2(data_width_p)-1:0] pos;
        pos = '0;
        while (N) begin
            N = N >> 1;
            pos++;
        end
        return pos;
    endfunction

    function logic [data_width_p-1:0] get_modmul();
        logic [data_width_p-1:0] res;
        res = ((2 * data_width_p)'(opa * opb)) % mod;
        return res;
    endfunction
endclass

module modmul_tb;
    parameter data_width_p   = 64;
    parameter mul_level_p    = 2;
    parameter mul_stage_p    = 2;
    parameter last_stage_p   = 2;

    parameter period_p       = 10;
    parameter test_num_p     = 1000000;

    logic                      clk_i;
    logic                      rst_n;
    logic                      valid_i;
    logic  [data_width_p-1:0]  opa_i;
    logic  [data_width_p-1:0]  opb_i;
    logic  [data_width_p-1:0]  mod_i;
    logic  [data_width_p-1:0]  imod_i;
    logic                      valid_o;
    logic  [data_width_p-1:0]  res_o;
    logic  [$clog2(data_width_p)-1:0]   mod_width;
    logic  [31:0]              valid_num;
    logic  [31:0]              passed_num;
    logic  [31:0]              failed_num;

    ModMul mulbus = new;

    parameter pipe_stage_p = 3*mul_stage_p + last_stage_p;

    logic [pipe_stage_p-1:0][data_width_p-1:0] real_res_ds;
    logic [data_width_p-1:0] real_res_d;
    wire  [data_width_p-1:0] val = real_res_ds[pipe_stage_p-1];

    logic [pipe_stage_p-1:0][data_width_p-1:0] opa_ds;
    logic [data_width_p-1:0] opa_d;
    wire  [data_width_p-1:0] opa = opa_ds[pipe_stage_p-1];

    logic [pipe_stage_p-1:0][4:0] opb_ds;
    logic [data_width_p-1:0] opb_d;
    wire  [data_width_p-1:0] opb = opb_ds[pipe_stage_p-1];

    logic [pipe_stage_p-1:0][data_width_p-1:0] mod_ds;
    logic [data_width_p-1:0] mod_d;
    wire  [data_width_p-1:0] mod = mod_ds[pipe_stage_p-1];

    function is_prime(input [data_width_p-1:0] num);
        if (num % 6 != 1 && num % 6 != 5) begin
            return 1'b0;
        end
        for (int i = 5; i <= $sqrt(real'(num)); i+=6) begin
            if (num % i == 0 || num % (i+2) == 0) begin
                return 1'b0;
            end
        end
        return 1'b1;
    endfunction


    initial begin
        $display("test modmul, configuration:");
        $display("mul64 level:       %5d", mul_level_p);
        $display("mul64 pipeline:    %5d", mul_stage_p);
        $display("modmul pipeline:   %5d", pipe_stage_p);
    end

    initial begin
        clk_i      = '0;
        rst_n      = '0;
        valid_i    = '0;
        opa_i      = '0;
        opb_i      = '0;
        mod_i      = '0;
        imod_i     = '0;
        real_res_d = '0;
        valid_num  = '0;
        #(period_p*5) rst_n = 1;

        for (int i = 0; i < test_num_p; i++) begin
            assert (mulbus.randomize)
            else   $fatal("randomize failed");
            @(posedge clk_i);
            if (i % 5 == 0) begin // invalid data every 5 cycles
                valid_i <= 1'b0;
            end
            else begin
                valid_i   <= 1'b1;
                valid_num <= valid_num + 1'b1;
            end
            opa_i  <= mulbus.opa;
            opb_i  <= mulbus.opb;
            mod_i  <= mulbus.mod;
            imod_i <= mulbus.imod;
            mod_width <= mulbus.mod_width;
            real_res_d <= mulbus.get_modmul();
            opa_d <= mulbus.opa;
            opb_d <= mulbus.opb;
            mod_d <= mulbus.mod;

        end

        @(posedge clk_i);
        valid_i <= 1'b0;

        #(period_p*40)
        if (failed_num === '0) $display("*****valid num: %5d, passed num: %5d*****", valid_num, passed_num);
        else $display("*****valid num: %5d, failed num: %5d*****", valid_num, failed_num);
        $finish;
    end

    // pipeline stages
    always_ff @(posedge clk_i or negedge rst_n) begin
        if (~rst_n) begin
            for (int j = 0; j < pipe_stage_p; j++) begin
                real_res_ds[j] <= '0;
                opa_ds[j] <= '0;
                opb_ds[j] <= '0;
                mod_ds[j] <= '0;
            end
        end
        else begin
            real_res_ds[0] <= real_res_d;
            opa_ds[0] <= opa_d;
            opb_ds[0] <= opb_d;
            mod_ds[0] <= mod_d;
            for (int j = pipe_stage_p-1; j > 0; j--) begin
                real_res_ds[j] <= real_res_ds[j-1];
                opa_ds[j] <= opa_ds[j - 1];
                opb_ds[j] <= opb_ds[j - 1];
                mod_ds[j] <= mod_ds[j - 1];
            end
        end
    end

// initial begin
//     $fsdbDumpfile("modmul.fsdb");
//     $fsdbDumpvars("+all");
// end

    // check data
    always_ff @(posedge clk_i or negedge rst_n) begin
        if (~rst_n) begin
            failed_num <= '0;
            passed_num <= '0;
        end
        else if (valid_o) begin
            if (val === res_o) begin
                passed_num <= passed_num + 1'b1;
                // $display("check pass! opa=%h, opb=%h, mod=%h, val=%h, res_o=%h, delta=%h, time=%h", opa, opb, mod, val, res_o, val-res_o, $time);
            end
            else begin
                if (is_prime(mod)) begin
                    $error("\033[40;33m check failed! val=%h, res_o=%h, mod=%h, delta=%h, time=%h \033[0m", val, res_o, mod, val-res_o, $time);
                    failed_num <= failed_num + 1'b1;
                end
                else begin
                    $display("check passed! val0=%h, res0=%h, cause mod is not prime!", val, res_o);
                    passed_num <= passed_num + 1'b1;
                end
            end
        end
    end

    always #(period_p/2) clk_i = ~clk_i;

    modmul #(
        .data_width_p ( data_width_p ),
        .mul_level_p  ( mul_level_p  ),
        .mul_stage_p  ( mul_stage_p  ),
        .last_stage_p ( last_stage_p )
    ) modmul_i ( .* );

endmodule
