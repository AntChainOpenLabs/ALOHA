//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: VP
// Module Name: ntt_swap
// Modify Date: 
//
// Description:
// NTT/INTT ALU input/output data swap
//////////////////////////////////////////////////

module ntt_swap#(
        parameter DATA_WIDTH = 64,
        parameter LATENCY = 1
    )(
        input logic clk,
        input logic i_alu_inout_swap,
        input logic[DATA_WIDTH - 1:0] i_data0,
        input logic[DATA_WIDTH - 1:0] i_data1,
        output logic[DATA_WIDTH - 1:0] o_data0,
        output logic[DATA_WIDTH - 1:0] o_data1
    );

    logic[DATA_WIDTH - 1:0] up_reg;
    logic[DATA_WIDTH - 1:0] down_reg;
    logic[DATA_WIDTH - 1:0] up_out;
    logic[DATA_WIDTH - 1:0] down_out;
    logic[DATA_WIDTH - 1:0] data0_pipe[0:LATENCY - 1];
    logic[DATA_WIDTH - 1:0] data1_pipe[0:LATENCY - 1];

    genvar i;

    //up register and mux 0
    always_ff @(posedge clk) begin
        if(!i_alu_inout_swap) begin
            up_reg <= i_data0;
        end
        else begin
            up_reg <= down_reg;
        end
    end

    assign up_out = up_reg;

    //down register and mux 1
    always_ff @(posedge clk) begin
        down_reg <= i_data1;
    end

    assign down_out = !i_alu_inout_swap ? down_reg : i_data0;

    //output pipeline
    assign data0_pipe[0] = up_out;
    assign data1_pipe[0] = down_out;

    generate
        for(i = 1;i < LATENCY;i++) begin
            always_ff @(posedge clk) begin
                data0_pipe[i] <= data0_pipe[i - 1];
                data1_pipe[i] <= data1_pipe[i - 1];
            end
        end
    endgenerate

    assign o_data0 = data0_pipe[LATENCY - 1];
    assign o_data1 = data1_pipe[LATENCY - 1];
endmodule