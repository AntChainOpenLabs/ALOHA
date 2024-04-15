module mem_top #(
    parameter URAM_ADDR_WIDTH       = 12,
    parameter BANK_NUM              = 4,
    parameter SPM_ADDR_WIDTH        = $clog2(BANK_NUM) + URAM_ADDR_WIDTH,
    parameter NUM_LANE              = 128,
    parameter DATA_WIDTH            = 64,
    parameter NB_PIPE               = 2,
    parameter AXI_ADDR_WIDTH        = 64,
    parameter AXI_DATA_WIDTH        = 512,
    parameter AXI_XFER_SIZE_WIDTH   = 32,
    parameter INCLUDE_DATA_FIFO     = 0
) (
    input                       clk,
    input                       rst_n,

    // to ddr
    output  logic                          axi_awvalid,
    input   logic                          axi_awready,
    output  logic [AXI_ADDR_WIDTH-1:0]     axi_awaddr,
    output  logic [7:0]                    axi_awlen,
    output  logic                          axi_wvalid,
    input   logic                          axi_wready,
    output  logic [AXI_DATA_WIDTH-1:0]     axi_wdata,
    output  logic [AXI_DATA_WIDTH/8-1:0]   axi_wstrb,
    output  logic                          axi_wlast,
    input   logic                          axi_bvalid,
    output  logic                          axi_bready,
    output  logic                          axi_arvalid,
    input   logic                          axi_arready,
    output  logic [AXI_ADDR_WIDTH-1:0]     axi_araddr,
    output  logic [7:0]                    axi_arlen,
    input   logic                          axi_rvalid,
    output  logic                          axi_rready,
    input   logic [AXI_DATA_WIDTH-1:0]     axi_rdata,
    input   logic                          axi_rlast,

    // from arm
    input   logic [31:0]                   axi_cfg_awaddr,
    input   logic                          axi_cfg_awvalid,
    output  logic                          axi_cfg_awready,
    input   logic [31:0]                   axi_cfg_wdata,
    input   logic [3:0]                    axi_cfg_wstrb,
    input   logic                          axi_cfg_wvalid,
    output  logic                          axi_cfg_wready,
    output  logic [1:0]                    axi_cfg_bresp,
    output  logic                          axi_cfg_bvalid,
    input   logic                          axi_cfg_bready,
    input   logic [31:0]                   axi_cfg_araddr,
    input   logic                          axi_cfg_arvalid,
    output  logic                          axi_cfg_arready,
    output  logic [31:0]                   axi_cfg_rdata,
    output  logic [1:0]                    axi_cfg_rresp,
    output  logic                          axi_cfg_rvalid,
    input   logic                          axi_cfg_rready,

    // from encoder
    input   logic                          i_encode_wr_en,
    input   logic [SPM_ADDR_WIDTH-1:0]     i_encode_wr_addr,
    input   logic [NUM_LANE*DATA_WIDTH-1:0]i_encode_wr_data,
    input   logic [10:0]                   poly_id_o,

    // to encoder
    output  logic                          encode_axis_tvalid,
    input   logic                          encode_axis_tready,
    output  logic                          encode_axis_tlast,
    output  logic [AXI_DATA_WIDTH-1:0]     encode_axis_tdata,
    output  logic [SPM_ADDR_WIDTH-1:0]     encode2spm_base_addr,
    output  logic                          encode_cfg_start,
    output  logic [10:0]                   poly_id_i,

    // from vp
    input   logic [SPM_ADDR_WIDTH-1:0]     i_vp_rd_addr,
    input   logic                          i_vp_wr_en,
    input   logic [SPM_ADDR_WIDTH-1:0]     i_vp_wr_addr,
    input   logic [NUM_LANE*DATA_WIDTH-1:0]i_vp_wr_data,
    output  logic [NUM_LANE*DATA_WIDTH-1:0]o_vp_rd_data,

    // to ksk
    output  logic                          o_ksk_wr_en,
    output  logic [AXI_ADDR_WIDTH-1:0]     o_ksk_addr,
    output  logic [AXI_DATA_WIDTH-1:0]     o_ksk_wr_data
);

    logic                               i_axi_en;
    logic [AXI_ADDR_WIDTH-1:0]          axi_rd_wraddr;
    logic [AXI_DATA_WIDTH-1:0]          axi_rd_wrdata;
    logic                               axi_rd_wren;
    logic [AXI_ADDR_WIDTH-1:0]          axi_wr_rdaddr;
    logic [AXI_DATA_WIDTH-1:0]          axi_wr_rddata;
    logic                               axi_wr_rden;
    logic [NUM_LANE*DATA_WIDTH-1:0]     o_axi_rd_data;

    logic [AXI_ADDR_WIDTH-1:0]          rd_ptr;
    logic [AXI_XFER_SIZE_WIDTH-1:0]     rd_size_bytes;
    logic                               rd_done;
    logic [31:0]                        rd_command;
    logic                               rd_start;
    logic [AXI_ADDR_WIDTH-1:0]          rd_base_addr;

    logic                               wr_start;
    logic                               wr_done;
    logic [AXI_ADDR_WIDTH-1:0]          wr_base_addr;
    logic [AXI_ADDR_WIDTH-1:0]          wr_ptr;
    logic [AXI_XFER_SIZE_WIDTH-1:0]     wr_size_bytes;

    logic [AXI_ADDR_WIDTH-1:0]          base_addr;
    logic [AXI_ADDR_WIDTH-1:0]          data_ptr;
    logic [AXI_XFER_SIZE_WIDTH-1:0]     data_size_bytes;
    logic                               rd_start_r;
    logic                               wr_start_r;
    logic                               rd_pedge_start;
    logic                               rd_pedge_start_r;
    logic                               wr_pedge_start;
    logic                               wr_pedge_start_r;

    logic [AXI_ADDR_WIDTH-1:0]          rd_wraddr;
    logic [AXI_DATA_WIDTH-1:0]          rd_wrdata;

    assign i_axi_en = axi_wr_rden | axi_rd_wren;

    axi_data_rd_top #(
        .AXI_ADDR_WIDTH      (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH      (AXI_DATA_WIDTH),
        .AXI_XFER_SIZE_WIDTH (AXI_XFER_SIZE_WIDTH),
        .INCLUDE_DATA_FIFO   (INCLUDE_DATA_FIFO),
        .NB_PIPE             (NB_PIPE)
    ) u_axi_data_rd_top (
        .clk                (clk),
        .rst_n              (rst_n),
        .axi_arvalid        (axi_arvalid),
        .axi_arready        (axi_arready),
        .axi_araddr         (axi_araddr),
        .axi_arlen          (axi_arlen),
        .axi_rvalid         (axi_rvalid),
        .axi_rready         (axi_rready),
        .axi_rdata          (axi_rdata),
        .axi_rlast          (axi_rlast),
        .i_axi_rd_command   (rd_command),
        .i_axi_rd_start     (rd_start),
        .o_axi_rd_done      (rd_done),
        .i_axi_rd_base_addr (base_addr),
        .data_ptr           (data_ptr),
        .data_size_bytes    (data_size_bytes),
        .ksk_wr_en          (o_ksk_wr_en),
        .axi_wr_en          (axi_rd_wren),
        .rd_wraddr          (rd_wraddr),
        .rd_wrdata          (rd_wrdata),
        .encode_axis_tdata  (encode_axis_tdata),
        .encode_axis_tvalid (encode_axis_tvalid),
        .encode_axis_tlast  (encode_axis_tlast),
        .encode_axis_tready (encode_axis_tready)
    );

    axi_data_wr_top #(
        .AXI_ADDR_WIDTH      (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH      (AXI_DATA_WIDTH),
        .AXI_XFER_SIZE_WIDTH (AXI_XFER_SIZE_WIDTH),
        .INCLUDE_DATA_FIFO   (INCLUDE_DATA_FIFO),
        .NB_PIPE             (NB_PIPE)
    ) u_axi_data_wr_top (
        .clk               (clk),
        .rst_n             (rst_n),
        .axi_awvalid       (axi_awvalid),
        .axi_awready       (axi_awready),
        .axi_awaddr        (axi_awaddr),
        .axi_awlen         (axi_awlen),
        .axi_wvalid        (axi_wvalid),
        .axi_wready        (axi_wready),
        .axi_wdata         (axi_wdata),
        .axi_wstrb         (axi_wstrb),
        .axi_wlast         (axi_wlast),
        .axi_bvalid        (axi_bvalid),
        .axi_bready        (axi_bready),
        .i_axi_wr_start    (wr_start),
        .o_axi_wr_done     (wr_done),
        .i_axi_wr_base_addr(base_addr),
        .data_ptr          (data_ptr),
        .data_size_bytes   (data_size_bytes),
        .wr_rdaddr         (axi_wr_rdaddr),
        .wr_rddata         (axi_wr_rddata),
        .wr_rden           (axi_wr_rden)
    );

    spm #(
        .URAM_ADDR_WIDTH   (URAM_ADDR_WIDTH),
        .BANK_NUM          (BANK_NUM),
        .NUM_LANE          (NUM_LANE),
        .DATA_WIDTH        (DATA_WIDTH),
        .NB_PIPE           (NB_PIPE),
        .AXI_ADDR_WIDTH    (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH    (AXI_DATA_WIDTH)
    ) u_spm (
        .clk              (clk),
        .rst_n            (rst_n),
        .i_vp_rd_addr     (i_vp_rd_addr),
        .i_vp_wr_en       (i_vp_wr_en),
        .i_vp_wr_addr     (i_vp_wr_addr),
        .i_vp_wr_data     (i_vp_wr_data),
        .o_vp_rd_data     (o_vp_rd_data),
        .i_axi_wr_en      (axi_rd_wren),
        .i_axi_en         (i_axi_en),
        .i_axi_addr       (axi_rd_wren ? axi_rd_wraddr : axi_wr_rdaddr),
        .i_axi_wr_data    (axi_rd_wrdata),
        .o_axi_rd_data    (axi_wr_rddata),
        .i_encode_wr_en   (i_encode_wr_en),
        .i_encode_wr_addr (i_encode_wr_addr),
        .i_encode_wr_data (i_encode_wr_data)
    );

    axil_parse #(
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(32)
    ) u_axil_parse (
        .clk                   (clk),
        .rst_n                 (rst_n),
        .clk_en                (1'b1),
        .awaddr                (axi_cfg_awaddr),
        .awvalid               (axi_cfg_awvalid),
        .awready               (axi_cfg_awready),
        .wdata                 (axi_cfg_wdata),
        .wstrb                 (axi_cfg_wstrb),
        .wvalid                (axi_cfg_wvalid),
        .wready                (axi_cfg_wready),
        .bresp                 (axi_cfg_bresp),
        .bvalid                (axi_cfg_bvalid),
        .bready                (axi_cfg_bready),
        .araddr                (axi_cfg_araddr),
        .arvalid               (axi_cfg_arvalid),
        .arready               (axi_cfg_arready),
        .rdata                 (axi_cfg_rdata),
        .rresp                 (axi_cfg_rresp),
        .rvalid                (axi_cfg_rvalid),
        .rready                (axi_cfg_rready),
        // .axi_wr_start          (wr_start),
        // .axi_rd_start          (rd_start),
        // .axi_wr_done           (wr_done),
        // .axi_rd_done           (rd_done),
        // .poly_id_o             (poly_id_o),
        // .axi_rd_command        (rd_command),
        // .base_addr             (base_addr),
        // .data_ptr              (data_ptr),
        // .data_size_bytes       (data_size_bytes),
        // .encode_base_addr      (encode2spm_base_addr),
        // .poly_id_i             (poly_id_i)
        .axi_wr_start          (wr_start),
        .axi_rd_start          (rd_start),
        .axi_wr_done           (wr_done),
        .axi_rd_done           (rd_done),
        .poly_id_o             (poly_id_o),
        .axi_rd_command        (rd_command),
        .base_addr             (base_addr),
        .data_ptr              (data_ptr),
        .data_size_bytes       (data_size_bytes),
        .encode_base_addr      (encode2spm_base_addr),
        .poly_id_i             (poly_id_i),
        .i_vp_done             ('0),
        .o_vp_pc               (),
        .o_vp_start            (),
        .o_csr_vp_src0_ptr     (),
        .o_csr_vp_src1_ptr     (),
        .o_csr_vp_rslt_ptr     (),
        .o_csr_vp_rot_step     ()
    );

    ksk_mem #(
        .DATA_WIDTH      (DATA_WIDTH),
        .NUM_LANE        (NUM_LANE),
        .NB_PIPE         (NB_PIPE),
        .KSK_MEM_DEPTH   (9216),
        .AXI_DATA_WIDTH  (AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH  (AXI_ADDR_WIDTH)
    ) u_ksk_mem (
        .clk             (clk),
        .rst_n           (rst_n),
        .i_vp_rd_addr    (),
        .i_vp_rd_en      (),
        .o_vp_rd_data    (),
        .i_axi_wr_en     (),//o_ksk_wr_en),
        .i_axi_addr      (),//o_ksk_addr),
        .i_axi_wr_data   ()//o_ksk_wr_data)
    );

    assign axi_rd_wraddr  = rd_wraddr,
            o_ksk_addr    = rd_wraddr;
    assign axi_rd_wrdata  = rd_wrdata,
            o_ksk_wr_data = rd_wrdata;

    assign encode_cfg_start = rd_start & (rd_command == 'd2);

endmodule