//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: VP
// Module Name: iconn_mux
// Modify Date: 
//
// Description:
// Interconnect MUX
//////////////////////////////////////////////////

module iconn_mux#(
        parameter OMEGA_MODE = 1,
        parameter PORT_NUM = 2,//must be 2
        parameter NODE_ADDR_WIDTH = 5,
        parameter DATA_WIDTH = 64,
        parameter ADDR_BIT_ID = 0
    )(
        input logic[NODE_ADDR_WIDTH - 1:0] ain[0:PORT_NUM - 1],
        input logic[DATA_WIDTH - 1:0] din[0:PORT_NUM - 1],
        input logic[PORT_NUM - 1:0] din_valid,
        output logic[NODE_ADDR_WIDTH - 1:0] aout[0:PORT_NUM - 1],
        output logic[DATA_WIDTH - 1:0] dout[0:PORT_NUM - 1],
        output logic[PORT_NUM - 1:0] dout_valid
    );

    logic selected_id;
    logic mode_bit;
    logic cross_mode;

    generate
        if(OMEGA_MODE) begin
            iconn_upper_selector#(
                .PORT_NUM(PORT_NUM),
                .NODE_ADDR_WIDTH(NODE_ADDR_WIDTH)
            )iconn_upper_selector_inst(
                .ain(ain),
                .ain_valid(din_valid),
                .port_index(selected_id)
            );
        end
        else begin
            iconn_smaller_selector#(
                .PORT_NUM(PORT_NUM),
                .NODE_ADDR_WIDTH(NODE_ADDR_WIDTH)
            )iconn_smaller_selector_inst(
                .ain(ain),
                .ain_valid(din_valid),
                .port_index(selected_id)
            );
        end
    endgenerate

    assign mode_bit = ain[selected_id][ADDR_BIT_ID];
    assign cross_mode = mode_bit ^ selected_id;
    assign aout[0] = !cross_mode ? ain[0] : ain[1];
    assign aout[1] = !cross_mode ? ain[1] : ain[0];
    assign dout[0] = !cross_mode ? din[0] : din[1];
    assign dout[1] = !cross_mode ? din[1] : din[0];
    assign dout_valid[0] = !cross_mode ? din_valid[0] : din_valid[1];
    assign dout_valid[1] = !cross_mode ? din_valid[1] : din_valid[0];
endmodule