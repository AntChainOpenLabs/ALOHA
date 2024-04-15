module axi_data_rd_top #(
    parameter AXI_ADDR_WIDTH = 64,
    parameter AXI_DATA_WIDTH = 512,
    parameter AXI_XFER_SIZE_WIDTH = 32,
    parameter INCLUDE_DATA_FIFO = 0,
    parameter NB_PIPE = 1
) (
    // System Signals
    input       clk,
    input       rst_n,

    // AXI4 Interfaces for Input Data
    output logic                                axi_arvalid,
    input  logic                                axi_arready,
    output logic    [AXI_ADDR_WIDTH-1:0]        axi_araddr,
    output logic    [7:0]                       axi_arlen,

    input  logic                                axi_rvalid,
    output logic                                axi_rready,
    input  logic    [AXI_DATA_WIDTH-1:0]        axi_rdata,
    input  logic                                axi_rlast,

    // Control Signals
    input  logic    [31:0]                      i_axi_rd_command,
    input  logic                                i_axi_rd_start,
    output logic                                o_axi_rd_done,
    input  logic    [AXI_ADDR_WIDTH-1:0]        i_axi_rd_base_addr,

    input  logic    [AXI_ADDR_WIDTH-1:0]        data_ptr,
    input  logic    [AXI_XFER_SIZE_WIDTH-1:0]   data_size_bytes,

    // To RAM
    output logic                                ksk_wr_en,
    output logic                                axi_wr_en,
    // output logic                                encode_wr_en,

    output logic    [AXI_ADDR_WIDTH-1:0]        rd_wraddr,
    output logic    [AXI_DATA_WIDTH-1:0]        rd_wrdata,

    // TO Encoder
    output logic    [AXI_DATA_WIDTH-1:0]        encode_axis_tdata,
    output logic                                encode_axis_tvalid,
    output logic                                encode_axis_tlast,
    input  logic                                encode_axis_tready
);
    typedef enum logic [1:0] { IDLE, KSK, ENCODE, AXI } fsm_t;
    fsm_t crt_state, nxt_state;

    logic a2b_wr_en;
    logic [AXI_ADDR_WIDTH-1:0] a2b_wr_addr;
    logic [AXI_DATA_WIDTH-1:0] a2b_wr_data;
    logic [AXI_DATA_WIDTH-1:0] a2b_axis_tdata;
    logic                      a2b_axis_tvalid;
    logic                      a2b_axis_tlast;
    logic                      a2b_axis_tready;
    logic                      as2b_bypass;

    assign ksk_wr_en = (i_axi_rd_command == 'd0) & a2b_wr_en;
    assign axi_wr_en = (i_axi_rd_command == 'd1) & a2b_wr_en;
    // assign encode_wr_en = (i_axi_rd_command == 'd2) & a2b_wr_en;

    assign rd_wraddr = a2b_wr_addr;
    assign rd_wrdata = a2b_wr_data;

    logic a2b_done;

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n)
            crt_state <= IDLE;
        else
            crt_state <= nxt_state;
    end

    always_comb begin
        nxt_state = crt_state;
        case (crt_state)
            IDLE: begin
                if (i_axi_rd_command == 'd0 && i_axi_rd_start)
                    nxt_state = KSK;
                else if (i_axi_rd_command == 'd1 && i_axi_rd_start)
                    nxt_state = AXI;
                else if (i_axi_rd_command == 'd2 && i_axi_rd_start)
                    nxt_state = ENCODE;
            end

            KSK: nxt_state = a2b_done ? IDLE : crt_state;

            // if in encode state, we will bypass the axis2bram
            ENCODE: nxt_state = a2b_done ? IDLE : crt_state;

            AXI: nxt_state = a2b_done ? IDLE : crt_state;
        endcase
    end

    assign o_axi_rd_done = crt_state == IDLE;

    logic [AXI_ADDR_WIDTH-1:0] a2b_wr_addr_offset;

    assign a2b_wr_addr = a2b_wr_addr_offset + i_axi_rd_base_addr;

    axi_axi2bram #(
        .AXI_ADDR_WIDTH         ( AXI_ADDR_WIDTH            ),
        .AXI_DATA_WIDTH         ( AXI_DATA_WIDTH            ),
        .AXI_XFER_SIZE_WIDTH    ( AXI_XFER_SIZE_WIDTH       ),
        .BRAM_ADDR_WIDTH        ( AXI_ADDR_WIDTH            ),
        .BRAM_DELAY             ( NB_PIPE                   ),
        .INCLUDE_DATA_FIFO      ( INCLUDE_DATA_FIFO         )
    )
    i_axi2bram (
        .clk                    ( clk                       ),
        .rst_n                  ( rst_n                     ),
        .i_a2b_start            ( i_axi_rd_start            ),
        .o_a2b_done             ( a2b_done                  ),
        .i_a2b_ready            ( 1'b1                      ),
        .i_a2b_data_addr        ( data_ptr                  ),
        .i_a2b_data_size_bytes  ( data_size_bytes           ),
        .m_axi_arvalid          ( axi_arvalid               ),
        .m_axi_arready          ( axi_arready               ),
        .m_axi_araddr           ( axi_araddr                ),
        .m_axi_arlen            ( axi_arlen                 ),
        .m_axi_rvalid           ( axi_rvalid                ),
        .m_axi_rready           ( axi_rready                ),
        .m_axi_rdata            ( axi_rdata                 ),
        .m_axi_rlast            ( axi_rlast                 ),
        .o_a2b_wren             ( a2b_wr_en                 ),
        .o_a2b_wraddr           ( a2b_wr_addr_offset        ),
        .o_a2b_wrdata           ( a2b_wr_data               ),
        .o_axi_tdata            ( a2b_axis_tdata            ),
        .o_axi_tvalid           ( a2b_axis_tvalid           ),
        .i_axi_tready           ( a2b_axis_tready           ),
        .o_axi_tlast            ( a2b_axis_tlast            ),
        .i_as2b_bypass          ( as2b_bypass               )
    );

    assign as2b_bypass        = crt_state == ENCODE;
    assign encode_axis_tdata  = a2b_axis_tdata     & {AXI_DATA_WIDTH{as2b_bypass}};
    assign encode_axis_tvalid = a2b_axis_tvalid    & as2b_bypass;
    assign encode_axis_tlast  = a2b_axis_tlast     & as2b_bypass;
    assign a2b_axis_tready    = encode_axis_tready & as2b_bypass;

endmodule