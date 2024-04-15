//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: VP
// Module Name: iconn_upper_selector
// Modify Date: 
//
// Description:
// Upper priority selector
//////////////////////////////////////////////////

module iconn_upper_selector#(
        parameter PORT_NUM = 2,//must be 2
        parameter NODE_ADDR_WIDTH = 5
    )(
        input logic[NODE_ADDR_WIDTH - 1:0] ain[0:PORT_NUM - 1],
        input logic[PORT_NUM - 1:0] ain_valid,
        output logic[$clog2(PORT_NUM) - 1:0] port_index
    );

    assign port_index = !ain_valid[0] ? 'b1 : 'b0;
endmodule