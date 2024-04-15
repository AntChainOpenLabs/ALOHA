//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: 
// Module Name: op_queues
// Modify Date:

// Description: 
// Opcode queues
// output   reg  [RW_OP_WIDTH-1:0]   o_op_b0r,
// output   reg  [RW_OP_WIDTH-1:0]   o_op_b0w,
// output   reg  [RW_OP_WIDTH-1:0]   o_op_b1r,
// output   reg  [RW_OP_WIDTH-1:0]   o_op_b1w,
// output   reg  [ALU_OP_WIDTH-1:0]  o_op_alu,
// output   reg  [MUXO_OP_WIDTH-1:0] o_op_muxo,
// output   reg  [MUXI_OP_WIDTH-1:0] o_op_muxi,
// output   reg  [LS_OP_WIDTH-1:0]   o_op_ls,
// output   reg  [SCALAR_WIDTH-1:0]  o_scalar_alu
// output   reg  [SCALAR_WIDTH-1:0]  o_scalar_ls
//////////////////////////////////////////////////

`include "vp_defines.vh"
`include "common_defines.vh"
module op_queues #(
    parameter INST_WIDTH        = `INST_WIDTH       ,
    parameter CONFIG_OP_WIDTH   = `CONFIG_OP_WIDTH  ,
    parameter MUXO_OP_WIDTH     = `MUXO_OP_WIDTH    ,
    parameter MUXI_OP_WIDTH     = `MUXI_OP_WIDTH    ,
    parameter RW_OP_WIDTH       = `RW_OP_WIDTH      ,     // address + enable
    parameter ALU_OP_WIDTH      = `ALU_OP_WIDTH     ,
    parameter ICONN_OP_WIDTH    = `ICONN_OP_WIDTH   ,
    parameter NTT_OP_WIDTH      = `NTT_OP_WIDTH     ,
    parameter LSU_OP_WIDTH      = `LSU_OP_WIDTH     ,
    parameter SCALAR_WIDTH      = `SCALAR_WIDTH     ,

    parameter DEPTH             = `OPQUEUE_DEPTH,     // log(depth,2)
    parameter COMMON_BRAM_DELAY = `COMMON_BRAM_DELAY
) (
    input                               clk,
    input                               rst_n,
    input                               i_push,
    input       [CONFIG_OP_WIDTH-1:0]   i_op_config,
    input       [SCALAR_WIDTH-1:0]      i_scalar_config,
    input       [RW_OP_WIDTH-1:0]       i_op_b0r,
    input       [RW_OP_WIDTH-1:0]       i_op_b0w,
    input       [RW_OP_WIDTH-1:0]       i_op_b1r,
    input       [RW_OP_WIDTH-1:0]       i_op_b1w,
    input       [ALU_OP_WIDTH-1:0]      i_op_alu,
    input       [ICONN_OP_WIDTH-1:0]    i_op_iconn,
    input       [SCALAR_WIDTH-1:0]      i_scalar_iconn,
    input       [NTT_OP_WIDTH-1:0]      i_op_ntt,
    input       [MUXO_OP_WIDTH-1:0]     i_op_muxo,
    input       [MUXI_OP_WIDTH-1:0]     i_op_muxi,
    input       [LSU_OP_WIDTH-1:0]      i_op_ls,
    input       [SCALAR_WIDTH-1:0]      i_scalar_alu,
    input       [SCALAR_WIDTH-1:0]      i_scalar_ls,
    input                               i_pop,
    output      [CONFIG_OP_WIDTH-1:0]   o_op_config,
    output      [SCALAR_WIDTH-1:0]      o_scalar_config,
    output      [RW_OP_WIDTH-1:0]       o_op_b0r,
    output      [RW_OP_WIDTH-1:0]       o_op_b0w,
    output      [RW_OP_WIDTH-1:0]       o_op_b1r,
    output      [RW_OP_WIDTH-1:0]       o_op_b1w,
    output      [ALU_OP_WIDTH-1:0]      o_op_alu,
    output      [ICONN_OP_WIDTH-1:0]    o_op_iconn,
    output      [SCALAR_WIDTH-1:0]      o_scalar_iconn,
    output      [NTT_OP_WIDTH-1:0]      o_op_ntt,
    output      [MUXO_OP_WIDTH-1:0]     o_op_muxo,
    output      [MUXI_OP_WIDTH-1:0]     o_op_muxi,
    output      [LSU_OP_WIDTH-1:0]      o_op_ls,
    output      [SCALAR_WIDTH-1:0]      o_scalar_alu,
    output      [SCALAR_WIDTH-1:0]      o_scalar_ls,
    output                              o_empty,
    output                              o_afull
);

