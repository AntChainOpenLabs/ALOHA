
//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: VP
// Module Name: modmul
// Modify Date:  
//
// Description:
//   Parameterized ModMul module of VP.
//   Modmul pipeline stages = mul_stage_p*3 + last_stage_p
//
//   Parameter     Description                               Recommended value
//   mul_level_p   Level num of 64-bit multiplier,                2
//                 set to 1 while using "*", can be 1/2/3
//
//   mul_stage_p   Pipeline stages of 64-bit multiplier,          1
//                 can be set according to mul_level_p
//
//   use_mul_ip_p  Use Xilinx Mul IP (multiplier v12),            0
//                 can be 0/1
//
//   last_stage_p  Last pipeline stages of Barrett Reduction,     1
//                 can be 1/2
//////////////////////////////////////////////////

module modmul #(
    parameter data_width_p = 64,
    parameter mul_level_p  = 2,
    parameter mul_stage_p  = 2,
    parameter last_stage_p = 2
) (
    input                               clk_i,
    input                               rst_n,
    input                               valid_i,
    input  [data_width_p-1:0]           opa_i,
    input  [data_width_p-1:0]           opb_i,
    input  [data_width_p-1:0]           mod_i,
    input  [data_width_p-1:0]           imod_i,
    input  [$clog2(data_width_p)-1:0]   mod_width,
    output                              valid_o,
    output [data_width_p-1:0]           res_o
);

    logic [last_stage_p-1:0] valid;
    logic [2:0] valid_mul;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (~rst_n) begin
            valid <= '0;
        end
        else begin
            valid[0] <= valid_mul[2];
            for (int i = last_stage_p-1; i > 0; i--) begin
                valid[i] <= valid[i-1];
            end
        end
    end

    // pipeline 1
    logic [data_width_p*2-1:0] prod;

    mul64 #(
        .data_width_p ( data_width_p  ),
        .mul_level_p  ( mul_level_p   ),
        .mul_stage_p  ( mul_stage_p   )
    ) mul0 (
        .clk_i   ( clk_i         ),
        .rst_n   ( rst_n         ),
        .valid_i ( valid_i       ),
        .opa_i   ( opa_i         ),
        .opb_i   ( opb_i         ),
        .valid_o ( valid_mul[0]  ),
        .res_o   ( prod          )
    );

    localparam prod_buffer_depth_p = mul_stage_p*2;
    logic [prod_buffer_depth_p-1:0][data_width_p*2-1:0] prod_buffer;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (~rst_n) begin
            for (int i = 0; i < prod_buffer_depth_p; i++) begin
                prod_buffer[i] <= '0;
            end
        end
        else begin
            if (valid_mul[0]) begin
                prod_buffer[0] <= prod;
            end
            for (int j = prod_buffer_depth_p-1; j > 0; j--) begin
                prod_buffer[j] <= prod_buffer[j-1];
            end
        end
    end

    localparam mod_buffer_depth_p  = mul_stage_p*3 + last_stage_p - 1;
    localparam imod_buffer_depth_p = mul_stage_p;

    logic [mod_buffer_depth_p-1:0][data_width_p-1:0] mod_buffer;
    logic [imod_buffer_depth_p-1:0][data_width_p-1:0] imod_buffer;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (~rst_n) begin
            for (int i = 0; i < mod_buffer_depth_p; i++) begin
                mod_buffer[i] <= '0;
            end
            for (int j = 0; j < imod_buffer_depth_p; j++) begin
                imod_buffer[j] <= '0;
            end
        end
        else begin
            if (valid_i) begin
                mod_buffer[0]  <= mod_i;
                imod_buffer[0] <= imod_i;
            end
            for (int i = mod_buffer_depth_p-1; i > 0; i--) begin
                mod_buffer[i]  <= mod_buffer[i-1];
            end
            for (int j = imod_buffer_depth_p-1; j > 0; j--) begin
                imod_buffer[j] <= imod_buffer[j-1];
            end
        end
    end

    localparam mod_width_depth_p = mul_stage_p*3;
    logic [$clog2(data_width_p)-1:0] mod_width_buffer [mod_width_depth_p-1:0];

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (~rst_n) begin
            for (int i = 0; i < mod_width_depth_p; i++) begin
                mod_width_buffer[i] <= '0;
            end
        end
        else begin
            if (valid_i) begin
                mod_width_buffer[0] <= mod_width;
            end
            for (int i = mod_width_depth_p-1; i > 0; i--) begin
                mod_width_buffer[i]  <= mod_width_buffer[i-1];
            end
        end
    end

    // pipeline 2
    logic [data_width_p-1:0] prod_shift;
    logic [2*data_width_p-1:0] mid;
    logic [data_width_p-1:0] mul1_opb;

    assign prod_shift = prod >> (mod_width_buffer[mul_stage_p-1]-2);
    assign mul1_opb   = imod_buffer[imod_buffer_depth_p-1];

    mul64 #(
        .data_width_p ( data_width_p  ),
        .mul_level_p  ( mul_level_p   ),
        .mul_stage_p  ( mul_stage_p   )
    ) mul1 (
        .clk_i   ( clk_i         ),
        .rst_n   ( rst_n         ),
        .valid_i ( valid_mul[0]  ),
        .opa_i   ( prod_shift    ),
        .opb_i   ( mul1_opb      ),
        .valid_o ( valid_mul[1]  ),
        .res_o   ( mid           )
    );

    // pipeline 3
    logic [data_width_p-1:0] mid_shift;
    logic [2*data_width_p-1:0] estim;
    logic [data_width_p-1:0] mul2_opb;

    assign mid_shift = mid >> (mod_width_buffer[mul_stage_p*2-1]+3);
    assign mul2_opb  = mod_buffer[mul_stage_p*2-1];

    mul64 #(
        .data_width_p ( data_width_p  ),
        .mul_level_p  ( mul_level_p   ),
        .mul_stage_p  ( mul_stage_p   )
    ) mul2 (
        .clk_i   ( clk_i         ),
        .rst_n   ( rst_n         ),
        .valid_i ( valid_mul[1]  ),
        .opa_i   ( mid_shift     ),
        .opb_i   ( mul2_opb      ),
        .valid_o ( valid_mul[2]  ),
        .res_o   ( estim         )
    );

    logic [data_width_p-1:0] diff;
    logic [data_width_p-1:0] diff_X;
    logic [data_width_p-1:0] diff_Y;
    logic last_valid;
    logic [data_width_p-1:0] mod_mask;

    assign mod_mask = 1<<(mod_width_buffer[mul_stage_p*3-1]+1);

