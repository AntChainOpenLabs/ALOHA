module modalu #(
    parameter data_width_p = 64,
    parameter mul_level_p  = 2,
    parameter mul_stage_p  = 2,
    parameter last_stage_p = 2,
    parameter modhalf_stage_p = 1
) (
    input                      clk_i,
    input                      rst_n,
    input                      valid_i,
    input  [4:0]               opcode_i,
    input  [data_width_p-1:0]  opa_i,
    input  [data_width_p-1:0]  opb_i,
    input  [data_width_p-1:0]  ops_i,
    input  [data_width_p-1:0]  mod_i,
    input  [data_width_p-1:0]  imod_i,
    input  [$clog2(data_width_p)-1:0]   mod_width,
    output                     valid_o,
    output [data_width_p-1:0]  res0_o,
    output [data_width_p-1:0]  res1_o
);
    typedef enum logic [4:0] {
        MODMUL_VV = 5'b00000,
        MODMUL_VS = 5'b00100,
        MODADD_VV = 5'b00001,
        MODADD_VS = 5'b00101,
        MODSUB_VV = 5'b00010,
        MODSUB_VS = 5'b00110,
        MODSUB_SV = 5'b01010,
        MOD       = 5'b00011,
        MADD_VS   = 5'b10101,
        MSUB_VS   = 5'b10110,
        MSUB_SV   = 5'b11010,
        CT_VVS    = 5'b10000,
        GS_VVS    = 5'b10011,
        VVS       = 5'b10001
     } OPCODE;

    // input operand
    logic [data_width_p-1:0] opa;
    logic [data_width_p-1:0] opb;
    logic [data_width_p-1:0] ops;

    assign opa = opa_i >= mod_i ? opa_i - mod_i : opa_i;
    assign opb = opb_i >= mod_i ? opb_i - mod_i : opb_i;
    assign ops = ops_i >= mod_i ? ops_i - mod_i : ops_i;

    localparam valid_stage_p = mul_stage_p*3 + last_stage_p + modhalf_stage_p;
    logic [valid_stage_p-1:0] valid;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (~rst_n) begin
            valid <= '0;
        end
        else begin
            valid[0] <= valid_i;
            for (int i = valid_stage_p-1; i > 0; i--) begin
                valid[i] <= valid[i-1];
            end
        end
    end

    localparam opcode_stage_p = valid_stage_p;
    logic [opcode_stage_p-1:0][4:0] opcode_buffer;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (~rst_n) begin
            opcode_buffer <= '0;
        end
        else begin
            if (valid_i) begin
                opcode_buffer[0] <= opcode_i;
            end
            for (int i = opcode_stage_p-1; i > 0; i--) begin
                opcode_buffer[i] <= opcode_buffer[i-1];
            end
        end
    end

    localparam scalar_stage_p = valid_stage_p;
    logic [scalar_stage_p-1:0][data_width_p-1:0] scalar_buffer;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (~rst_n) begin
            scalar_buffer <= '0;
        end
        else begin
            if (valid_i) begin
                scalar_buffer[0] <= ops;
            end
            for (int i = scalar_stage_p-1; i > 0; i--) begin
                scalar_buffer[i] <= scalar_buffer[i-1];
            end
        end
    end

    localparam mod_buffer_depth_p  = valid_stage_p;

    logic [mod_buffer_depth_p-1:0][data_width_p-1:0] mod_buffer;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (~rst_n) begin
            mod_buffer  <= '0;
        end
        else begin
            if (valid_i) begin
                mod_buffer[0]  <= mod_i;
            end
            for (int i = mod_buffer_depth_p-1; i > 0; i--) begin
                mod_buffer[i]  <= mod_buffer[i-1];
            end
        end
    end

    localparam opab_buffer_depth_p = mul_stage_p*3 + last_stage_p;
    logic [opab_buffer_depth_p-1:0][data_width_p-1:0] opa_buffer;
    logic [opab_buffer_depth_p-1:0][data_width_p-1:0] opb_buffer;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (~rst_n) begin
            opa_buffer <= '0;
            opb_buffer <= '0;
        end
        else begin
            if (valid_i) begin
                if (opcode_i == MODADD_VV ||
                    opcode_i == MODADD_VS ||
                    opcode_i == MODSUB_VV ||
                    opcode_i == MODSUB_VS ||
                    opcode_i == MODSUB_SV ||
                    opcode_i == MADD_VS   ||
                    opcode_i == MSUB_VS   ||
                    opcode_i == MSUB_SV   ||
                    opcode_i == CT_VVS    ||
                    opcode_i == GS_VVS    ||
                    opcode_i == VVS         ) begin
                    // bypass modmul pipeline
                    opa_buffer[0] <= opa;
                    opb_buffer[0] <= opb;
                end
            end
            for (int i = opab_buffer_depth_p-1; i > 0; i--) begin
                opa_buffer[i] <= opa_buffer[i-1];
                opb_buffer[i] <= opb_buffer[i-1];
            end
        end
    end

    // gs butterfly
    // opa - opb
    logic [data_width_p-1:0] gs_subred;
    assign gs_subred = (opa >= opb) ? (opa - opb) : (mod_i + opa - opb);

    // modmul pipeline
    logic  [data_width_p-1:0] mul_opa, mul_opb;
    logic  mul_valid;
    logic  modmul_valid;
    logic  [data_width_p-1:0] modmul_res;

    assign mul_opa = (opcode_i == GS_VVS || opcode_i == VVS) ? gs_subred :
                     (opcode_i == CT_VVS) ? opb:
                     opa;
    assign mul_opb = (opcode_i == MODMUL_VS || opcode_i == CT_VVS || opcode_i == GS_VVS || opcode_i == VVS) ? ops :
                     (opcode_i == MOD) ? data_width_p'(1) :
                     opb;

    assign mul_valid = valid_i & (opcode_i == MADD_VS   ||
                                  opcode_i == MSUB_VS   ||
                                  opcode_i == MSUB_SV   ||
                                  opcode_i == CT_VVS    ||
                                  opcode_i == GS_VVS    ||
                                  opcode_i == VVS       ||
                                  opcode_i == MODMUL_VS ||
                                  opcode_i == MODMUL_VV ||
                                  opcode_i == MOD       );

    modmul #(
        .data_width_p (data_width_p),
        .mul_level_p  (mul_level_p),
        .mul_stage_p  (mul_stage_p),
        .last_stage_p (last_stage_p)
    ) u_mul (
        .clk_i      (clk_i),
        .rst_n      (rst_n),
        .valid_i    (mul_valid),
        .opa_i      (mul_opa),
        .opb_i      (mul_opb),
        .mod_i      (mod_i),
        .imod_i     (imod_i),
        .mod_width  (mod_width),
        .valid_o    (modmul_valid),
        .res_o      (modmul_res)
    );

    // modadd/sub pipeline
    // modadd.vv	00001	opa + opb
    // modadd.vs	00101	opa + ops
    // modsub.vv	00010	opa - opb
    // modsub.vs	00110	opa - ops
    // modsub.sv	01010	ops - opa
    // madd.vs	    10101	opa * opb + ops
    // msub.vs	    10110	opa * opb - ops
    // msub.sv	    11010	ops - opa * opb
    // ct.vvs       10000   opa + opb * ops /// opa - opb * ops
    // gs.vvs       10011   (opa + opb)/2 /// (opa - opb) * ops/2
    logic  [4:0] addsub_opcode;
    logic  add_valid, sub_valid;
    logic  [data_width_p-1:0] addsub_mod;
    logic  [data_width_p-1:0] add_opa, add_opb, add_res;
    logic  [data_width_p:0]   add_sum;
    logic  [data_width_p-1:0] sub_opa, sub_opb, sub_res;
    logic  [data_width_p-1:0] addsub_res;

    assign addsub_mod    = mod_buffer[mul_stage_p*3 + last_stage_p - 1];
    assign addsub_opcode = opcode_buffer[mul_stage_p*3 + last_stage_p - 1];

    assign add_valid = valid[mul_stage_p*3 + last_stage_p - 1] & (addsub_opcode == MODADD_VS ||
                                                                  addsub_opcode == MODADD_VV ||
                                                                  addsub_opcode == MADD_VS   ||
                                                                  addsub_opcode == CT_VVS    ||
                                                                  addsub_opcode == GS_VVS    );

    assign add_opa = (addsub_opcode == MADD_VS) ? modmul_res : opa_buffer[opab_buffer_depth_p-1];
    assign add_opb = (addsub_opcode == MADD_VS || addsub_opcode == MODADD_VS) ? scalar_buffer[mul_stage_p*3+last_stage_p-1] :
                     (addsub_opcode == CT_VVS) ? modmul_res :
                     opb_buffer[opab_buffer_depth_p-1];

    assign add_sum = add_opa + add_opb;
    assign add_res = add_valid ? (add_sum >= addsub_mod) ? add_sum - addsub_mod : add_sum : data_width_p'(0);

    assign sub_valid = valid[mul_stage_p*3 + last_stage_p - 1] & (addsub_opcode == MODSUB_SV ||
                                                                  addsub_opcode == MODSUB_VS ||
                                                                  addsub_opcode == MODSUB_VV ||
                                                                  addsub_opcode == MSUB_SV   ||
                                                                  addsub_opcode == MSUB_VS   ||
                                                                  addsub_opcode == CT_VVS    );

    assign sub_opa = (addsub_opcode == MODSUB_VS ||
                      addsub_opcode == MODSUB_VV ||
                      addsub_opcode == CT_VVS    ) ? opa_buffer[opab_buffer_depth_p-1] :
                     (addsub_opcode == MSUB_VS   ) ? modmul_res :
                     scalar_buffer[mul_stage_p*3+last_stage_p-1];
    assign sub_opb = (addsub_opcode == MSUB_SV   ||
                      addsub_opcode == CT_VVS) ? modmul_res :
                     (addsub_opcode == MODSUB_VV) ? opb_buffer[opab_buffer_depth_p-1] :
                     (addsub_opcode == MODSUB_SV ) ? opa_buffer[opab_buffer_depth_p-1] :
                     scalar_buffer[mul_stage_p*3+last_stage_p-1];

    assign sub_res = sub_valid ? (sub_opa >= sub_opb) ? (sub_opa - sub_opb) : (addsub_mod + sub_opa - sub_opb) : data_width_p'(0);

    generate
        logic  [data_width_p-1:0] add_res_n;
        logic  [data_width_p-1:0] sub_res_n;
        logic  [data_width_p-1:0] modmul_res_n;
        logic  modhalf_valid;
        logic  [4:0] modhalf_opcode;
        logic  [data_width_p-1:0] modhalf_mod;
        logic  [data_width_p-1:0] modhalf_op0;
        logic  [data_width_p-1:0] modhalf_op1;
        logic  [data_width_p-1:0] modhalf_res0;
        logic  [data_width_p-1:0] modhalf_res1;
        logic  ntt_valid;

        assign ntt_valid = modhalf_opcode == CT_VVS || modhalf_opcode == GS_VVS;

        if (modhalf_stage_p == 0) begin
            // modhalf pipeline
            assign modhalf_mod    = addsub_mod;
            assign modhalf_opcode = addsub_opcode;
            assign modhalf_valid  = modhalf_opcode == GS_VVS;

            assign modhalf_op0 = add_res;
            assign modhalf_op1 = modmul_res;

            halfred #(
                .data_width_p (data_width_p)
            ) u_halfred0 (
                .a_i        (modhalf_op0),
                .mod_i      (modhalf_mod),
                .halfred_o  (modhalf_res0)
            );

            halfred #(
                .data_width_p (data_width_p)
            ) u_halfred1 (
                .a_i        (modhalf_op1),
                .mod_i      (modhalf_mod),
                .halfred_o  (modhalf_res1)
            );

            assign add_res_n = add_res;
            assign sub_res_n = sub_res;
            assign modmul_res_n = modmul_res;
        end

        if (modhalf_stage_p == 1) begin
            always_ff @(posedge clk_i) begin
                modhalf_op0 <= add_res;
                modhalf_op1 <= modmul_res;
                modhalf_mod <= addsub_mod;
                modhalf_opcode <= addsub_opcode;
            end

            assign modhalf_valid  = modhalf_opcode == GS_VVS;

            halfred #(
                .data_width_p (data_width_p)
            ) u_halfred0 (
                .a_i        (modhalf_op0),
                .mod_i      (modhalf_mod),
                .halfred_o  (modhalf_res0)
            );

            halfred #(
                .data_width_p (data_width_p)
            ) u_halfred1 (
                .a_i        (modhalf_op1),
                .mod_i      (modhalf_mod),
                .halfred_o  (modhalf_res1)
            );

            always_ff @(posedge clk_i) begin
                add_res_n <= add_res;
                sub_res_n <= sub_res;
                modmul_res_n <= modmul_res;
            end
        end
    endgenerate

    // output mux pipeline
    logic  [4:0]  output_opcode;
    always_ff @(posedge clk_i) begin
        output_opcode <= modhalf_opcode;
    end

    logic  valid_r;
    logic  [data_width_p-1:0] res0_r;
    logic  [data_width_p-1:0] modmul_res_r;
    logic  [data_width_p-1:0] add_res_r;
    logic  [data_width_p-1:0] sub_res_r;
    logic  [data_width_p-1:0] modhalf_res0_r;
    logic  [data_width_p-1:0] res1_r;

    always_ff @(posedge clk_i) begin
        modmul_res_r <= modmul_res_n;
        add_res_r <= add_res_n;
        sub_res_r <= sub_res_n;
        modhalf_res0_r <= modhalf_res0;
    end

    always_comb begin
        case (output_opcode) inside
            MOD,
            MODMUL_VS,
            MODMUL_VV,
            VVS      : res0_r = modmul_res_r;
            MODADD_VS,
            MODADD_VV,
            MADD_VS,
            CT_VVS   : res0_r = add_res_r;
            MODSUB_VV,
            MODSUB_VS,
            MODSUB_SV,
            MSUB_SV,
            MSUB_VS  : res0_r = sub_res_r;
            GS_VVS   : res0_r = modhalf_res0_r;
            default  : begin
                res0_r = '0;
            end
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (~rst_n) begin
            res1_r   <= '0;
        end else begin
            res1_r <= ntt_valid ? modhalf_valid ? modhalf_res1 : sub_res_n : data_width_p'(0);
        end
    end

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (~rst_n) begin
            valid_r <= '0;
        end else begin
            valid_r <= valid[valid_stage_p - 1];
        end
    end

    assign res0_o = res0_r;
    assign res1_o = res1_r;
    assign valid_o = valid_r;


endmodule