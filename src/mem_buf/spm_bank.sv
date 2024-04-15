//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: SPM
// Module Name: spm_bank
// Modify Date: 
//
// Description:
// ScratchPad Memory Bank
//////////////////////////////////////////////////
module spm_bank #(
    parameter NUM_LANE = 128,
    parameter URAM_ADDR_WIDTH = 12,
    parameter URAM_DEPTH = 4096,
    parameter DATA_WIDTH = 64,
    parameter NB_PIPE = 3,
    parameter RAM_TYPE = "URAM"
) (
    input                                        clk,

    input  [URAM_ADDR_WIDTH-1:0]                 i_bank_addr_a,
    input  [DATA_WIDTH*NUM_LANE-1:0]             i_bank_wr_data_a,
    input                                        i_bank_en_a,
    input                                        i_bank_wr_en_a,
    output logic [DATA_WIDTH*NUM_LANE-1:0]       o_bank_rd_data_a,

    input  [URAM_ADDR_WIDTH-1:0]                 i_bank_addr_b,
    input  [DATA_WIDTH*NUM_LANE-1:0]             i_bank_wr_data_b,
    input                                        i_bank_en_b,
    input                                        i_bank_wr_en_b,
    input  [NUM_LANE-1:0]                        i_bank_col_mask,

    output logic [DATA_WIDTH*NUM_LANE-1:0]       o_bank_rd_data_b
);


    generate
        genvar i;
        if (RAM_TYPE == "URAM") begin
            for (i=0; i<NUM_LANE; i++) begin
                spm_uram #(
                    .URAM_ADDR_WIDTH    (URAM_ADDR_WIDTH),
                    .URAM_DEPTH         (URAM_DEPTH),
                    .DATA_WIDTH         (DATA_WIDTH),
                    .NB_PIPE            (NB_PIPE)
                ) u_spm_uram (
                    .clk         (clk),
                    .i_addr_a    (i_bank_addr_a),
                    .i_wr_data_a (i_bank_wr_data_a[i*DATA_WIDTH+:DATA_WIDTH]),
                    .i_en_a      (i_bank_en_a),
                    .i_wr_en_a   (i_bank_wr_en_a),
                    .o_rd_data_a (o_bank_rd_data_a[i*DATA_WIDTH+:DATA_WIDTH]),
                    .i_addr_b    (i_bank_addr_b),
                    .i_wr_data_b (i_bank_wr_data_b[i*DATA_WIDTH+:DATA_WIDTH]),
                    .i_en_b      (i_bank_en_b & i_bank_col_mask[i]),
                    .i_wr_en_b   (i_bank_wr_en_b),
                    .o_rd_data_b (o_bank_rd_data_b[i*DATA_WIDTH+:DATA_WIDTH])
                );
            end
        end
    endgenerate

endmodule