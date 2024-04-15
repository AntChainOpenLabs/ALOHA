//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: ENCODER
// Module Name: ram
// Modify Date: 
//
// Description:
// ram bank for ping pang buffer
//////////////////////////////////////////////////
module ram #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 13,
    parameter LATENCY    = 1
) (
    input                           clk,

    input        [ADDR_WIDTH-1:0]   waddr_i,
    input        [ADDR_WIDTH-1:0]   raddr_i,
    input        [DATA_WIDTH-1:0]   wdata_i,
    input                           we_i,
    input                           re_i,
    output logic [DATA_WIDTH-1:0]   rdata_o
);
    logic [DATA_WIDTH-1:0]  mem [(1<<ADDR_WIDTH)-1:0];
    (* MAX_FANOUT = 100 *) logic [DATA_WIDTH-1:0]  mem_reg [LATENCY-1:0];
    // wr
    always_ff @(posedge clk) begin
        if (we_i)
            mem[waddr_i] <= wdata_i;
    end
    // rd
    always_ff @(posedge clk) begin
        if (re_i)
            mem_reg[0] <= mem[raddr_i];
    end

    always_ff @(posedge clk) begin
        for (int i=0; i<LATENCY-1;i++)
            mem_reg[i+1] <= mem_reg[i];
    end

    assign rdata_o = mem_reg[LATENCY-1];
endmodule : ram

module ram_bank #(
    parameter BANK_DATA_WIDTH = 512,
    parameter ADDR_WIDTH = 10,
    parameter LATENCY = 1,
    parameter BANK_NUM = 8,
    parameter STAGE = 0,
    localparam DATA_WIDTH = BANK_DATA_WIDTH / BANK_NUM
) (
    input                                           clk,
    input        [ADDR_WIDTH-1:0]                   raddr,
    input        [ADDR_WIDTH-1:0]                   waddr,
    input        [BANK_DATA_WIDTH-1:0]              wdata,
    input        [DATA_WIDTH-1:0]                   wdata_per_bank,
    input        [BANK_NUM-1:0]                     wen,
    output logic [BANK_DATA_WIDTH-1:0]              rdata
);
    genvar i;
    generate;
        if (STAGE == 0 || STAGE == 2) begin
            for (i = 0; i < BANK_NUM; i++) begin
                ram #(
                    .DATA_WIDTH (DATA_WIDTH),
                    .ADDR_WIDTH (ADDR_WIDTH),
                    .LATENCY    (LATENCY)
                ) u_ram (
                    .clk        (clk),
                    .waddr_i    (waddr),
                    .raddr_i    (raddr),
                    .wdata_i    (wdata[i*DATA_WIDTH+:DATA_WIDTH]),
                    .we_i       (wen[i]),
                    .re_i       (~wen[i]),
                    .rdata_o    (rdata[i*DATA_WIDTH+:DATA_WIDTH])
                );
            end
        end
        else if (STAGE == 1) begin
            for (i = 0; i < BANK_NUM; i++) begin
                ram #(
                    .DATA_WIDTH (DATA_WIDTH),
                    .ADDR_WIDTH (ADDR_WIDTH),
                    .LATENCY    (LATENCY)
                ) u_ram (
                    .clk        (clk),
                    .waddr_i    (waddr),
                    .raddr_i    (raddr),
                    .wdata_i    (wdata_per_bank),
                    .we_i       (wen[i]),
                    .re_i       (~wen[i]),
                    .rdata_o    (rdata[i*DATA_WIDTH+:DATA_WIDTH])
                );
            end
        end
    endgenerate
endmodule : ram_bank

