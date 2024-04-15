module bram #(
    parameter ADDR_WIDTH = 12,
    parameter DEPTH = 4096,
    parameter DATA_WIDTH = 64,
    parameter NB_PIPE = 3
) (
    input                         clk,
    input                         wen,
    input                         ren,
    input        [ADDR_WIDTH-1:0] addr,
    input        [DATA_WIDTH-1:0] wdata,
    output logic [DATA_WIDTH-1:0] rdata
);
    (* ram_style="block" *) reg [DATA_WIDTH-1:0] mem [DEPTH-1:0];
    reg [DATA_WIDTH-1:0] mem_pipe_reg [NB_PIPE-1:0];

    always_ff @(posedge clk) begin
        if (wen) begin
            mem[addr] <= wdata;
        end
    end

    always_ff @(posedge clk) begin
        if (ren) begin
            mem_pipe_reg[0] <= mem[addr];
        end
    end

    always_ff @(posedge clk) begin
        for (int i=0; i<NB_PIPE-1; ++i) begin
            mem_pipe_reg[i+1] <= mem_pipe_reg[i];
        end
    end

    assign rdata = mem_pipe_reg[NB_PIPE-1];

endmodule

module ksk_bram_bank #(
    parameter NUM_LANE = 128,
    parameter ADDR_WIDTH = 12,
    parameter DEPTH = 4096,
    parameter DATA_WIDTH = 64,
    parameter NB_PIPE = 3
) (
    input                                   clk,

    input        [ADDR_WIDTH-1:0]           addr,
    input                                   wen,
    input                                   ren,
    input        [NUM_LANE-1:0]             wmask,
    input        [DATA_WIDTH*NUM_LANE-1:0]  wdata,

    output logic [DATA_WIDTH*NUM_LANE-1:0] rdata
);
    genvar i;
    generate
        for (i=0; i<NUM_LANE; i++) begin
            bram #(
                .ADDR_WIDTH   (ADDR_WIDTH),
                .DEPTH        (DEPTH),
                .DATA_WIDTH   (DATA_WIDTH),
                .NB_PIPE      (NB_PIPE)
            ) u_ksk_bram (
                .clk          (clk),
                .wen          (wen & wmask[i]),
                .ren          (ren),
                .addr         (addr),
                .wdata        (wdata[i*DATA_WIDTH+:DATA_WIDTH]),
                .rdata        (rdata[i*DATA_WIDTH+:DATA_WIDTH])
            );
        end
    endgenerate

endmodule