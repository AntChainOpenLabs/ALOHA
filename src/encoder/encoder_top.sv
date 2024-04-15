//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: ENCODER
// Module Name: encoder_top
// Modify Date: 
//
// Description:
// encoder top
//////////////////////////////////////////////////
module encoder_top #(
    parameter AXI_DATA_WIDTH = 512,
    parameter AXI_ADDR_WIDTH = 10,
    parameter ST0_DATA_WIDTH = 64,
    parameter ST0_ADDR_WIDTH = 13,
    parameter ST1_ADDR_WIDTH = 12,
    parameter ST1_DATA_WIDTH = 68,
    parameter ST2_ADDR_WIDTH = 11,
    parameter ST2_DATA_WIDTH = 68,
    parameter ST3_ADDR_WIDTH = 7,
    parameter ST3_DATA_WIDTH = 64,
    parameter ST4_ADDR_WIDTH = 2,
    parameter ST4_DATA_WIDTH = 8192,
    parameter BRAM_LATENCY   = 1,
    parameter POLY_POWER     = 8192,
    parameter CHANNEL_NUM    = 4,
    parameter MOD_WIDTH      = 64,
    parameter MOD_0          = 64'd576460825317867521,
    parameter MOD_1          = 64'd576460924102115329,
    parameter SPM_ADDR_WIDTH = 14,
    parameter ID_WIDTH       = 11
) (
    input                               clk,
    input                               rst_n,

    // DMA
    input                               m_axis_tvalid,
    output logic                        m_axis_tready,
    input        [AXI_DATA_WIDTH-1:0]   m_axis_tdata,
    input                               m_axis_tlast,

    // ctrl
    input                               ctrl_start,
    input        [SPM_ADDR_WIDTH-1:0]   encode2spm_base_addr,
    input        [ID_WIDTH-1:0]         poly_id_i,
    output logic [ID_WIDTH-1:0]         poly_id_o,
    // SPM
    output logic [SPM_ADDR_WIDTH-1:0]   encode_wr_addr,
    output logic                        encode_wr_en,
    output logic [ST4_DATA_WIDTH-1:0]   encode_wr_data
);
    logic                          st0_sel;
    logic [AXI_ADDR_WIDTH-1:0]     st0_waddr;
    logic [AXI_DATA_WIDTH-1:0]     st0_wdata;
    logic                          st0_wen;
    logic [ST0_ADDR_WIDTH-1:0]     st0_raddr;
    logic                          st0_ren;
    logic [ST0_DATA_WIDTH-1:0]     st0_re;
    logic [ST0_DATA_WIDTH-1:0]     st0_im;

    logic                          st1_sel;
    logic [ST1_DATA_WIDTH-1:0]     st1_wdata;
    logic                          st1_wen;
    logic [ST1_ADDR_WIDTH-1:0]     st1_waddr;
    logic [ST1_ADDR_WIDTH-1:0]     st1_raddr;
    logic [ST1_DATA_WIDTH*4-1:0]   st1_rdata;
    logic                          rd_stage_ptr;

    logic                          st2_sel;
    logic [ST2_DATA_WIDTH*4-1:0]   st2_wdata;
    logic                          st2_wen;
    logic [ST2_ADDR_WIDTH-1:0]     st2_waddr;
    logic [ST2_ADDR_WIDTH-1:0]     st2_raddr;
    logic [ST2_DATA_WIDTH*4-1:0]   st2_rdata;

    logic [ST2_ADDR_WIDTH-1:0]     tf_raddr;
    logic [ST2_DATA_WIDTH*4-1:0]   tf_rdata  [CHANNEL_NUM];
    logic                          st3_sel;
    logic [ST3_DATA_WIDTH-1:0]     st3_wdata [CHANNEL_NUM];
    logic                          st3_wen;
    logic [ST3_ADDR_WIDTH-1:0]     st3_waddr;
    logic [ST4_ADDR_WIDTH-1:0]     st3_raddr;
    logic [ST4_DATA_WIDTH-1:0]     st3_rdata;

    controller #(
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .ST0_DATA_WIDTH (ST0_DATA_WIDTH),
        .ST0_ADDR_WIDTH (ST0_ADDR_WIDTH),
        .ST1_ADDR_WIDTH (ST1_ADDR_WIDTH),
        .ST1_DATA_WIDTH (ST1_DATA_WIDTH),
        .ST2_ADDR_WIDTH (ST2_ADDR_WIDTH),
        .ST2_DATA_WIDTH (ST2_DATA_WIDTH),
        .ST3_ADDR_WIDTH (ST3_ADDR_WIDTH),
        .ST3_DATA_WIDTH (ST3_DATA_WIDTH),
        .ST4_ADDR_WIDTH (ST4_ADDR_WIDTH),
        .ST4_DATA_WIDTH (ST4_DATA_WIDTH),
        .BRAM_LATENCY   (BRAM_LATENCY),
        .POLY_POWER     (POLY_POWER),
        .CHANNEL_NUM    (CHANNEL_NUM),
        .MOD_WIDTH      (MOD_WIDTH),
        .MOD_0          (MOD_0),
        .MOD_1          (MOD_1),
        .SPM_ADDR_WIDTH (SPM_ADDR_WIDTH),
        .ID_WIDTH       (ID_WIDTH)
    ) u_controller (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axis_tvalid  (m_axis_tvalid),
        .s_axis_tready  (m_axis_tready),
        .s_axis_tdata   (m_axis_tdata),
        .s_axis_tlast   (m_axis_tlast),
        .st0_sel        (st0_sel),
        .st0_waddr      (st0_waddr),
        .st0_wdata      (st0_wdata),
        .st0_wen        (st0_wen),
        .st0_raddr      (st0_raddr),
        .st0_re         (st0_re),
        .st0_im         (st0_im),
        .st1_sel        (st1_sel),
        .st1_wdata      (st1_wdata),
        .st1_wen        (st1_wen),
        .st1_waddr      (st1_waddr),
        .st1_raddr      (st1_raddr),
        .rd_stage_ptr   (rd_stage_ptr),
        .st1_rdata      (st1_rdata),
        .st2_sel        (st2_sel),
        .st2_wdata      (st2_wdata),
        .st2_wen        (st2_wen),
        .st2_waddr      (st2_waddr),
        .st2_raddr      (st2_raddr),
        .st2_rdata      (st2_rdata),
        .tf_raddr       (tf_raddr),
        .tf_rdata       (tf_rdata),
        .st3_sel        (st3_sel),
        .st3_wdata      (st3_wdata),
        .st3_wen        (st3_wen),
        .st3_waddr      (st3_waddr),
        .st3_raddr      (st3_raddr),
        .st3_rdata      (st3_rdata),
        .ctrl_start     (ctrl_start),
        .encode2spm_base_addr(encode2spm_base_addr),
        .poly_id_i      (poly_id_i),
        .poly_id_o      (poly_id_o),
        .encode_wr_addr (encode_wr_addr),
        .encode_wr_en   (encode_wr_en),
        .encode_wr_data (encode_wr_data)
    );

    pp_st0 #(
        .IN_DATA_WIDTH   (AXI_DATA_WIDTH),
        .IN_ADDR_WIDTH   (AXI_ADDR_WIDTH),
        .OUT_DATA_WIDTH  (ST0_DATA_WIDTH),
        .OUT_ADDR_WIDTH  (ST0_ADDR_WIDTH),
        .LATENCY         (BRAM_LATENCY),
        .BANK_NUM        (8),
        .STAGE           (0)
    ) u_pp_st0 (
        .clk             (clk),
        .rst_n           (rst_n),
        .st0_sel         (st0_sel),
        .st0_waddr       (st0_waddr),
        .st0_wdata       (st0_wdata),
        .st0_wen         (st0_wen),
        .st0_raddr       (st0_raddr),
        .st0_ren         (st0_ren),
        .st0_re          (st0_re),
        .st0_im          (st0_im)
    );

    pp_st1 #(
        .DATA_WIDTH      (ST1_DATA_WIDTH),
        .ADDR_WIDTH      (ST1_ADDR_WIDTH),
        .LATENCY         (BRAM_LATENCY),
        .BANK_NUM        (4),
        .STAGE           (1)
    ) u_pp_st1 (
        .clk             (clk),
        .rst_n           (rst_n),
        .st1_sel         (st1_sel),
        .st1_wdata       (st1_wdata),
        .st1_wen         (st1_wen),
        .st1_waddr       (st1_waddr),
        .st1_raddr       (st1_raddr),
        .rd_stage_ptr    (rd_stage_ptr),
        .st1_rdata       (st1_rdata)
    );

    pp_st2 #(
        .DATA_WIDTH     (ST2_DATA_WIDTH),
        .ADDR_WIDTH     (ST2_ADDR_WIDTH),
        .LATENCY        (BRAM_LATENCY),
        .BANK_NUM       (4),
        .STAGE          (2)
    ) u_pp_st2 (
        .clk            (clk),
        .rst_n          (rst_n),
        .st2_sel        (st2_sel),
        .st2_wdata      (st2_wdata),
        .st2_wen        (st2_wen),
        .st2_waddr      (st2_waddr),
        .st2_raddr      (st2_raddr),
        .st2_rdata      (st2_rdata)
    );

    pp_st3 #(
        .IN_DATA_WIDTH  (ST3_DATA_WIDTH),
        .OUT_DATA_WIDTH (ST4_DATA_WIDTH),
        .CHANNEL_NUM    (CHANNEL_NUM),
        .IN_ADDR_WIDTH  (ST3_ADDR_WIDTH),
        .OUT_ADDR_WIDTH (ST4_ADDR_WIDTH),
        .LATENCY        (BRAM_LATENCY),
        .STAGE          (3)
    ) u_pp_st3 (
        .clk            (clk),
        .rst_n          (rst_n),
        .st3_sel        (st3_sel),
        .st3_wdata      (st3_wdata),
        .st3_wen        (st3_wen),
        .st3_waddr      (st3_waddr),
        .st3_raddr      (st3_raddr),
        .st3_rdata      (st3_rdata)
    );

    tf_buf #(
        .DATA_WIDTH     (ST2_DATA_WIDTH),
        .ADDR_WIDTH     (ST2_ADDR_WIDTH),
        .LATENCY        (BRAM_LATENCY),
        .CHANNEL_NUM    (4)
    ) u_tf_buf (
        .clk            (clk),
        .raddr          (tf_raddr),
        .rdata          (tf_rdata)
    );

endmodule : encoder_top

