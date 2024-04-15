//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: VP
// Module Name: iconn_shuffle_reverse
// Modify Date: 
//
// Description:
// Shuffle-Exchange Reverse Map Function
//////////////////////////////////////////////////

module iconn_shuffle_reverse#(
        parameter NODE_ADDR_WIDTH = 5,
        parameter DATA_WIDTH = 64
    )(
        input logic[NODE_ADDR_WIDTH - 1:0] ain[0:2 ** NODE_ADDR_WIDTH - 1],
        input logic[DATA_WIDTH - 1:0] din[0:2 ** NODE_ADDR_WIDTH - 1],
        input logic[2 ** NODE_ADDR_WIDTH - 1:0] din_valid,
        output logic[NODE_ADDR_WIDTH - 1:0] aout[0:2 ** NODE_ADDR_WIDTH - 1],
        output logic[DATA_WIDTH - 1:0] dout[0:2 ** NODE_ADDR_WIDTH- 1],
        output logic[2 ** NODE_ADDR_WIDTH - 1:0] dout_valid
    );

    localparam PORT_NUM = 2 ** NODE_ADDR_WIDTH;

    genvar i;
    
    logic[$clog2(PORT_NUM) - 1:0] src_index[0:PORT_NUM - 1];
    
    generate
        for(i = 0;i < PORT_NUM;i++) begin
            assign src_index[i] = ((i & (2 ** (NODE_ADDR_WIDTH - 1))) == 0) ? (i << 1) : ((i << 1) + 1);
            assign aout[i] = ain[src_index[i]];
            assign dout[i] = din[src_index[i]];
            assign dout_valid[i] = din_valid[src_index[i]];
        end
    endgenerate
endmodule