queue_wrapper #(
    .DWIDTH            (CONFIG_OP_WIDTH),
    .DEPTH             (DEPTH),
    .COMMON_BRAM_DELAY (COMMON_BRAM_DELAY)
) CONFIG_OpQueue(
    .clk                 (clk        ),
    .rst_n               (rst_n      ),
    .i_push              (i_push     ),
    .i_data              (i_op_config), 
    .i_pop               (i_pop      ),
    .o_data              (o_op_config),
    .o_empty             (           ),
    .o_full              (           )
);

queue_wrapper #(
    .DWIDTH            (SCALAR_WIDTH),
    .DEPTH             (DEPTH),
    .COMMON_BRAM_DELAY (COMMON_BRAM_DELAY)
) SCALAR_CONFIG_OpQueue(
    .clk                 (clk            ),
    .rst_n               (rst_n          ),
    .i_push              (i_push         ),
    .i_data              (i_scalar_config), 
    .i_pop               (i_pop          ),
    .o_data              (o_scalar_config),
    .o_empty             (               ),
    .o_full              (               )
);

queue_wrapper #(
    .DWIDTH            (RW_OP_WIDTH),
    .DEPTH             (DEPTH),
    .COMMON_BRAM_DELAY (COMMON_BRAM_DELAY)
) B0R(
    .clk                 (clk        ),
    .rst_n               (rst_n      ),
    .i_push              (i_push     ),
    .i_data              (i_op_b0r   ), 
    .i_pop               (i_pop      ),
    .o_data              (o_op_b0r   ),
    .o_empty             (o_empty    ),
    .o_afull             (o_afull    )
);

queue_wrapper #(
    .DWIDTH            (RW_OP_WIDTH),
    .DEPTH             (DEPTH),
    .COMMON_BRAM_DELAY (COMMON_BRAM_DELAY)
) B1R(
    .clk                 (clk        ),
    .rst_n               (rst_n      ),
    .i_push              (i_push     ),
    .i_data              (i_op_b1r   ), 
    .i_pop               (i_pop      ),
    .o_data              (o_op_b1r   ),
    .o_empty             (           ),
    .o_full              (           )
);

queue_wrapper #(
    .DWIDTH            (RW_OP_WIDTH),
    .DEPTH             (DEPTH),
    .COMMON_BRAM_DELAY (COMMON_BRAM_DELAY)
) B0W(
    .clk                 (clk        ),
    .rst_n               (rst_n      ),
    .i_push              (i_push     ),
    .i_data              (i_op_b0w   ), 
    .i_pop               (i_pop      ),
    .o_data              (o_op_b0w   ),
    .o_empty             (           ),
    .o_full              (           )
);  

queue_wrapper #(
    .DWIDTH            (RW_OP_WIDTH),
    .DEPTH             (DEPTH),
    .COMMON_BRAM_DELAY (COMMON_BRAM_DELAY)
) B1W(
    .clk                 (clk        ),
    .rst_n               (rst_n      ),
    .i_push              (i_push     ),
    .i_data              (i_op_b1w   ), 
    .i_pop               (i_pop      ),
    .o_data              (o_op_b1w   ),
    .o_empty             (           ),
    .o_full              (           )
);

queue_wrapper #(
    .DWIDTH            (ALU_OP_WIDTH),
    .DEPTH             (DEPTH),
    .COMMON_BRAM_DELAY (COMMON_BRAM_DELAY)
) ALU_OpQueue(
    .clk                 (clk        ),
    .rst_n               (rst_n      ),
    .i_push              (i_push     ),
    .i_data              (i_op_alu   ), 
    .i_pop               (i_pop      ),
    .o_data              (o_op_alu   ),
    .o_empty             (           ),
    .o_full              (           )
);

