
//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: VP
// Module Name: modalu_tb
// Modify Date: 
//
// Description:
//   Testbench of modalu, generates random operands with random opcodes.
//////////////////////////////////////////////////

virtual class AluFunc #(int data_width_p = 64);

    static function logic [data_width_p-1:0] modadd (
        input bit [data_width_p-1:0] opa,
        input bit [data_width_p-1:0] opb,
        input bit [data_width_p-1:0] mod
    );
        logic [data_width_p-1:0] res;
        res = ((opa % mod) + (opb % mod)) % mod;
        return res;
    endfunction

    static function logic [data_width_p-1:0] modsub (
        input bit [data_width_p-1:0] opa,
        input bit [data_width_p-1:0] opb,
        input bit [data_width_p-1:0] mod
    );
        logic [data_width_p-1:0] res;
        res = ((opa % mod) + mod - (opb % mod)) % mod;
        return res;
    endfunction

    static function logic [data_width_p-1:0] mod (
        input bit [data_width_p-1:0] opa,
        input bit [data_width_p-1:0] mod_i,
        input bit [data_width_p-1:0] imod_i
    );
        logic [data_width_p-1:0] opb, res;
        opb = data_width_p'(1);
        res = modmul(opa, opb, mod_i, imod_i);
        return res;
    endfunction

    static function logic [data_width_p-1:0] modmul (
        input bit [data_width_p-1:0] opa,
        input bit [data_width_p-1:0] opb,
        input bit [data_width_p-1:0] mod,
        input bit [data_width_p-1:0] imod
    );
        logic [data_width_p-1:0] res;
        res = ((2 * data_width_p)'(opa * opb)) % mod;
        return res;
    endfunction

    static function logic [data_width_p-1:0] modhalf (
        input bit [data_width_p-1:0] opa,
        input bit [data_width_p-1:0] mod
    );
        logic [data_width_p-1:0] res;
        logic [data_width_p-1:0] mux;

        mux = opa[0] ? (mod + 1) >> 1 : 'b0;
        res = mux + (opa >> 1);

        return res;
    endfunction

endclass

class ModAlu #(int data_width_p = 64);
    rand bit [data_width_p-1:0] opa;
    rand bit [data_width_p-1:0] opb;
    rand bit [data_width_p-1:0] ops;
    rand bit [data_width_p-1:0] mod;
    rand bit [data_width_p-1:0] imod;
    rand bit [4:0]              opcode;
    rand bit [$clog2(data_width_p)-1:0] mod_width;

    constraint val_range {
        opa [data_width_p-1] == 1'b0;
        opb [data_width_p-1] == 1'b0;
        ops [data_width_p-1] == 1'b0;
        mod inside {'d576460825317867521, 'd576460924102115329, 'd576462951330889729};
        opa < (1<<mod_width);
        opb < (1<<mod_width);
        ops < (1<<mod_width);
        mod_width == clz(mod);
        imod == cal_imod(mod, mod_width);
    }

    constraint op_range {
        opcode inside {
            5'b00000, // modmul.vv
            5'b00100, // modmul.vs
            5'b00001, // modadd.vv
            5'b00101, // modadd.vs
            5'b00010, // modsub.vv
            5'b00110, // modsub.vs
            5'b01010, // modsub.sv
            5'b00011, // mod
            5'b10101, // madd.vs
            5'b10110, // msub.vs
            5'b11010, // msub.sv
            5'b10000, // ct.vvs
            5'b10011, // gs.vvs
            5'b10001  // vvs
        };
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


    function logic [data_width_p-1:0] get_res0();
        logic [data_width_p-1:0] res0;

        case (opcode)
            5'b00000: res0 = AluFunc #(data_width_p)::modmul(opa, opb, mod, imod); // modmul.vv
            5'b00100: res0 = AluFunc #(data_width_p)::modmul(opa, ops, mod, imod); // modmul.vs
            5'b00001: res0 = AluFunc #(data_width_p)::modadd(opa, opb, mod);       // modadd.vv
            5'b00101: res0 = AluFunc #(data_width_p)::modadd(opa, ops, mod);       // modadd.vs
            5'b00010: res0 = AluFunc #(data_width_p)::modsub(opa, opb, mod);       // modsub.vv
            5'b00110: res0 = AluFunc #(data_width_p)::modsub(opa, ops, mod);       // modsub.vs
            5'b01010: res0 = AluFunc #(data_width_p)::modsub(ops, opa, mod);       // modsub.sv
            5'b00011: res0 = AluFunc #(data_width_p)::mod(opa, mod, imod);         // mod
            5'b10101: res0 = AluFunc #(data_width_p)::modadd(AluFunc #(data_width_p)::modmul(opa, opb, mod, imod), ops, mod); // madd.vs
            5'b10110: res0 = AluFunc #(data_width_p)::modsub(AluFunc #(data_width_p)::modmul(opa, opb, mod, imod), ops, mod); // msub.vs
            5'b11010: res0 = AluFunc #(data_width_p)::modsub(ops, AluFunc #(data_width_p)::modmul(opa, opb, mod, imod), mod); // msub.sv\
            5'b10000: res0 = AluFunc #(data_width_p)::modadd(opa, AluFunc #(data_width_p)::modmul(opb, ops, mod, imod), mod);
            5'b10011: res0 = AluFunc #(data_width_p)::modhalf(AluFunc #(data_width_p)::modadd(opa, opb, mod), mod); // gs.vvs
            5'b10001: res0 = AluFunc #(data_width_p)::modmul(AluFunc #(data_width_p)::modsub(opa, opb, mod), ops, mod, imod); // vvs
            default:  res0 = '0;
        endcase
        return res0;
    endfunction

    function logic [data_width_p-1:0] get_res1();
        logic [data_width_p-1:0] res1;
        case (opcode)
            5'b10000: res1 = AluFunc #(data_width_p)::modsub(opa, AluFunc #(data_width_p)::modmul(opb, ops, mod, imod), mod);
            5'b10011: res1 = AluFunc #(data_width_p)::modhalf(AluFunc #(data_width_p)::modmul(AluFunc #(data_width_p)::modsub(opa, opb, mod), ops, mod, imod), mod);
            default:  res1 = '0;
        endcase
        return res1;
    endfunction
endclass

function string get_opcode(input bit [4:0] opcode);
    string opstr;
    case (opcode)
        5'b00000: opstr = "modmul.vv"; // modmul.vv
        5'b00100: opstr = "modmul.vs"; // modmul.vs
        5'b00001: opstr = "modadd.vv"; // modadd.vv
        5'b00101: opstr = "modadd.vs"; // modadd.vs
        5'b00010: opstr = "modsub.vv"; // modsub.vv
        5'b00110: opstr = "modsub.vs"; // modsub.vs
        5'b01010: opstr = "modsub.sv"; // modsub.sv
        5'b00011: opstr = "mod";       // mod
        5'b10101: opstr = "madd.vs";   // madd.vs
        5'b10110: opstr = "msub.vs";   // msub.vs
        5'b11010: opstr = "msub.sv";   // msub.sv
        5'b10000: opstr = "ct.vvs";      // gs.u
        5'b10011: opstr = "gs.vvs";      // gs.v
        5'b10001: opstr = "vvs";
        default:  opstr = "invalid opcode";
    endcase

    return opstr;
endfunction

module modalu_tb;
    parameter data_width_p   = 64;
    parameter mul_level_p    = 2;
    parameter mul_stage_p    = 2;
    parameter last_stage_p   = 2;
    parameter modhalf_stage_p= 1;
    parameter output_stage_p = 1;
    parameter period_p       = 10;
    parameter test_num_p     = 1000000;

    logic                      clk_i;
    logic                      rst_n;
    logic                      valid_i;
    logic  [4:0]               opcode_i;
    logic  [data_width_p-1:0]  opa_i;
    logic  [data_width_p-1:0]  opb_i;
    logic  [data_width_p-1:0]  ops_i;
    logic  [data_width_p-1:0]  mod_i;
    logic  [data_width_p-1:0]  imod_i;
    logic  [$clog2(data_width_p)-1:0] mod_width;
    logic                      valid_o;
    logic  [data_width_p-1:0]  res0_o;
    logic  [data_width_p-1:0]  res1_o;
    logic  [31:0]              valid_num;
    logic  [31:0]              passed_num;
    logic  [31:0]              failed_num;

    ModAlu alubus = new;

    parameter pipe_stage_p = 3*mul_stage_p + last_stage_p + modhalf_stage_p + output_stage_p;

    logic [pipe_stage_p-1:0][data_width_p-1:0] real_res0_ds;
    logic [data_width_p-1:0] real_res0_d;
    wire  [data_width_p-1:0] val0 = real_res0_ds[pipe_stage_p-1];

    logic [pipe_stage_p-1:0][data_width_p-1:0] real_res1_ds;
    logic [data_width_p-1:0] real_res1_d;
    wire  [data_width_p-1:0] val1 = real_res1_ds[pipe_stage_p-1];

    logic [pipe_stage_p-1:0][4:0] opcode_ds;
    logic [4:0] opcode_d;
    wire  [4:0] opcode = opcode_ds[pipe_stage_p-1];

    logic [pipe_stage_p-1:0][data_width_p-1:0] opa_ds;
    logic [data_width_p-1:0] opa_d;
    wire  [data_width_p-1:0] opa = opa_ds[pipe_stage_p-1];

    logic [pipe_stage_p-1:0][4:0] opb_ds;
    logic [data_width_p-1:0] opb_d;
    wire  [data_width_p-1:0] opb = opb_ds[pipe_stage_p-1];

    logic [pipe_stage_p-1:0][data_width_p-1:0] ops_ds;
    logic [data_width_p-1:0] ops_d;
    wire  [data_width_p-1:0] ops = ops_ds[pipe_stage_p-1];

    logic [pipe_stage_p-1:0][data_width_p-1:0] mod_ds;
    logic [data_width_p-1:0] mod_d;
    wire  [data_width_p-1:0] mod = mod_ds[pipe_stage_p-1];

    logic [pipe_stage_p-1:0][data_width_p-1:0] imod_ds;
    logic [data_width_p-1:0] imod_d;
    wire  [data_width_p-1:0] imod = imod_ds[pipe_stage_p-1];

    logic [pipe_stage_p-1:0][$clog2(data_width_p)-1:0] mod_width_ds;
    logic [data_width_p-1:0] mod_width_d;
    wire  [data_width_p-1:0] mod_width_n = mod_width_ds[pipe_stage_p-1];

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
        $display("test modalu, configuration:");
        $display("mul64 level:       %5d", mul_level_p);
        $display("mul64 pipeline:    %5d", mul_stage_p);
        $display("modmul pipeline:   %5d", 3*mul_stage_p + last_stage_p);
        $display("modalu pipeline:   %5d", pipe_stage_p);
    end

    initial begin
        clk_i       = '0;
        rst_n       = '0;
        valid_i     = '0;
        opa_i       = '0;
        opb_i       = '0;
        ops_i       = '0;
        opcode_i    = '0;
        mod_i       = '0;
        imod_i      = '0;
        real_res0_d = '0;
        real_res1_d = '0;
        opcode_d    = '0;
        valid_num   = '0;
        #(period_p*5) rst_n = 1;

        for (int i = 0; i < test_num_p; i++) begin
            assert (alubus.randomize)
            else   $fatal(0, "randomize failed");
            @(posedge clk_i);
            if (i % 5 == 0) begin // invalid data every 5 cycles
                valid_i <= 1'b0;
            end
            else begin
                valid_i   <= 1'b1;
                valid_num <= valid_num + 1'b1;
            end
            opa_i      <= alubus.opa;
            opb_i      <= alubus.opb;
            ops_i      <= alubus.ops;
            opcode_i   <= alubus.opcode;
            mod_i      <= alubus.mod;
            imod_i     <= alubus.imod;
            mod_width <= alubus.mod_width;
            real_res0_d <= alubus.get_res0();
            real_res1_d <= alubus.get_res1();
            opcode_d   <= alubus.opcode;
            opa_d <= alubus.opa;
            opb_d <= alubus.opb;
            ops_d <= alubus.ops;
            mod_d <= alubus.mod;
            imod_d <= alubus.imod;
            mod_width_d <= alubus.mod_width;
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
                real_res0_ds[j] <= '0;
                real_res1_ds[j] <= '0;
                opcode_ds[j]   <= '0;
                opa_ds[j] <= '0;
                opb_ds[j] <= '0;
                ops_ds[j] <= '0;
                mod_ds[j] <= '0;
                imod_ds[j] <= '0;
                mod_width_ds[j] <= '0;
            end
        end
        else begin
            real_res0_ds[0] <= real_res0_d;
            real_res1_ds[0] <= real_res1_d;
            opcode_ds[0]   <= opcode_d;
            opa_ds[0] <= opa_d;
            opb_ds[0] <= opb_d;
            ops_ds[0] <= ops_d;
            mod_ds[0] <= mod_d;
            imod_ds[0] <= imod_d;
            mod_width_ds[0] <= mod_width_d;
            for (int j = pipe_stage_p-1; j > 0; j--) begin
                real_res0_ds[j] <= real_res0_ds[j-1];
                real_res1_ds[j] <= real_res1_ds[j-1];
                opcode_ds[j]   <= opcode_ds[j-1];
                opa_ds[j] <= opa_ds[j - 1];
                opb_ds[j] <= opb_ds[j - 1];
                ops_ds[j] <= ops_ds[j - 1];
                mod_ds[j] <= mod_ds[j - 1];
                imod_ds[j] <= imod_ds[j - 1];
                mod_width_ds[j] <= mod_width_ds[j - 1];
            end
        end
    end

    // check data
    always_ff @(posedge clk_i or negedge rst_n) begin
        if (~rst_n) begin
            failed_num <= '0;
            passed_num <= '0;
        end
        else if (valid_o) begin
            if (val0 === res0_o && val1 === res1_o) begin
                passed_num <= passed_num + 1'b1;
                // $display("check passed! opcode=%s, val0=%h, res0=%h", get_opcode(opcode), val0, res0_o);
            end
            else begin
                if (is_prime(mod)) begin
                    failed_num <= failed_num + 1'b1;
                    $error("\033[40;33m check failed! opa=%h, opb=%h, mod=%h, opcode=%s, val0=%h, res0_o=%h, val1=%h, res1_o=%h, time=%h \033[0m", opa, opb, mod, get_opcode(opcode), val0, res0_o, val1, res1_o, $time);
                end
                else begin
                    passed_num <= passed_num + 1'b1;
                    $display("check passed! opcode=%s, val0=%h, res0=%h, cause mod is not prime!", get_opcode(opcode), val0, res0_o);
                end
            end
        end
    end

    initial begin
        $fsdbDumpfile("modalu.fsdb");
        $fsdbDumpvars("+all");
    end

    always #(period_p/2) clk_i = ~clk_i;

    modalu #(
        .data_width_p ( data_width_p ),
        .mul_level_p  ( mul_level_p  ),
        .mul_stage_p  ( mul_stage_p  ),
        .last_stage_p ( last_stage_p ),
        .modhalf_stage_p (modhalf_stage_p)
    ) modalu_i ( .* );

endmodule

