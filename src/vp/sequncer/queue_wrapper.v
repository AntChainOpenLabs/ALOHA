//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: 
// Module Name: queue_wrapper
// Modify Date:

// Description: ports for queue
//////////////////////////////////////////////////

`include "common_defines.vh"
`include "vp_defines.vh"
module queue_wrapper #(
    parameter DWIDTH = `COE_WIDTH,
    parameter DEPTH = `IQUEUE_DEPTH,
    parameter AWIDTH = $clog2(DEPTH),
    parameter COMMON_BRAM_DELAY = `COMMON_BRAM_DELAY
) (
    input                   clk,
    input                   rst_n,
    input                   i_push,
    input      [DWIDTH-1:0] i_data,
    input                   i_pop,
    output     [DWIDTH-1:0] o_data,
    output                  o_empty,
    output                  o_afull,
    output                  o_full
);

sync_fifo #(
    .DWIDTH           (DWIDTH           ),
    .DEPTH            (DEPTH            ),
    .AWIDTH           (AWIDTH           ),
    .COMMON_BRAM_DELAY(COMMON_BRAM_DELAY)
) queue_fifo (
    .clk         (clk         ),
    .reset       (!rst_n      ),
    .push        (i_push      ),
    .in          (i_data      ),
    .pop         (i_pop       ),
    .out         (o_data      ),
    .empty       (o_empty     ),
    .almostempty (            ),
    .full        (o_full      ),
    .almostfull  (o_afull     ),
    .num         (            )
);

endmodule