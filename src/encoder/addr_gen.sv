//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: ENCODER
// Module Name: addr_gen
// Modify Date: 
//
// Description:
// rearrange function
//////////////////////////////////////////////////
module ecd_addr_gen #(
    parameter ADDR_WIDTH = 12, //$clog2(ST1)
    parameter POLY_POWER = 8192,
    parameter ROTATE_BASE = 3
) (
    input                         clk,
    input                         rst_n,

    input                         rarg_vld,
    input  logic                  rarg_rdy,
    input  logic [ADDR_WIDTH-1:0] org_addr,
    output logic [ADDR_WIDTH-1:0] rarg_addr,
    output logic                  b_im,

    output logic                  addr_gen_vld
);
    localparam POWER_WIDTH = $clog2(POLY_POWER);
    logic [POWER_WIDTH:0] permute_pow_r;
    logic [POWER_WIDTH-1:0] tmp_idx;
    logic flag; // seq > 4095
    logic rarg_shaked;

    assign rarg_shaked = rarg_vld & rarg_rdy;

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            tmp_idx <= '0;
            permute_pow_r <= {{{POWER_WIDTH}{1'b0}}, {1'b1}};
        end else if (rarg_shaked) begin
            tmp_idx <= (permute_pow_r - 1) >> 1;
            permute_pow_r <= permute_pow_r * ROTATE_BASE;
        end else if (org_addr == ((POLY_POWER >> 1) - 1)) begin
            tmp_idx <= '0;
            permute_pow_r <= {{{POWER_WIDTH}{1'b0}}, {1'b1}};
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n)
            addr_gen_vld <= 1'b0;
        else if (rarg_shaked)
            addr_gen_vld <= 1'b1;
        else
            addr_gen_vld <= 1'b0;
    end

    assign flag = (POLY_POWER -  tmp_idx - 1) > ((POLY_POWER >> 1) - 1);
    assign rarg_addr = flag ? tmp_idx : POLY_POWER - 1 - tmp_idx;
    assign b_im = flag & addr_gen_vld;

endmodule : ecd_addr_gen

// module addr_gen_tb;
//     parameter PERIOD = 10;
//     parameter ADDR_WIDTH = 12;

//     logic clk;
//     logic rst_n;
//     logic                  rarg_vld;
//     logic                  rarg_rdy;
//     logic [ADDR_WIDTH-1:0] org_addr;
//     logic [ADDR_WIDTH-1:0] rarg_addr;
//     logic                  b_im;
//     logic [ADDR_WIDTH-1:0] cnt;

//     always_ff @(posedge clk or negedge rst_n) begin
//         if (~rst_n)
//             cnt <= {default: 0};
//         else if (rarg_vld) begin
//             cnt <= cnt + 1'b1;
//         end
//     end

//     assign org_addr = cnt;
//     always #(PERIOD/2) clk = ~clk;

//     initial begin
//         clk = 1'b0;
//         rst_n = 1'b0;
//         rarg_vld = 1'b0;
//         repeat(10) @(posedge clk);
//         rst_n = 1'b1;
//         # 0.1
//         rarg_vld = 1'b1;
//         repeat(5000) @(posedge clk);
//         $finish;
//     end

//     addr_gen #(
//         .ADDR_WIDTH     (12  ),
//         .POLY_POWER     (8192),
//         .ROTATE_BASE    (3   )
//     ) u_addr_gen (
//         .clk         (clk),
//         .rst_n      (rst_n),
//         .rarg_vld   (rarg_vld),
//         .rarg_rdy   (rarg_rdy),
//         .org_addr   (org_addr),
//         .rarg_addr  (rarg_addr),
//         .b_im       (b_im)
//     );

//     initial begin
//         $fsdbDumpfile("addr_gen.fsdb");
//         $fsdbDumpvars("+all");
//     end
// endmodule