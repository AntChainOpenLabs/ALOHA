
// //////////////////////////////////////////////////
// Engineer: Xin Fan (daxin)
// Email: 
//
// Project Name: VP
// Module Name: mul64
// Modify Date: 
//
// Description:
//   64-bit multiplier.
//
//   Parameter     Description                            Recommended value
//   mul_level_p   Level num of 64-bit multiplier,           2
//                 set to 1 while using "*", can be 1/2/3
//
//   mul_stage_p   Pipeline stages of 64-bit multiplier,     2
//                 can be set according to mul_level_p
// //////////////////////////////////////////////////

module mul64 #(
    parameter data_width_p = 64,
    parameter mul_level_p  = 2,
    parameter mul_stage_p  = 2
) (
    input                       clk_i,
    input                       rst_n,
    input                       valid_i,
    input  [data_width_p-1:0]   opa_i,
    input  [data_width_p-1:0]   opb_i,
    output                      valid_o,
    output [data_width_p*2-1:0] res_o
);
    localparam pipe_stage_p = mul_stage_p;
    logic [pipe_stage_p-1:0] valid;
    always_ff @(posedge clk_i or negedge rst_n) begin
        if (~rst_n) begin
            valid <= '0;
        end
        else begin
            valid[0] <= valid_i;
            for (int i = pipe_stage_p-1; i > 0; i--) begin
                valid[i] <= valid[i-1];
            end
        end
    end
    logic [data_width_p*2-1:0] res_r;
    assign res_o = res_r;
    assign valid_o = valid[pipe_stage_p-1];

    generate
        if (mul_level_p == 1 & mul_stage_p == 1) begin : classical_mul
            always_ff @(posedge clk_i or negedge rst_n) begin
                if (~rst_n) begin
                    res_r <= '0;
                end
                else if (valid_i) begin
                    (* use_dsp = "yes" *) res_r <= opa_i * opb_i;
                end
            end
        end // classical_mul

        if (mul_level_p == 1 & mul_stage_p == 2) begin
            logic [data_width_p*2-1:0] res_mid;
            always_ff @(posedge clk_i or negedge rst_n) begin
                if (~rst_n) begin
                    res_mid <= '0;
                    res_r   <= '0;
                end
                else if (valid_i) begin
                    (* use_dsp = "yes" *) res_mid <= opa_i * opb_i;
                    res_r                         <= res_mid;
                end
            end
        end

        if (mul_level_p == 2 & mul_stage_p == 1) begin 
            logic [22:0]                    a_0;
            logic [45:23]                   a_1;
            logic [data_width_p-1-45:46]    a_2;
            logic [22:0]                    b_0;
            logic [45:23]                   b_1;
            logic [data_width_p-1-45:46]    b_2;

            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_0;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_1;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_2;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_3;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_4;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_5;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_6;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_7;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_8;

            always_comb begin
                a_0 = opa_i[22:0];
                a_1 = opa_i[45:23];
                a_2 = opa_i[data_width_p-1:46];

                b_0 = opb_i[22:0];
                b_1 = opb_i[45:23];
                b_2 = opb_i[data_width_p-1:46];
            end

            always_ff @(posedge clk_i) begin
                dsp_0 <= a_0 * b_0;
                dsp_1 <= a_0 * b_1;
                dsp_2 <= a_0 * b_2;
                dsp_3 <= a_1 * b_0;
                dsp_4 <= a_1 * b_1;
                dsp_5 <= a_1 * b_2;
                dsp_6 <= a_2 * b_0;
                dsp_7 <= a_2 * b_1;
                dsp_8 <= a_2 * b_2;
            end

            assign res_r = dsp_0 + (dsp_1 << 23) + (dsp_3 << 23) + (dsp_2 << 46) + (dsp_4 << 46) + (dsp_6 << 46) + (dsp_5 << 69) + (dsp_7 << 69) + (dsp_8 << 92);

        end

        if (mul_level_p == 2 & mul_stage_p == 2) begin 
            logic [22:0]                    a_0;
            logic [45:23]                   a_1;
            logic [data_width_p-1-45:46]    a_2;
            logic [22:0]                    b_0;
            logic [45:23]                   b_1;
            logic [data_width_p-1-45:46]    b_2;

            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_0;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_1;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_2;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_3;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_4;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_5;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_6;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_7;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_8;

            always_comb begin
                a_0 = opa_i[22:0];
                a_1 = opa_i[45:23];
                a_2 = opa_i[data_width_p-1:46];

                b_0 = opb_i[22:0];
                b_1 = opb_i[45:23];
                b_2 = opb_i[data_width_p-1:46];
            end

            always_ff @(posedge clk_i) begin
                // pip1: DSP
                dsp_0 <= a_0 * b_0;
                dsp_1 <= a_0 * b_1;
                dsp_2 <= a_0 * b_2;
                dsp_3 <= a_1 * b_0;
                dsp_4 <= a_1 * b_1;
                dsp_5 <= a_1 * b_2;
                dsp_6 <= a_2 * b_0;
                dsp_7 <= a_2 * b_1;
                dsp_8 <= a_2 * b_2;

                // pip2: addr tree
                res_r <= dsp_0 + (dsp_1 << 23) + (dsp_3 << 23) + (dsp_2 << 46) + (dsp_4 << 46) + (dsp_6 << 46) + (dsp_5 << 69) + (dsp_7 << 69) + (dsp_8 << 92);
            end
        end

        if (mul_level_p == 3 & mul_stage_p == 2) begin // split mul + karatsuba
            logic [21:0]                    a_0;
            logic [43:22]                   a_1;
            logic [data_width_p-1-43:44]    a_2;
            logic [21:0]                    b_0;
            logic [43:22]                   b_1;
            logic [data_width_p-1-43:44]    b_2;

            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_0;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_1;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_2;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_3;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_4;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_5;

            always_comb begin
                a_0 = opa_i[21:0];
                a_1 = opa_i[43:22];
                a_2 = opa_i[data_width_p-1:44];

                b_0 = opb_i[21:0];
                b_1 = opb_i[43:22];
                b_2 = opb_i[data_width_p-1:44];
            end

            always_ff @(posedge clk_i) begin
                // pip1
                dsp_0 <= a_0 * b_0;
                dsp_1 <= a_1 * b_1;
                dsp_2 <= a_2 * b_2;
                dsp_3 <= (a_0 + a_1) * (b_0 + b_1);
                dsp_4 <= (a_0 + a_2) * (b_0 + b_2);
                dsp_5 <= (a_1 + a_2) * (b_1 + b_2);

                // pip2
                res_r <= dsp_0 + ((dsp_3 - dsp_0 - dsp_1) << 22) + ((dsp_4 - dsp_0 - dsp_2 + dsp_1) << 44) + ((dsp_5 - dsp_1 - dsp_2) << 66) + (dsp_2 << 88);
            end

        end

        if (mul_level_p == 3 & mul_stage_p == 3) begin // split mul + karatsuba
            logic [21:0]                    a_0;
            logic [43:22]                   a_1;
            logic [data_width_p-1-43:44]    a_2;
            logic [21:0]                    b_0;
            logic [43:22]                   b_1;
            logic [data_width_p-1-43:44]    b_2;

            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_0;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_1;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_2;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_3;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_4;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_5;
                                  logic [2*data_width_p-1:0]    mid_0;
                                  logic [2*data_width_p-1:0]    mid_1;
                                  logic [2*data_width_p-1:0]    mid_2;
                                  logic [2*data_width_p-1:0]    mid_3;
                                  logic [2*data_width_p-1:0]    mid_4;
                                 
            always_comb begin
                a_0 = opa_i[21:0];
                a_1 = opa_i[43:22];
                a_2 = opa_i[data_width_p-1:44];

                b_0 = opb_i[21:0];
                b_1 = opb_i[43:22];
                b_2 = opb_i[data_width_p-1:44];
            end

            always_ff @(posedge clk_i) begin
                // pip1
                dsp_0 <= a_0 * b_0;
                dsp_1 <= a_1 * b_1;
                dsp_2 <= a_2 * b_2;
                dsp_3 <= (a_0 + a_1) * (b_0 + b_1);
                dsp_4 <= (a_0 + a_2) * (b_0 + b_2);
                dsp_5 <= (a_1 + a_2) * (b_1 + b_2);

                // pip2
                mid_0 <= dsp_0;
                mid_1 <= dsp_3 - dsp_0 - dsp_1;
                mid_2 <= dsp_4 - dsp_0 - dsp_2 + dsp_1;
                mid_3 <= dsp_5 - dsp_1 - dsp_2;
                mid_4 <= dsp_2;

                // pip3
                res_r <= mid_0 + (mid_1 << 22) + (mid_2 << 44) + (mid_3 << 66) + (mid_4 << 88);
            end
        end

        if (mul_level_p == 4 & mul_stage_p == 2) begin 
            logic [22:0]                    a_0;
            logic [45:23]                   a_1;
            logic [data_width_p-1-45:46]    a_2;
            logic [22:0]                    b_0;
            logic [45:23]                   b_1;
            logic [data_width_p-1-45:46]    b_2;

            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_0;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_1;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_2;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_3;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_4;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_5;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_6;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_7;
            (* use_dsp = "yes" *) logic [2*data_width_p-1:0]    dsp_8;


            always_comb begin
                a_0 = opa_i[22:0];
                a_1 = opa_i[45:23];
                a_2 = opa_i[data_width_p-1:46];

                b_0 = opb_i[22:0];
                b_1 = opb_i[45:23];
                b_2 = opb_i[data_width_p-1:46];
            end

            always_comb begin
                dsp_1   = a_0 * b_1;
                dsp_2   = a_0 * b_2;
                dsp_3   = a_1 * b_1;
            end

            always_ff @(posedge clk_i) begin
                dsp_0   <= a_0 * b_0;
                dsp_4   <= a_1 * b_2;
                dsp_5   <= a_2 * b_1;
                dsp_6   <= a_1 * b_0 + dsp_1;
                dsp_7   <= a_2 * b_0 + dsp_2 + dsp_3;
                dsp_8   <= a_2 * b_2;

                // pip2
                res_r   <= dsp_0 + (dsp_6 << 23) + (dsp_7 << 46) + ((dsp_4 + dsp_5) << 69) + (dsp_8 << 92);
            end
        end

    endgenerate
endmodule