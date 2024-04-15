//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: ENCODER
// Module Name: sycn_fifo
// Modify Date: 
//
// Description:
// synchronous FIFO
//////////////////////////////////////////////////
module fifo #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 4,
    parameter THRESHOLD = 2
) (
    input                           clk,
    input                           rst_n,
    input        [DATA_WIDTH-1:0]   data_i,
    input                           push,
    input                           pop,

    output logic [DATA_WIDTH-1:0]   data_o,
    output logic                    accept,
    output logic                    valid,
    output logic                    almost_full
);
    localparam DEPTH = 1 << ADDR_WIDTH;
    localparam COUNT_WIDTH = ADDR_WIDTH + 1;

    logic [DATA_WIDTH-1:0] ram[DEPTH-1:0];
    logic [ADDR_WIDTH-1:0] rd_ptr;
    logic [ADDR_WIDTH-1:0] wr_ptr;
    logic [COUNT_WIDTH-1:0] cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            cnt    <= '0;
            rd_ptr <= '0;
            wr_ptr <= '0;
        end else begin
            if(push & accept) begin
                ram[wr_ptr] <= data_i;
                wr_ptr <= wr_ptr + 1;
            end

            if(pop & valid) begin
                rd_ptr <= rd_ptr + 1;
            end

            if((push & accept) & ~(pop & valid)) begin
                cnt <= cnt + 1;
            end else if (~(push & accept) & (pop & valid)) begin
                cnt <= cnt - 1;
            end
        end
    end

    assign valid = (cnt != 0);
    assign accept = (cnt != DEPTH);
    assign almost_full = (cnt >= DEPTH - THRESHOLD);

    assign data_o = ram[rd_ptr];

endmodule : fifo

