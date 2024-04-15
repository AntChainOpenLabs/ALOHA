//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: ENCODER
// Module Name: controller
// Modify Date: 
//
// Description:
// encoder controller
//////////////////////////////////////////////////
module controller #(
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
    parameter MOD_0          = 64'd576460825317867521,
    parameter MOD_1          = 64'd576460924102115329,
    parameter BRAM_LATENCY   = 1,
    parameter POLY_POWER     = 8192,
    parameter CHANNEL_NUM    = 4,
    parameter MOD_WIDTH      = 64,
    parameter SPM_ADDR_WIDTH = 14,
    parameter ID_WIDTH       = 11
) (
    input                               clk,
    input                               rst_n,

    // dma
    input                               s_axis_tvalid,
    output                              s_axis_tready,
    input        [AXI_DATA_WIDTH-1:0]   s_axis_tdata,
    input                               s_axis_tlast,

    // st0
    output logic                        st0_sel,

    output logic [AXI_ADDR_WIDTH-1:0]   st0_waddr,
    output logic [AXI_DATA_WIDTH-1:0]   st0_wdata,
    output logic                        st0_wen,

    output logic [ST0_ADDR_WIDTH-1:0]   st0_raddr,
    input  logic [ST0_DATA_WIDTH-1:0]   st0_re,
    input  logic [ST0_DATA_WIDTH-1:0]   st0_im,

    output logic                        st1_sel,
    output logic [ST1_DATA_WIDTH-1:0]   st1_wdata,
    output logic                        st1_wen,
    output logic [ST1_ADDR_WIDTH-1:0]   st1_waddr,
    output logic [ST1_ADDR_WIDTH-1:0]   st1_raddr,
    output logic                        rd_stage_ptr,
    input        [ST1_DATA_WIDTH*4-1:0] st1_rdata,

    output logic                        st2_sel,
    output logic [ST2_DATA_WIDTH*4-1:0] st2_wdata,
    output logic                        st2_wen,
    output logic [ST2_ADDR_WIDTH-1:0]   st2_waddr,
    output logic [ST2_ADDR_WIDTH-1:0]   st2_raddr,
    input        [ST2_DATA_WIDTH*4-1:0] st2_rdata,

    output logic                        st3_sel,
    output logic [ST3_DATA_WIDTH-1:0]   st3_wdata [CHANNEL_NUM],
    output logic                        st3_wen,
    output logic [ST3_ADDR_WIDTH-1:0]   st3_waddr,
    output logic [ST4_ADDR_WIDTH-1:0]   st3_raddr,
    input  logic [ST4_DATA_WIDTH-1:0]   st3_rdata,

    output logic [$clog2(POLY_POWER/CHANNEL_NUM)-1:0] tf_raddr,
    input        [ST2_DATA_WIDTH*CHANNEL_NUM-1:0]     tf_rdata [CHANNEL_NUM],

    input        [SPM_ADDR_WIDTH-1:0]   encode2spm_base_addr,
    input        [ID_WIDTH-1:0]         poly_id_i,
    output logic [ID_WIDTH-1:0]         poly_id_o,
    input                               ctrl_start,

    // output logic                        ctrl_done
    output logic [SPM_ADDR_WIDTH-1:0]   encode_wr_addr,
    output logic                        encode_wr_en,
    output logic [ST4_DATA_WIDTH-1:0]   encode_wr_data
);
    localparam ST0 = 1024;
    localparam BUF_NUM = 2;
    localparam ST1 = 4096;
    localparam ST2 = 2048;
    localparam ST3 = 4096;

    logic [$clog2(ST3)-1:0] st3_cnt;


    logic [ST0_DATA_WIDTH-1:0] flt2fx_axis_tdata_re;
    logic [ST0_DATA_WIDTH-1:0] flt2fx_axis_tdata_im;
    logic                  flt2fx_axis_tvalid_re;
    logic                  flt2fx_axis_tvalid_im;
    logic                  flt2fx_axis_tready_re;
    logic                  flt2fx_axis_tready_im;
    logic                  re_fifo_full;
    logic                  im_fifo_full;
    logic                  re_fifo_push;
    logic                  im_fifo_push;

    logic st0_rd_vld;
    logic st0_is_rd;
    logic st0_rd_done;

    logic [SPM_ADDR_WIDTH-1:0]   fifo_base_addr;
    logic [ID_WIDTH-1:0]         fifo_poly_id;
    logic                        info_fifo_pop;

    fifo #(
        .DATA_WIDTH (SPM_ADDR_WIDTH + ID_WIDTH),
        .ADDR_WIDTH  (4),
        .THRESHOLD   (0)
    ) u_sync_fifo_info (
        .clk         (clk),
        .rst_n       (rst_n),
        .data_i      ({encode2spm_base_addr, poly_id_i}),
        .push        (ctrl_start),
        .pop         (info_fifo_pop),
        .data_o      ({fifo_base_addr, fifo_poly_id}),
        .accept      (),
        .valid       (),
        .almost_full ()
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            poly_id_o <= '0;
        end
        else if (info_fifo_pop) begin
            poly_id_o <= fifo_poly_id;
        end
    end

    // ------------------------------------------------------------- //
    //                             STAGE0                            //
    // ------------------------------------------------------------- //
    wr_cnt #(
        .CNT_NUM         (ST0),
        .IN_DATA_WIDTH   (AXI_DATA_WIDTH),
        .OUT_DATA_WIDTH  (AXI_DATA_WIDTH),
        .ADDR_WIDTH      (AXI_ADDR_WIDTH),
        .STAGE           (0)
    ) u_st0_wr_cnt (
        .clk             (clk),
        .rst_n           (rst_n),
        .pre_st_vld      (s_axis_tvalid),
        .pre_st_wdata    (s_axis_tdata),
        .st_rd_done      (st0_rd_done),

        .pre_st_rdy      (s_axis_tready),
        .st_wen          (st0_wen),
        .st_wdata        (st0_wdata),
        .st_sel          (st0_sel),
        .st_waddr        (st0_waddr),
        .st_vld          (st0_rd_vld)
    );

    rd_cnt #(
        .CNT_NUM          (ST1),
        .STAGE            (0),
        .ADDR_WIDTH       (ST0_ADDR_WIDTH),
        .BANK_NUM         (AXI_DATA_WIDTH / ST0_DATA_WIDTH),
        .BRAM_LATENCY     (BRAM_LATENCY)
    ) u_st0_rd_cnt (
        .clk              (clk),
        .rst_n            (rst_n),
        .st_vld           (st0_rd_vld),
        .aft_st_rdy       (~(re_fifo_full | im_fifo_full)),
        .aft_st_raddr     (st0_raddr),
        .aft_st_rd        (st0_is_rd),
        .st_rd_done       (st0_rd_done),
        .fft_rd_st_ptr    ()
    );

    assign re_fifo_push = st0_is_rd,
           im_fifo_push = st0_is_rd;

    fifo #(
        .DATA_WIDTH(ST0_DATA_WIDTH),
        .ADDR_WIDTH(4),
        .THRESHOLD (BRAM_LATENCY+1)
    ) u_sync_fifo_re (
        .clk         (clk),
        .rst_n       (rst_n),
        .data_i      (st0_re),
        .push        (re_fifo_push),
        .pop         (flt2fx_axis_tvalid_re & flt2fx_axis_tready_re),
        .data_o      (flt2fx_axis_tdata_re),
        .accept      (),
        .valid       (flt2fx_axis_tvalid_re),
        .almost_full (re_fifo_full)
    );

    fifo #(
        .DATA_WIDTH(ST0_DATA_WIDTH),
        .ADDR_WIDTH(4),
        .THRESHOLD (BRAM_LATENCY+1)
    ) u_sync_fifxo_im (
        .clk         (clk),
        .rst_n       (rst_n),
        .data_i      (st0_im),
        .push        (im_fifo_push),
        .pop         (flt2fx_axis_tvalid_im & flt2fx_axis_tready_im),
        .data_o      (flt2fx_axis_tdata_im),
        .accept      (),
        .valid       (flt2fx_axis_tvalid_im),
        .almost_full (im_fifo_full)
    );

    logic fx_re_tvalid;
    logic fx_re_tready;
    logic [39:0] fx_re_tdata;
    logic fx_im_tvalid;
    logic fx_im_tready;
    logic [39:0] fx_im_tdata;

    floating_point_0 u_floating_point_0 (
        .aclk(clk),
        .s_axis_a_tvalid        (flt2fx_axis_tvalid_re),
        .s_axis_a_tready        (flt2fx_axis_tready_re),
        .s_axis_a_tdata         (flt2fx_axis_tdata_re),
        .m_axis_result_tvalid   (fx_re_tvalid),
        .m_axis_result_tready   (fx_re_tready),
        .m_axis_result_tdata    (fx_re_tdata)
    );

    floating_point_0 u_floating_point_1 (
        .aclk(clk),
        .s_axis_a_tvalid        (flt2fx_axis_tvalid_im),
        .s_axis_a_tready        (flt2fx_axis_tready_im),
        .s_axis_a_tdata         (flt2fx_axis_tdata_im),
        .m_axis_result_tvalid   (fx_im_tvalid),
        .m_axis_result_tready   (fx_im_tready),
        .m_axis_result_tdata    (fx_im_tdata)
    );

    // ------------------------------------------------------------- //
    //                             STAGE1                            //
    // ------------------------------------------------------------- //
    logic st1_rd_vld;
    localparam FFT_CNT = 2048;
    logic st1_rd_done;
    logic st1_is_rd;

    logic bf_fft_fifo_push;
    logic [CHANNEL_NUM-1:0] bf_fft_fifo_full;
    logic [CHANNEL_NUM-1:0] bf_fft_fifo_vld;
    wr_cnt #(
        .CNT_NUM        (ST1),
        .IN_DATA_WIDTH  (40*2),
        .OUT_DATA_WIDTH (34*2),
        .ADDR_WIDTH     ($clog2(ST1)),
        .STAGE          (1)
    ) u_st1_wr_cnt (
        .clk            (clk),
        .rst_n          (rst_n),
        .pre_st_vld     (fx_re_tvalid),
        .pre_st_wdata   ({fx_im_tdata, fx_re_tdata}),
        .st_rd_done     (st1_rd_done),
        .pre_st_rdy     (fx_re_tready),
        .st_wen         (st1_wen),
        .st_wdata       (st1_wdata),
        .st_sel         (st1_sel),
        .st_waddr       (st1_waddr),
        .st_vld         (st1_rd_vld)
    );

    assign fx_im_tready = fx_re_tready;

    rd_cnt #(
        .CNT_NUM          (FFT_CNT),
        .STAGE            ("FFT"),
        .ADDR_WIDTH       (ST1_ADDR_WIDTH),
        .BANK_NUM         (4),
        .BRAM_LATENCY     (BRAM_LATENCY)
    ) u_st1_rd_cnt (
        .clk              (clk),
        .rst_n            (rst_n),
        .st_vld           (st1_rd_vld),
        .aft_st_rdy       (~&bf_fft_fifo_full),
        .aft_st_raddr     (st1_raddr),
        .aft_st_rd        (st1_is_rd),
        .st_rd_done       (st1_rd_done),
        .fft_rd_st_ptr    (rd_stage_ptr)
    );

    assign bf_fft_fifo_push = st1_is_rd;

    logic [ST1_DATA_WIDTH/2-1:0] bf_fft_fifo_data_re [CHANNEL_NUM];
    logic [ST1_DATA_WIDTH/2-1:0] bf_fft_fifo_data_im [CHANNEL_NUM];

    logic [$clog2(FFT_CNT)-1:0] fft_cnt;
    logic [CHANNEL_NUM-1:0] bf_fft_fifo_rdy;

    generate
        genvar i;
        for (i=0; i<CHANNEL_NUM; i++) begin
            fifo #(
                .DATA_WIDTH(ST1_DATA_WIDTH),
                .ADDR_WIDTH(4),
                .THRESHOLD (BRAM_LATENCY+1)
            ) u_sync_fifo_channel (
                .clk         (clk),
                .rst_n       (rst_n),
                .data_i      (st1_rdata[i*ST1_DATA_WIDTH+:ST1_DATA_WIDTH]),
                .push        (bf_fft_fifo_push),
                .pop         (&bf_fft_fifo_vld & &bf_fft_fifo_rdy),
                .data_o      ({bf_fft_fifo_data_re[i], bf_fft_fifo_data_im[i]}),
                .accept      (),
                .valid       (bf_fft_fifo_vld[i]),
                .almost_full (bf_fft_fifo_full[i])
            );
        end
    endgenerate


    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n)
            fft_cnt <= '0;
        else if (&bf_fft_fifo_vld & &bf_fft_fifo_rdy) begin
            fft_cnt <= fft_cnt + 1;
        end
    end

    logic [39:0] aft_fft_data_re     [CHANNEL_NUM];
    logic [39:0] aft_fft_data_im     [CHANNEL_NUM];
    logic event_frame_started        [CHANNEL_NUM];
    logic event_tlast_unexpected     [CHANNEL_NUM];
    logic event_tlast_missing        [CHANNEL_NUM];
    logic event_fft_overflow         [CHANNEL_NUM];
    logic event_status_channel_halt  [CHANNEL_NUM];
    logic event_data_in_channel_halt [CHANNEL_NUM];
    logic event_data_out_channel_halt[CHANNEL_NUM];

    logic [CHANNEL_NUM-1:0] aft_fft_data_tvalid;
    logic [CHANNEL_NUM-1:0] aft_fft_data_tready;
    logic [CHANNEL_NUM-1:0] aft_fft_data_tlast ;
    logic                   aft_fft_data_tready_n;

    logic [7:0] aft_fft_status_tdata  [CHANNEL_NUM];
    logic aft_fft_status_tvalid       [CHANNEL_NUM];
    logic fft_config_tready           [CHANNEL_NUM];
    logic [23:0] aft_fft_data_tuser   [CHANNEL_NUM];
    // axis_config [12:1] scale_sch        [0] fwd_inv
    generate
        genvar j;
        for(j=0; j<CHANNEL_NUM; j++) begin
            xfft_0 fft_channel (
              .aclk                            (clk),
              .s_axis_config_tdata             (16'b0110_1010_1010_0),
              .s_axis_config_tvalid            (bf_fft_fifo_vld[j]),
              .s_axis_config_tready            (fft_config_tready[j]),
              .s_axis_data_tdata               ({6'b0, bf_fft_fifo_data_im[j], 6'b0, bf_fft_fifo_data_re[j]}),
              .s_axis_data_tvalid              (bf_fft_fifo_vld[j]),
              .s_axis_data_tready              (bf_fft_fifo_rdy[j]),
              .s_axis_data_tlast               (fft_cnt == '1),
              .m_axis_data_tdata               ({aft_fft_data_im[j], aft_fft_data_re[j]}),
              .m_axis_data_tuser               (aft_fft_data_tuser[j]),
              .m_axis_data_tvalid              (aft_fft_data_tvalid[j]),
              .m_axis_data_tready              (aft_fft_data_tready[j]),
              .m_axis_data_tlast               (aft_fft_data_tlast[j]),
              .m_axis_status_tdata             (aft_fft_status_tdata[j]),
              .m_axis_status_tvalid            (aft_fft_status_tvalid[j]),
              .m_axis_status_tready            (aft_fft_data_tready[j]),
              .event_frame_started             (event_frame_started[j]),
              .event_tlast_unexpected          (event_tlast_unexpected[j]),
              .event_tlast_missing             (event_tlast_missing[j]),
              .event_fft_overflow              (event_fft_overflow[j]),
              .event_status_channel_halt       (event_status_channel_halt[j]),
              .event_data_in_channel_halt      (event_data_in_channel_halt[j]),
              .event_data_out_channel_halt     (event_data_out_channel_halt[j])
            );
        end
    endgenerate

    // ------------------------------------------------------------- //
    //                             STAGE2                            //
    // ------------------------------------------------------------- //
    logic [ST2_DATA_WIDTH*4-1:0] st2_wdata_n;
    logic st2_rd_vld;
    logic st2_is_rd;
    logic st2_rd_done;
    logic [CHANNEL_NUM-1:0] cmp_fifo_full;
    logic cmp_fifo_push;
    logic cmp_fifo_pop;
    wr_cnt #(
        .CNT_NUM       (ST2),
        .IN_DATA_WIDTH (ST2_DATA_WIDTH*4),
        .OUT_DATA_WIDTH(ST2_DATA_WIDTH*4),
        .ADDR_WIDTH    (ST2_ADDR_WIDTH),
        .STAGE         (2)
    ) u_st2_wr_cnt (
        .clk           (clk),
        .rst_n         (rst_n),
        .pre_st_vld    (&aft_fft_data_tvalid),
        .pre_st_wdata  (st2_wdata_n),
        .st_rd_done    (st2_rd_done),
        .pre_st_rdy    (aft_fft_data_tready_n),
        .st_wen        (st2_wen),
        .st_wdata      (st2_wdata),
        .st_sel        (st2_sel),
        .st_waddr      (st2_waddr),
        .st_vld        (st2_rd_vld)
    );

    always_comb begin
        for (int i=0; i<CHANNEL_NUM; i++) begin
            st2_wdata_n[i*ST2_DATA_WIDTH+:ST2_DATA_WIDTH] = {aft_fft_data_im[i][ST2_DATA_WIDTH/2-1:0], aft_fft_data_re[i][ST2_DATA_WIDTH/2-1:0]};
        end
    end

    assign aft_fft_data_tready = {CHANNEL_NUM{aft_fft_data_tready_n}};

    rd_cnt #(
        .CNT_NUM         (ST3),
        .STAGE           (2),
        .ADDR_WIDTH      (ST2_ADDR_WIDTH),
        .BANK_NUM        (4),
        .BRAM_LATENCY    (BRAM_LATENCY)
    ) u_st2_rd_cnt (
        .clk             (clk),
        .rst_n           (rst_n),
        .st_vld          (st2_rd_vld),
        .aft_st_rdy      (~|cmp_fifo_full),
        .aft_st_raddr    (st2_raddr),
        .aft_st_rd       (st2_is_rd),
        .st_rd_done      (st2_rd_done),
        .fft_rd_st_ptr   ()
    );
    assign tf_raddr = st2_raddr;

    logic [CHANNEL_NUM-1:0]      cmp_axis_fft_tvalid ;
    logic [CHANNEL_NUM-1:0]      cmp_axis_tf_tvalid     [CHANNEL_NUM];
    logic [ST2_DATA_WIDTH/2-1:0] cmp_axis_tdata_fft_re  [CHANNEL_NUM];
    logic [ST2_DATA_WIDTH/2-1:0] cmp_axis_tdata_fft_im  [CHANNEL_NUM];
    logic [ST2_DATA_WIDTH/2-1:0] cmp_axis_tdata_tf_re   [CHANNEL_NUM][CHANNEL_NUM];
    logic [ST2_DATA_WIDTH/2-1:0] cmp_axis_tdata_tf_im   [CHANNEL_NUM][CHANNEL_NUM];

    logic [CHANNEL_NUM-1:0] cmp_dout_tvalid [CHANNEL_NUM];
    logic [47:0] cmp_im   [CHANNEL_NUM][CHANNEL_NUM];
    logic [47:0] cmp_re   [CHANNEL_NUM][CHANNEL_NUM];
    logic [CHANNEL_NUM-1:0] cmp_axis_fft_tready [CHANNEL_NUM];
    logic [CHANNEL_NUM-1:0] cmp_axis_tf_tready  [CHANNEL_NUM];
    logic cmp_dout_tready;

    assign cmp_fifo_push = st2_is_rd;
    assign cmp_fifo_pop  = &cmp_axis_fft_tvalid & &cmp_axis_fft_tready[0];

    generate
        genvar cmp_fft;
        for(cmp_fft=0; cmp_fft<CHANNEL_NUM; cmp_fft++) begin
            fifo #(
                .DATA_WIDTH(ST2_DATA_WIDTH),
                .ADDR_WIDTH(4),
                .THRESHOLD (BRAM_LATENCY+1)
            ) u_sync_cmp_fft (
                .clk         (clk),
                .rst_n       (rst_n),
                .data_i      (st2_rdata[cmp_fft*ST2_DATA_WIDTH+:ST2_DATA_WIDTH]),
                .push        (cmp_fifo_push),
                .pop         (cmp_fifo_pop),
                .data_o      ({cmp_axis_tdata_fft_im[cmp_fft], cmp_axis_tdata_fft_re[cmp_fft]}),
                .accept      (),
                .valid       (cmp_axis_fft_tvalid[cmp_fft]),
                .almost_full (cmp_fifo_full[cmp_fft])
            );
        end
    endgenerate

    generate
        genvar cmp_tf_row, cmp_tf_col;
        for(cmp_tf_row=0; cmp_tf_row<CHANNEL_NUM; cmp_tf_row++) begin
            for(cmp_tf_col=0; cmp_tf_col<CHANNEL_NUM; cmp_tf_col++) begin
                fifo #(
                    .DATA_WIDTH(ST2_DATA_WIDTH),
                    .ADDR_WIDTH(4),
                    .THRESHOLD (BRAM_LATENCY+1)
                ) u_sync_cmp_tf (
                    .clk         (clk),
                    .rst_n       (rst_n),
                    .data_i      (tf_rdata[cmp_tf_row][cmp_tf_col*ST2_DATA_WIDTH+:ST2_DATA_WIDTH]),
                    .push        (cmp_fifo_push),
                    .pop         (cmp_fifo_pop),
                    .data_o      ({cmp_axis_tdata_tf_re[cmp_tf_row][cmp_tf_col], cmp_axis_tdata_tf_im[cmp_tf_row][cmp_tf_col]}),
                    .accept      (),
                    .valid       (cmp_axis_tf_tvalid[cmp_tf_row][cmp_tf_col]),
                    .almost_full ()
                );
            end
        end
    endgenerate

    // 0 - 1023
    generate;
        genvar cmp_row, cmp_col;
        for(cmp_row=0; cmp_row<CHANNEL_NUM; cmp_row++) begin
            for(cmp_col=0; cmp_col<CHANNEL_NUM; cmp_col++) begin
                cmpy_0 u_cmp (
                    .aclk               (clk),
                    .s_axis_a_tvalid    (&cmp_axis_fft_tvalid),
                    .s_axis_a_tready    (cmp_axis_fft_tready[cmp_row][cmp_col]),
                    .s_axis_a_tdata     ({6'b0, cmp_axis_tdata_fft_im[cmp_row], 6'b0, cmp_axis_tdata_fft_re[cmp_row]}),
                    .s_axis_b_tvalid    (&cmp_axis_tf_tvalid[cmp_row]),
                    .s_axis_b_tdata     ({6'b0, cmp_axis_tdata_tf_im[cmp_row][cmp_col], 6'b0, cmp_axis_tdata_tf_re[cmp_row][cmp_col]}),
                    .s_axis_b_tready    (cmp_axis_tf_tready[cmp_row][cmp_col]),
                    .m_axis_dout_tvalid (cmp_dout_tvalid[cmp_row][cmp_col]),
                    .m_axis_dout_tready (cmp_dout_tready),
                    .m_axis_dout_tdata  ({cmp_im[cmp_row][cmp_col], cmp_re[cmp_row][cmp_col]})
                );
            end
        end
    endgenerate

    logic [47:0] cmp_re_res   [CHANNEL_NUM];
    logic [47:0] cmp_re_res_n [CHANNEL_NUM];
    logic [CHANNEL_NUM-1:0] cmp_re_res_vld;

    generate;
        genvar sum_idx_row, sum_idx_col;
        always_comb begin
            for (int sum_idx_row=0; sum_idx_row<CHANNEL_NUM; sum_idx_row++) begin
                cmp_re_res_n[sum_idx_row] = '0;
                for (int sum_idx_col=0; sum_idx_col<CHANNEL_NUM; sum_idx_col++) begin
                    cmp_re_res_n[sum_idx_row] += cmp_re[sum_idx_col][sum_idx_row];
                end
            end
        end
    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            cmp_re_res <= '{default: 0};
            cmp_re_res_vld <= '0;
        end else begin
            for(int sum_idx=0; sum_idx<CHANNEL_NUM; sum_idx++) begin
                if(&cmp_dout_tvalid[sum_idx]) begin
                    cmp_re_res_vld[sum_idx] <= 1'b1;
                    cmp_re_res[sum_idx] <= cmp_re_res_n[sum_idx];
                end
                else begin
                    cmp_re_res_vld[sum_idx] <= 1'b0;
                end
            end
        end
    end

    // ------------------------------------------------------------- //
    //                             STAGE3                            //
    // ------------------------------------------------------------- //
    logic [SPM_ADDR_WIDTH-1:0] base_addr;
    logic [MOD_WIDTH-1:0] mod;
    logic                 mod_sel;
    logic st3_rd_vld;
    logic st3_is_rd;
    logic st3_rd_done;

    // 16 trans cnt
    localparam TRANS_CNT = 16;
    localparam FILL_CNT  = 128;
    localparam RLS_CNT   = 4;
    logic [$clog2(TRANS_CNT)-1:0] trans_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            trans_cnt <= '0;
        end
        else if (st3_rd_done) begin
            trans_cnt <= trans_cnt + 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mod_sel <= 1'b0;
        end
        else if ((trans_cnt == '1) & (st3_waddr == '1) & st3_wen) begin
            mod_sel <= ~mod_sel;
        end
    end

    assign mod = mod_sel ? MOD_1 : MOD_0;

    wr_cnt #(
        .CNT_NUM           (FILL_CNT),
        .IN_DATA_WIDTH     (48*CHANNEL_NUM),
        .OUT_DATA_WIDTH    (48*CHANNEL_NUM),
        .ADDR_WIDTH        ($clog2(FILL_CNT)),
        .STAGE             (3)
    ) u_st3_wr_cnt (
        .clk               (clk),
        .rst_n             (rst_n),
        .pre_st_vld        (&cmp_re_res_vld),
        .pre_st_wdata      (),
        .st_rd_done        (st3_rd_done),
        .pre_st_rdy        (cmp_dout_tready),
        .st_wen            (st3_wen),
        .st_wdata          (),
        .st_sel            (st3_sel),
        .st_waddr          (st3_waddr),
        .st_vld            (st3_rd_vld)
    );

    rd_cnt #(
        .CNT_NUM           (RLS_CNT),
        .STAGE             (3),
        .ADDR_WIDTH        ($clog2(RLS_CNT)),
        .BANK_NUM          (4),
        .BRAM_LATENCY      (BRAM_LATENCY)
    ) u_st3_rd_cnt (
        .clk               (clk),
        .rst_n             (rst_n),
        .st_vld            (st3_rd_vld),
        .aft_st_rdy        (1'b1),
        .aft_st_raddr      (st3_raddr),
        .aft_st_rd         (st3_is_rd),
        .st_rd_done        (st3_rd_done),
        .fft_rd_st_ptr     ()
    );

    // wdata mod
    logic [ST3_DATA_WIDTH-1:0]   st3_wdata_n [CHANNEL_NUM];
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            st3_wdata_n <= '{0, 0, 0, 0};
        end
        else begin
            for (int i=0; i<CHANNEL_NUM; i++) begin
                st3_wdata_n[i] <= MOD_WIDTH'(signed'(cmp_re_res[i]));//cmp_re_res[i][47] ? MOD_WIDTH'(signed'(cmp_re_res[i])) + mod : MOD_WIDTH'(signed'(cmp_re_res[i]));
            end
        end
    end

    always_comb begin
        for (int i=0; i<CHANNEL_NUM; i++) begin
            st3_wdata[i] = st3_wdata_n[i][ST3_DATA_WIDTH-1] ? st3_wdata_n[i] + mod : st3_wdata_n[i];
        end
    end

    // addr gen
    assign encode_wr_en = st3_is_rd;
    assign encode_wr_data = st3_rdata;

    logic st3_rd_vld_r;
    logic st3_rd_vld_pos;
    logic st3_is_rd_r;
    logic st3_is_rd_neg;
    logic upd_base_addr;

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            st3_rd_vld_r <= '0;
        end
        else begin
            st3_rd_vld_r <= st3_rd_vld;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            st3_is_rd_r <= '0;
        end
        else begin
            st3_is_rd_r <= st3_is_rd;
        end
    end
    assign st3_is_rd_neg = st3_is_rd_r & ~st3_is_rd;
    assign st3_rd_vld_pos = st3_rd_vld & ~st3_rd_vld_r;
    assign info_fifo_pop = ~mod_sel & st3_is_rd_neg & (trans_cnt == '0);
    assign upd_base_addr = ~mod_sel & st3_rd_vld_pos & (trans_cnt == '0);

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            base_addr <= '0;
        end
        else if ( upd_base_addr ) begin
            base_addr <= fifo_base_addr;
        end
        else if ((st3_raddr == '1) & (trans_cnt == '0)) begin
            base_addr <= base_addr + 48 + 1;
        end
        else if (st3_raddr == '1) begin
            base_addr <= base_addr + 1;
        end
    end

    logic [SPM_ADDR_WIDTH-1:0]   encode_wr_addr_r [BRAM_LATENCY-1:0];


    always_ff @(posedge clk) begin
        encode_wr_addr_r[0] <= base_addr + (st3_raddr << 4);
        for (int i=0; i<BRAM_LATENCY-1; ++i) begin
            encode_wr_addr_r[i+1] <= encode_wr_addr_r[i];
        end
    end

    assign encode_wr_addr = encode_wr_addr_r[BRAM_LATENCY-1];

endmodule : controller