queue_wrapper #(
    .DWIDTH            (SCALAR_WIDTH),
    .DEPTH             (DEPTH),
    .COMMON_BRAM_DELAY (COMMON_BRAM_DELAY)
) SCALAR_ALU_OpQueue(
    .clk                 (clk            ),
    .rst_n               (rst_n          ),
    .i_push              (i_push         ),
    .i_data              (i_scalar_alu   ), 
    .i_pop               (i_pop          ),
    .o_data              (o_scalar_alu   ),
    .o_empty             (               ),
    .o_full              (               )
);

queue_wrapper #(
    .DWIDTH            (ICONN_OP_WIDTH),
    .DEPTH             (DEPTH),
    .COMMON_BRAM_DELAY (COMMON_BRAM_DELAY)
) ICONN_OpQueue(
    .clk                 (clk        ),
    .rst_n               (rst_n      ),
    .i_push              (i_push     ),
    .i_data              (i_op_iconn ), 
    .i_pop               (i_pop      ),
    .o_data              (o_op_iconn ),
    .o_empty             (           ),
    .o_full              (           )
);

queue_wrapper #(
    .DWIDTH            (SCALAR_WIDTH),
    .DEPTH             (DEPTH),
    .COMMON_BRAM_DELAY (COMMON_BRAM_DELAY)
) SCALAR_ICONN_OpQueue(
    .clk                 (clk            ),
    .rst_n               (rst_n          ),
    .i_push              (i_push         ),
    .i_data              (i_scalar_iconn ), 
    .i_pop               (i_pop          ),
    .o_data              (o_scalar_iconn ),
    .o_empty             (               ),
    .o_full              (               )
);

queue_wrapper #(
    .DWIDTH            (NTT_OP_WIDTH),
    .DEPTH             (DEPTH),
    .COMMON_BRAM_DELAY (COMMON_BRAM_DELAY)
) NTT_OpQueue(
    .clk                 (clk        ),
    .rst_n               (rst_n      ),
    .i_push              (i_push     ),
    .i_data              (i_op_ntt   ), 
    .i_pop               (i_pop      ),
    .o_data              (o_op_ntt   ),
    .o_empty             (           ),
    .o_full              (           )
);

queue_wrapper #(
    .DWIDTH            (MUXO_OP_WIDTH),
    .DEPTH             (DEPTH),
    .COMMON_BRAM_DELAY (COMMON_BRAM_DELAY)
) MUXO_OpQueue(
    .clk                 (clk        ),
    .rst_n               (rst_n      ),
    .i_push              (i_push     ),
    .i_data              (i_op_muxo  ), 
    .i_pop               (i_pop      ),
    .o_data              (o_op_muxo  ),
    .o_empty             (           ),
    .o_full              (           )
);

queue_wrapper #(
    .DWIDTH            (MUXI_OP_WIDTH),
    .DEPTH             (DEPTH),
    .COMMON_BRAM_DELAY (COMMON_BRAM_DELAY)
) MUXI_OpQueue(
    .clk                 (clk        ),
    .rst_n               (rst_n      ),
    .i_push              (i_push     ),
    .i_data              (i_op_muxi  ), 
    .i_pop               (i_pop      ),
    .o_data              (o_op_muxi  ),
    .o_empty             (           ),
    .o_full              (           )
);

queue_wrapper #(
    .DWIDTH            (LSU_OP_WIDTH),
    .DEPTH             (DEPTH),
    .COMMON_BRAM_DELAY (COMMON_BRAM_DELAY)
) LS_OpQueue(
    .clk                 (clk        ),
    .rst_n               (rst_n      ),
    .i_push              (i_push     ),
    .i_data              (i_op_ls    ), 
    .i_pop               (i_pop      ),
    .o_data              (o_op_ls    ),
    .o_empty             (           ),
    .o_full              (           )
);

queue_wrapper #(
    .DWIDTH            (SCALAR_WIDTH),
    .DEPTH             (DEPTH),
    .COMMON_BRAM_DELAY (COMMON_BRAM_DELAY)
) SCALAR_LS_OpQueue(
    .clk                 (clk            ),
    .rst_n               (rst_n          ),
    .i_push              (i_push         ),
    .i_data              (i_scalar_ls    ), 
    .i_pop               (i_pop          ),
    .o_data              (o_scalar_ls    ),
    .o_empty             (               ),
    .o_full              (               )
);


endmodule