if (last_stage_p == 2) begin: pipe4

    logic [data_width_p-1:0] mod_mask_r;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (~rst_n) begin
            last_valid <= '0;
        end
        else begin
            last_valid <= valid_mul[2];
        end
    end

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (~rst_n) begin
            diff_X <= '0;
            diff_Y <= '0;
        end
        else if (valid_mul[2]) begin
            diff_X <= prod_buffer[prod_buffer_depth_p-1] & (mod_mask - 1);
            diff_Y <= estim & (mod_mask - 1);
            mod_mask_r <= mod_mask;
        end
    end
    always_comb begin
            diff   = ((diff_X | mod_mask_r) - diff_Y) & (mod_mask_r - 1);
    end

end

else if (last_stage_p == 1) begin: no_pipe4
    assign diff_X = prod_buffer[prod_buffer_depth_p-1] & (mod_mask - 1);
    assign diff_Y = estim & (mod_mask - 1);
    assign diff   = ((diff_X | mod_mask) - diff_Y) & (mod_mask - 1);
    assign last_valid = valid_mul[2];
end

    // output pipeline
    logic [data_width_p-1:0] res_r, mod_comp;

    assign mod_comp = mod_buffer[mod_buffer_depth_p-1];
    assign valid_o  = valid[last_stage_p-1];
    assign res_o    = res_r;

    wire less_than_mod  = diff < mod_comp;
    wire [data_width_p-1:0] diff_sub_mod  = diff - mod_comp;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (~rst_n) begin
            res_r <= '0;
        end
        else if (last_valid) begin
            if (less_than_mod) res_r <= diff;
            else res_r <= diff_sub_mod;
        end
    end

endmodule
