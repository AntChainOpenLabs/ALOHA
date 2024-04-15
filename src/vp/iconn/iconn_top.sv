//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: VP
// Module Name: iconn_top
// Modify Date: 
//
// Description:
// Interconnect TOP
//////////////////////////////////////////////////

module iconn_top#(
        parameter MUX_PORT_NUM = 2,//must be 2
        parameter NODE_ADDR_WIDTH = 5,
        parameter DATA_WIDTH = 64
    )(
        input logic clk,
        input logic rst_n,
        input logic[NODE_ADDR_WIDTH - 1:0] ain[0:2 ** NODE_ADDR_WIDTH - 1],
        input logic[DATA_WIDTH - 1:0] din[0:2 ** NODE_ADDR_WIDTH - 1],
        input logic[2 ** NODE_ADDR_WIDTH - 1:0] din_valid,
        output logic[NODE_ADDR_WIDTH - 1:0] aout[0:2 ** NODE_ADDR_WIDTH - 1],
        output logic[DATA_WIDTH - 1:0] dout[0:2 ** NODE_ADDR_WIDTH - 1],
        output logic[2 ** NODE_ADDR_WIDTH - 1:0] dout_valid,
        input logic fl_mode,
        output logic[NODE_ADDR_WIDTH - 1:0] fl_aout[0:2 ** NODE_ADDR_WIDTH - 1],//fl = first level
        output logic[DATA_WIDTH - 1:0] fl_dout[0:2 ** NODE_ADDR_WIDTH - 1],
        output logic[2 ** NODE_ADDR_WIDTH - 1:0] fl_dout_valid,
        input logic[NODE_ADDR_WIDTH - 1:0] flr_ain[0:2 ** NODE_ADDR_WIDTH - 1],//flr - first level reverse
        input logic[DATA_WIDTH - 1:0] flr_din[0: 2 ** NODE_ADDR_WIDTH - 1],
        input logic[2 ** NODE_ADDR_WIDTH - 1:0] flr_din_valid,
        output logic[NODE_ADDR_WIDTH - 1:0] flr_aout[0:2 ** NODE_ADDR_WIDTH - 1],
        output logic[DATA_WIDTH - 1:0] flr_dout[0:2 ** NODE_ADDR_WIDTH - 1],
        output logic[2 ** NODE_ADDR_WIDTH - 1:0] flr_dout_valid
    );

    genvar i, j;

    logic[NODE_ADDR_WIDTH - 1:0] input_port_addr[0:NODE_ADDR_WIDTH * 2 - 1][0:2 ** NODE_ADDR_WIDTH - 1];
    logic[DATA_WIDTH - 1:0] input_port_data[0:NODE_ADDR_WIDTH * 2 - 1][0:2 ** NODE_ADDR_WIDTH - 1];
    logic[2 ** NODE_ADDR_WIDTH - 1:0] input_port_valid[0:NODE_ADDR_WIDTH * 2 - 1];

    logic[NODE_ADDR_WIDTH - 1:0] output_port_addr[0:NODE_ADDR_WIDTH * 2 - 1][0:2 ** NODE_ADDR_WIDTH - 1];
    logic[DATA_WIDTH - 1:0] output_port_data[0:NODE_ADDR_WIDTH * 2 - 1][0:2 ** NODE_ADDR_WIDTH - 1];
    logic[2 ** NODE_ADDR_WIDTH - 1:0] output_port_valid[0:NODE_ADDR_WIDTH * 2 - 1];

    logic[NODE_ADDR_WIDTH - 1:0] shuffle_input_port_addr[0:NODE_ADDR_WIDTH * 2 - 1][0:2 ** NODE_ADDR_WIDTH - 1];
    logic[DATA_WIDTH - 1:0] shuffle_input_port_data[0:NODE_ADDR_WIDTH * 2 - 1][0:2 ** NODE_ADDR_WIDTH - 1];
    logic[2 ** NODE_ADDR_WIDTH - 1:0] shuffle_input_port_valid[0:NODE_ADDR_WIDTH * 2 - 1];

    logic[NODE_ADDR_WIDTH - 1:0] shuffle_output_port_addr[0:NODE_ADDR_WIDTH * 2 - 1][0:2 ** NODE_ADDR_WIDTH - 1];
    logic[DATA_WIDTH - 1:0] shuffle_output_port_data[0:NODE_ADDR_WIDTH * 2 - 1][0:2 ** NODE_ADDR_WIDTH - 1];
    logic[2 ** NODE_ADDR_WIDTH - 1:0] shuffle_output_port_valid[0:NODE_ADDR_WIDTH * 2 - 1];

    assign fl_aout = shuffle_output_port_addr[0];
    assign fl_dout = shuffle_output_port_data[0];
    assign fl_dout_valid = shuffle_output_port_valid[0];

    iconn_shuffle_reverse#(
        .NODE_ADDR_WIDTH(NODE_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    )iconn_shuffle_reverse_inst(
        .ain(flr_ain),
        .din(flr_din),
        .din_valid(flr_din_valid),
        .aout(flr_aout),
        .dout(flr_dout),
        .dout_valid(flr_dout_valid)
    );

    generate
        for(i = 0;i < NODE_ADDR_WIDTH * 2;i++) begin
            iconn_shuffle#(
                .NODE_ADDR_WIDTH(NODE_ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH)
            )iconn_shuffle_inst(
                .ain(shuffle_input_port_addr[i]),
                .din(shuffle_input_port_data[i]),
                .din_valid(shuffle_input_port_valid[i]),
                .aout(shuffle_output_port_addr[i]),
                .dout(shuffle_output_port_data[i]),
                .dout_valid(shuffle_output_port_valid[i])
            );

            for(j = 0;j < 2 ** NODE_ADDR_WIDTH;j += MUX_PORT_NUM) begin
                iconn_mux#(
                    .OMEGA_MODE(i >= NODE_ADDR_WIDTH),
                    .PORT_NUM(MUX_PORT_NUM),
                    .NODE_ADDR_WIDTH(NODE_ADDR_WIDTH),
                    .DATA_WIDTH(DATA_WIDTH),
                    .ADDR_BIT_ID(unsigned'((i < NODE_ADDR_WIDTH) ? (NODE_ADDR_WIDTH - i - 1) : (2 * NODE_ADDR_WIDTH - i - 1)))
                )iconn_mux_inst(
                    .ain(input_port_addr[i][j +: MUX_PORT_NUM]),
                    .din(input_port_data[i][j +: MUX_PORT_NUM]),
                    .din_valid(input_port_valid[i][j +: MUX_PORT_NUM]),
                    .aout(output_port_addr[i][j +: MUX_PORT_NUM]),
                    .dout(output_port_data[i][j +: MUX_PORT_NUM]),
                    .dout_valid(output_port_valid[i][j +: MUX_PORT_NUM])
                );
            end

            if(i == 0) begin
                assign shuffle_input_port_addr[i] = ain;
                assign shuffle_input_port_data[i] = din;
                assign shuffle_input_port_valid[i] = din_valid;
            end
            else if((i & 1) == 0) begin
                always_ff @(posedge clk or negedge rst_n) begin
                    if(!rst_n) begin
                        shuffle_input_port_valid[i] <= 'b0;
                    end
                    else begin
                        shuffle_input_port_valid[i] <= output_port_valid[i - 1];
                    end
                end

                always_ff @(posedge clk) begin
                    shuffle_input_port_addr[i] <= output_port_addr[i - 1];
                    shuffle_input_port_data[i] <= output_port_data[i - 1];
                end
            end
            else begin
                assign shuffle_input_port_addr[i] = output_port_addr[i - 1];
                assign shuffle_input_port_data[i] = output_port_data[i - 1];
                assign shuffle_input_port_valid[i] = output_port_valid[i - 1];
            end
        end
    endgenerate

    assign aout = shuffle_output_port_addr[NODE_ADDR_WIDTH * 2 - 1];
    assign dout = shuffle_output_port_data[NODE_ADDR_WIDTH * 2 - 1];
    assign dout_valid = shuffle_output_port_valid[NODE_ADDR_WIDTH * 2 - 1];

    assign input_port_addr = shuffle_output_port_addr;
    assign input_port_data = shuffle_output_port_data;
    assign input_port_valid[0] = fl_mode ? 'b0 : shuffle_output_port_valid[0];
    assign input_port_valid[1 +: NODE_ADDR_WIDTH * 2 - 1] = shuffle_output_port_valid[1 +: NODE_ADDR_WIDTH * 2 - 1];
endmodule