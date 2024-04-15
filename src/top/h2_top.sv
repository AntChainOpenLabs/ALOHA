`include "vp_defines.vh"
`include "common_defines.vh"

module h2_top #(
    parameter URAM_ADDR_WIDTH       = 12,
    parameter BANK_NUM              = 4,
    parameter SPM_ADDR_WIDTH        = $clog2(BANK_NUM) + URAM_ADDR_WIDTH,
    parameter KSK_MEM_DEPTH         = 9216,
    parameter KSK_ADDR_WIDTH        = $clog2(KSK_MEM_DEPTH),
    parameter NUM_LANE              = 128,
    parameter DATA_WIDTH            = 64,
    parameter NB_PIPE               = `COMMON_MEMR_DELAY,
    parameter AXI_ADDR_WIDTH        = 64,
    parameter AXI_DATA_WIDTH        = 512,
    parameter AXI_XFER_SIZE_WIDTH   = 32,
    parameter INCLUDE_DATA_FIFO     = 0,

    parameter ST0_ADDR_WIDTH        = 13,
    parameter ST0_DATA_WIDTH        = 64,
    parameter ST1_ADDR_WIDTH        = 12,
    parameter ST1_DATA_WIDTH        = 68,
    parameter ST2_DATA_WIDTH        = 68,
    parameter ST2_ADDR_WIDTH        = 11,
    parameter POLY_POWER            = 8192,
    parameter CHANNEL_NUM           = 4,
    parameter MOD_WIDTH             = 64,
    parameter ST3_ADDR_WIDTH        = 7,
    parameter ST3_DATA_WIDTH        = 64,
    parameter ST4_ADDR_WIDTH        = 2,
    parameter ST4_DATA_WIDTH        = 8192,
    parameter MOD_0                 = 64'd576460825317867521,
    parameter MOD_1                 = 64'd576460924102115329,
    parameter ISRAM_FILE            = "isram_file.mem",
    parameter TF_ROM_FILE           = "tf_rom"
) (
    input                   clk,
    input                   rst_n,

    // to ddr
    output  logic                          axi_awvalid,
    input   logic                          axi_awready,
    output  logic [11:0]                   axi_awid,
    output  logic [AXI_ADDR_WIDTH-1:0]     axi_awaddr,
    output  logic [7:0]                    axi_awlen,
    output  logic [2:0]                    axi_awsize,
    output  logic [1:0]                    axi_awburst,
    output  logic                          axi_awlock,
    output  logic [3:0]                    axi_awcache,
    output  logic [2:0]                    axi_awprot,
    output  logic                          axi_wvalid,
    input   logic                          axi_wready,
    output  logic [AXI_DATA_WIDTH-1:0]     axi_wdata,
    output  logic [AXI_DATA_WIDTH/8-1:0]   axi_wstrb,
    output  logic                          axi_wlast,
    input   logic                          axi_bvalid,
    output  logic                          axi_bready,
    output  logic                          axi_arvalid,
    input   logic                          axi_arready,
    output  logic [11:0]                   axi_arid,
    output  logic [AXI_ADDR_WIDTH-1:0]     axi_araddr,
    output  logic [7:0]                    axi_arlen,
    output  logic [2:0]                    axi_arsize,
    output  logic [1:0]                    axi_arburst,
    output  logic                          axi_arlock,
    output  logic [3:0]                    axi_arcache,
    output  logic [2:0]                    axi_arprot,
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
    input   logic                          axi_cfg_rready
);
    localparam ID_WIDTH = 11;
    logic                                           start_vp;
    logic                                           done_vp;

    logic[`INST_WIDTH - 1:0]                        vp_inst;
    logic                                           vp_rden;
    logic                                           vp_wren;
    logic[`SYS_SPM_ADDR_WIDTH - 1:0]                vp_rdaddr;
    logic[`SYS_SPM_ADDR_WIDTH - 1:0]                vp_wraddr;
    logic[`SYS_NUM_LANE * `LANE_DATA_WIDTH - 1:0]   vp_wrdata;
    logic[`SCALAR_WIDTH - 1:0]                      csr_vp_src0_ptr;
    logic[`SCALAR_WIDTH - 1:0]                      csr_vp_src1_ptr;
    logic[`SCALAR_WIDTH - 1:0]                      csr_vp_rslt_ptr;
    logic[`SCALAR_WIDTH - 1:0]                      csr_vp_step;
    logic[`SCALAR_WIDTH - 1:0]                      csr_vp_pc;


    logic [AXI_ADDR_WIDTH-1:0]          axi_rd_wraddr;
    logic [AXI_DATA_WIDTH-1:0]          axi_rd_wrdata;
    logic                               axi_rd_wren;
    logic [AXI_ADDR_WIDTH-1:0]          axi_wr_rdaddr;
    logic [AXI_DATA_WIDTH-1:0]          axi_wr_rddata;
    logic                               axi_wr_rden;

    logic                               rd_done;
    logic [31:0]                        rd_command;
    logic                               rd_start;
    logic                               wr_start;
    logic                               wr_done;
    logic [AXI_ADDR_WIDTH-1:0]          base_addr;
    logic [AXI_ADDR_WIDTH-1:0]          data_ptr;
    logic [AXI_XFER_SIZE_WIDTH-1:0]     data_size_bytes;
    logic                               rd_start_r;
    logic                               wr_start_r;
    logic                               rd_pedge_start;
    logic                               wr_pedge_start;

    logic [AXI_ADDR_WIDTH-1:0]          rd_wraddr;
    logic [AXI_DATA_WIDTH-1:0]          rd_wrdata;

    logic [ID_WIDTH-1:0]                poly_id_i;
    logic [ID_WIDTH-1:0]                poly_id_o;
    logic                               encode_wr_en;
    logic [SPM_ADDR_WIDTH-1:0]          encode_wr_addr;
    logic [NUM_LANE*DATA_WIDTH-1:0]     encode_wr_data;

    logic                               encode_axis_tvalid;
    logic                               encode_axis_tready;
    logic                               encode_axis_tlast;
    logic [AXI_DATA_WIDTH-1:0]          encode_axis_tdata;
    logic [SPM_ADDR_WIDTH-1:0]          ecd2spm_base_addr;
    logic [31:0]                        encode_base_addr;
    logic                               encode_cfg_start;

    logic                               ksk_wr_en;
    logic [AXI_ADDR_WIDTH-1:0]          ksk_addr;
    logic [AXI_DATA_WIDTH-1:0]          ksk_wr_data;

    logic                               ksk_rd_en;
    logic [`SYS_KSK_ADDR_WIDTH - 1:0]   ksk_rd_addr;
    logic [`SYS_NUM_LANE * `LANE_DATA_WIDTH - 1:0] ksk_rd_data;
    logic[`SYS_NUM_LANE * `LANE_DATA_WIDTH - 1:0]   spm_vp_rddata;

    assign axi_awid = 'd0;
    assign axi_awsize = 'd6;
    assign axi_awburst = 'd1;
    assign axi_awcache = 'd3;
    assign axi_awlock = 'd0;
    assign axi_awprot = 'd0;
    assign axi_arid = 'd0;
    assign axi_arsize = 'd6;
    assign axi_arburst = 'd1;
    assign axi_arcache = 'd3;
    assign axi_arlock = 'd0;
    assign axi_arprot = 'd0;

    vp_top_full #(
        .ISRAM_FILE(ISRAM_FILE),
        .TF_ROM_FILE(TF_ROM_FILE)
    )u_vp_top (
        .clk                 (clk),
        .rst_n               (rst_n),
        .i_start_vp          (start_vp),
        .o_done_vp           (done_vp),
        .o_vp_rden           (vp_rden),
        .o_vp_wren           (vp_wren),
        .o_vp_rdaddr         (vp_rdaddr),
        .o_vp_wraddr         (vp_wraddr),
        .i_vp_data           (spm_vp_rddata),
        .o_vp_data           (vp_wrdata),
        .o_vp_ksk_rden       (ksk_rd_en),
        .o_vp_ksk_rdaddr     (ksk_rd_addr),
        .i_vp_ksk_data       (ksk_rd_data),
        .i_csr_vp_src0_ptr   (csr_vp_src0_ptr),
        .i_csr_vp_src1_ptr   (csr_vp_src1_ptr),
        .i_csr_vp_rslt_ptr   (csr_vp_rslt_ptr),
        .i_csr_vp_step       (csr_vp_step),
        .i_csr_vp_pc         (csr_vp_pc)
    );

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
        .i_axi_rd_start     (rd_pedge_start),
        .o_axi_rd_done      (rd_done),
        .i_axi_rd_base_addr (base_addr),
        .data_ptr           (data_ptr),
        .data_size_bytes    (data_size_bytes),
        .ksk_wr_en          (ksk_wr_en),
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
        .i_axi_wr_start    (wr_pedge_start),
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
        .i_vp_rd_addr     (vp_rdaddr[SPM_ADDR_WIDTH - 1:0]),
        .i_vp_wr_en       (vp_wren),
        .i_vp_wr_addr     (vp_wraddr[SPM_ADDR_WIDTH - 1:0]),
        .i_vp_wr_data     (vp_wrdata),
        .o_vp_rd_data     (spm_vp_rddata),
        .i_axi_wr_en      (axi_rd_wren),
        .i_axi_en         (axi_rd_wren || axi_wr_rden),
        .i_axi_addr       (axi_rd_wren ? axi_rd_wraddr : axi_wr_rdaddr),
        .i_axi_wr_data    (axi_rd_wrdata),
        .o_axi_rd_data    (axi_wr_rddata),
        .i_encode_wr_en   (encode_wr_en),
        .i_encode_wr_addr (encode_wr_addr),
        .i_encode_wr_data (encode_wr_data)
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
        .axi_wr_start          (wr_start),
        .axi_rd_start          (rd_start),
        .axi_wr_done           (wr_done),
        .axi_rd_done           (rd_done),
        .poly_id_o             (poly_id_o),
        .axi_rd_command        (rd_command),
        .base_addr             (base_addr),
        .data_ptr              (data_ptr),
        .data_size_bytes       (data_size_bytes),
        .encode_base_addr      (encode_base_addr),
        .poly_id_i             (poly_id_i),
        .i_vp_done             (done_vp),
        .o_vp_pc               (csr_vp_pc[31:0]),
        .o_vp_start            (start_vp),
        .o_csr_vp_src0_ptr     (csr_vp_src0_ptr[31:0]),
        .o_csr_vp_src1_ptr     (csr_vp_src1_ptr[31:0]),
        .o_csr_vp_rslt_ptr     (csr_vp_rslt_ptr[31:0]),
        .o_csr_vp_rot_step     (csr_vp_step[31:0])
    );

    assign ecd2spm_base_addr = encode_base_addr[SPM_ADDR_WIDTH - 1:0];
    assign csr_vp_pc[`SCALAR_WIDTH - 1:32] = 'b0;
    assign csr_vp_src0_ptr[`SCALAR_WIDTH - 1:32] = 'b0;
    assign csr_vp_src1_ptr[`SCALAR_WIDTH - 1:32] = 'b0;
    assign csr_vp_rslt_ptr[`SCALAR_WIDTH - 1:32] = 'b0;
    assign csr_vp_step[`SCALAR_WIDTH - 1:32] = 'b0;

    ksk_mem #(
        .DATA_WIDTH      (DATA_WIDTH),
        .NUM_LANE        (NUM_LANE),
        .NB_PIPE         (NB_PIPE),
        .KSK_MEM_DEPTH   (KSK_MEM_DEPTH),
        .AXI_DATA_WIDTH  (AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH  (AXI_ADDR_WIDTH)
    ) u_ksk_mem (
        .clk             (clk),
        .rst_n           (rst_n),
        .i_vp_rd_addr    (ksk_rd_addr[KSK_ADDR_WIDTH - 1:0]),
        .i_vp_rd_en      (ksk_rd_en),
        .o_vp_rd_data    (ksk_rd_data),
        .i_axi_wr_en     (ksk_wr_en),
        .i_axi_addr      (ksk_addr),
        .i_axi_wr_data   (ksk_wr_data)
    );

    encoder_top #(
        .AXI_DATA_WIDTH     (AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH     (10),
        .ST0_DATA_WIDTH     (ST0_DATA_WIDTH),
        .ST0_ADDR_WIDTH     (ST0_ADDR_WIDTH),
        .ST1_ADDR_WIDTH     (ST1_ADDR_WIDTH),
        .ST1_DATA_WIDTH     (ST1_DATA_WIDTH),
        .ST2_ADDR_WIDTH     (ST2_ADDR_WIDTH),
        .ST2_DATA_WIDTH     (ST2_DATA_WIDTH),
        .ST3_ADDR_WIDTH     (ST3_ADDR_WIDTH),
        .ST3_DATA_WIDTH     (ST3_DATA_WIDTH),
        .ST4_ADDR_WIDTH     (ST4_ADDR_WIDTH),
        .ST4_DATA_WIDTH     (ST4_DATA_WIDTH),
        .MOD_0              (MOD_0),
        .MOD_1              (MOD_1),
        .BRAM_LATENCY       (NB_PIPE),
        .POLY_POWER         (POLY_POWER),
        .CHANNEL_NUM        (CHANNEL_NUM),
        .MOD_WIDTH          (MOD_WIDTH),
        .SPM_ADDR_WIDTH     (SPM_ADDR_WIDTH),
        .ID_WIDTH           (ID_WIDTH)
    ) u_encoder_top (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .m_axis_tvalid          (encode_axis_tvalid),
        .m_axis_tready          (encode_axis_tready),
        .m_axis_tdata           (encode_axis_tdata),
        .m_axis_tlast           (encode_axis_tlast),
        .ctrl_start             (encode_cfg_start),
        .encode2spm_base_addr   (ecd2spm_base_addr),
        .poly_id_i              (poly_id_i),
        .poly_id_o              (poly_id_o),
        .encode_wr_addr         (encode_wr_addr),
        .encode_wr_en           (encode_wr_en),
        .encode_wr_data         (encode_wr_data)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rd_start_r <= '0;
            wr_start_r <= '0;
        end
        else begin
            rd_start_r <= rd_start;
            wr_start_r <= wr_start;
        end
    end

    assign rd_pedge_start = ~rd_start_r & rd_start;
    assign wr_pedge_start = ~wr_start_r & wr_start;

    assign axi_rd_wraddr  = rd_wraddr,
            ksk_addr    = rd_wraddr;
    assign axi_rd_wrdata  = rd_wrdata,
            ksk_wr_data = rd_wrdata;

    assign encode_cfg_start = rd_pedge_start & (rd_command == 'd2);


endmodule