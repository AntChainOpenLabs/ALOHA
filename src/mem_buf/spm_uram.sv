//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: SPM
// Module Name: spm_uram
// Modify Date: 
//
// Description:
// ScratchPad Memory Uram
//////////////////////////////////////////////////
module spm_uram #(
    parameter URAM_ADDR_WIDTH = 12,
    parameter URAM_DEPTH = 4096,
    parameter DATA_WIDTH = 64,
    parameter NB_PIPE = 3,
    parameter SYN = 1
) (
    input                                        clk,

    // port A
    input  [URAM_ADDR_WIDTH-1:0]                 i_addr_a,
    input  [DATA_WIDTH-1:0]                      i_wr_data_a,
    input                                        i_en_a,
    input                                        i_wr_en_a,
    output logic [DATA_WIDTH-1:0]                o_rd_data_a,

    // port B
    input  [URAM_ADDR_WIDTH-1:0]                 i_addr_b,
    input  [DATA_WIDTH-1:0]                      i_wr_data_b,
    input                                        i_en_b,
    input                                        i_wr_en_b,
    output logic [DATA_WIDTH-1:0]                o_rd_data_b
);

    // xdc syntax: set_property ram_style ultra [get_cells myram]
    (* ram_style = "ultra" *) reg [DATA_WIDTH-1:0] mem [URAM_DEPTH-1:0];
    reg [DATA_WIDTH-1:0] mem_pipe_rega [NB_PIPE-1:0];
    reg [DATA_WIDTH-1:0] mem_pipe_regb [NB_PIPE-1:0];

    // port A
    generate
        if (SYN == 0) begin
            always_ff @(posedge clk) begin
                // port A have the highest priority
                if (i_en_a & i_wr_en_a) begin
                    mem[i_addr_a] <= i_wr_data_a;
                end
                if (i_en_b & i_wr_en_b) begin
                    mem[i_addr_b] <= i_wr_data_b;
                end
            end
        end
        else if (SYN == 1) begin
            always_ff @(posedge clk) begin
                if (i_en_a & i_wr_en_a) begin
                    mem[i_addr_a] <= i_wr_data_a;
                end
            end

            always_ff @(posedge clk) begin
                if (i_en_b & i_wr_en_b) begin
                    mem[i_addr_b] <= i_wr_data_b;
                end
            end

        end
    endgenerate

    // port A
    always_ff @(posedge clk) begin
        if (i_en_a & ~i_wr_en_a)
            mem_pipe_rega[0] <= mem[i_addr_a];
    end

    always_ff @(posedge clk) begin
        for (int i=0; i<NB_PIPE-1; i=i+1)
            mem_pipe_rega[i+1]<= mem_pipe_rega[i];
    end

    assign o_rd_data_a = mem_pipe_rega[NB_PIPE-1];

    // port B
    always_ff @(posedge clk) begin
        if (i_en_b & ~i_wr_en_b)
            mem_pipe_regb[0] <= mem[i_addr_b];
    end

    always_ff @(posedge clk) begin
        for (int i=0; i<NB_PIPE-1; i=i+1)
            mem_pipe_regb[i+1]<= mem_pipe_regb[i];
    end

    assign o_rd_data_b = mem_pipe_regb[NB_PIPE-1];

endmodule
