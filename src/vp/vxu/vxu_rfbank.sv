//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: VP
// Module Name: vxu_top
// Modify Date: 
//
// Description:
// Vector Execution Unit Register File Bank
//////////////////////////////////////////////////

module vxu_rfbank#(
        parameter ADDR_WIDTH = 16,
        parameter DATA_WIDTH = 64,
        parameter READ_LATENCY = 1
    )(
        input logic clk,
        input logic rst_n,
        input logic[ADDR_WIDTH - 1:0] raddr,
        output logic[DATA_WIDTH - 1:0] rdata,
        input re,
        input logic[ADDR_WIDTH - 1:0] waddr,
        input logic[DATA_WIDTH - 1:0] wdata,
        input we
    );
    
    (* ram_style="block" *)reg[DATA_WIDTH - 1:0] rf[0:2**ADDR_WIDTH - 1];
    reg[DATA_WIDTH - 1:0] rdata_shift[0:READ_LATENCY - 1];
    genvar i;

    always_ff @(posedge clk) begin
        if(re) begin
            rdata_shift[0] <= rf[raddr];
        end
    end

    generate
        for(i = 1;i < READ_LATENCY;i++) begin
            always_ff @(posedge clk) begin
                rdata_shift[i] <= rdata_shift[i - 1];
            end
        end
    endgenerate

    assign rdata = rdata_shift[READ_LATENCY - 1];

    always_ff @(posedge clk) begin
        if(we) begin
            rf[waddr] <= wdata;
        end
    end
endmodule