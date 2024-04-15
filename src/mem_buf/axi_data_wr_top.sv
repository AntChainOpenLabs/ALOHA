module axi_data_wr_top #(
    parameter AXI_ADDR_WIDTH = 64,
    parameter AXI_DATA_WIDTH = 512,
    parameter AXI_XFER_SIZE_WIDTH = 32,
    parameter INCLUDE_DATA_FIFO = 0,
    parameter NB_PIPE = 1

) (
    // System Signals
    input   logic   clk,
    input   logic   rst_n,

    // AXI4 Interfaces for Output Data
    output  logic                               axi_awvalid,
    input   logic                               axi_awready,
    output  logic   [AXI_ADDR_WIDTH-1:0]        axi_awaddr,
    output  logic   [7:0]                       axi_awlen,

    output  logic                               axi_wvalid,
    input   logic                               axi_wready,
    output  logic   [AXI_DATA_WIDTH-1:0]        axi_wdata,
    output  logic   [AXI_DATA_WIDTH/8-1:0]      axi_wstrb,
    output  logic                               axi_wlast,

    input   logic                               axi_bvalid,
    output  logic                               axi_bready,

    // Control Signals
    input   logic                               i_axi_wr_start,
    output  logic                               o_axi_wr_done,
    input   logic   [AXI_ADDR_WIDTH-1:0]        i_axi_wr_base_addr,

    input   logic   [AXI_ADDR_WIDTH-1:0]        data_ptr,
    input   logic   [AXI_XFER_SIZE_WIDTH-1:0]   data_size_bytes,

    output  logic   [AXI_ADDR_WIDTH-1:0]        wr_rdaddr,
    input   logic   [AXI_DATA_WIDTH-1:0]        wr_rddata,
    output  logic                               wr_rden
);
    typedef enum logic { IDLE, DATA } fsm_t;
    fsm_t crt_state, nxt_state;
    logic b2a_start, b2a_done;

    always_comb begin
        nxt_state = crt_state;
        case (crt_state)
            IDLE: nxt_state = i_axi_wr_start ? DATA : IDLE;
            DATA: nxt_state = b2a_done ? IDLE : DATA;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n)
            crt_state <= IDLE;
        else
            crt_state <= nxt_state;
    end

    assign o_axi_wr_done = (crt_state == IDLE);
    assign b2a_start = i_axi_wr_start;

    logic [AXI_ADDR_WIDTH-1:0] wr_rdaddr_offset;

    assign wr_rdaddr = wr_rdaddr_offset + i_axi_wr_base_addr;

    axi_bram2axi #(
        .AXI_ADDR_WIDTH         ( AXI_ADDR_WIDTH            ),
        .AXI_DATA_WIDTH         ( AXI_DATA_WIDTH            ),
        .AXI_XFER_SIZE_WIDTH    ( AXI_XFER_SIZE_WIDTH       ),
        .BRAM_DELAY             ( NB_PIPE                   ),
        .BRAM_ADDR_WIDTH        ( AXI_ADDR_WIDTH            ),
        .INCLUDE_DATA_FIFO      ( INCLUDE_DATA_FIFO         )
    )
    i_bram2axi (
        .clk                    ( clk                       ),
        .rst_n                  ( rst_n                     ),
        .i_b2a_start            ( b2a_start                 ),
        .o_b2a_done             ( b2a_done                  ),
        .i_b2a_data_addr        ( data_ptr                  ),
        .i_b2a_data_size_bytes  ( data_size_bytes           ),
        .m_axi_awvalid          ( axi_awvalid               ),
        .m_axi_awready          ( axi_awready               ),
        .m_axi_awaddr           ( axi_awaddr                ),
        .m_axi_awlen            ( axi_awlen                 ),
        .m_axi_wvalid           ( axi_wvalid                ),
        .m_axi_wready           ( axi_wready                ),
        .m_axi_wdata            ( axi_wdata                 ),
        .m_axi_wstrb            ( axi_wstrb                 ),
        .m_axi_wlast            ( axi_wlast                 ),
        .m_axi_bvalid           ( axi_bvalid                ),
        .m_axi_bready           ( axi_bready                ),
        .o_b2a_rdaddr           ( wr_rdaddr_offset          ),
        .i_b2a_rddata           ( wr_rddata                 ),
        .o_b2a_rden             ( wr_rden                   )
    );

endmodule