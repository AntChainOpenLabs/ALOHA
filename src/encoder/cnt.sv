//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: ENCODER
// Module Name: wr_cnt & rd_cnt
// Modify Date: 
//
// Description:
// wr_cnt & rd_cnt
//////////////////////////////////////////////////
module wr_cnt #(
    parameter CNT_NUM           = 1024,
    parameter IN_DATA_WIDTH     = 512,
    parameter OUT_DATA_WIDTH    = 512,
    parameter ADDR_WIDTH        = 10,
    parameter STAGE             = 0
) (
    input                               clk,
    input                               rst_n,
    input                               pre_st_vld,
    input        [IN_DATA_WIDTH-1:0]    pre_st_wdata,
    input                               st_rd_done,
    output logic                        pre_st_rdy,
    output logic                        st_wen,
    output logic [OUT_DATA_WIDTH-1:0]   st_wdata,
    output logic                        st_sel,
    output logic [ADDR_WIDTH-1:0]       st_waddr,
    output logic                        st_vld

);
    localparam BUF_NUM = 2;
    (* MAX_FANOUT = 100 *) logic [$clog2(CNT_NUM)-1:0] wr_cnt;
    logic wr_sel;
    logic [BUF_NUM-1:0] wr_undone;

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            wr_cnt <= '0;
        end
        else if (pre_st_vld & pre_st_rdy) begin
            wr_cnt <= wr_cnt + 1'b1;
        end
    end

    generate;
        if (STAGE == 0 || STAGE == 2 || STAGE == 3) begin
            // waddr gen
            assign st_waddr = wr_cnt - 1'b1;

            // wdata gen
            always_ff @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    st_wdata <= '0;
                end
                else begin
                    st_wdata <= pre_st_wdata;
                end
            end
            // wen gen
            always_ff @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    st_wen   <= 1'b0;
                end
                else begin
                    st_wen   <= pre_st_vld & pre_st_rdy;
                end
            end
        end

        if (STAGE == 1) begin
            // waddr wen gen
            localparam FX_DATA_WIDTH = 34;
            logic b_im;
            ecd_addr_gen #(
                .ADDR_WIDTH  ($clog2(CNT_NUM)),
                .POLY_POWER  (8192),
                .ROTATE_BASE (3)
            ) u_ecd_addr_gen (
                .clk            (clk),
                .rst_n          (rst_n),
                .rarg_vld       (pre_st_vld),
                .rarg_rdy       (pre_st_rdy),
                .org_addr       (wr_cnt),
                .rarg_addr      (st_waddr),
                .b_im           (b_im),
                .addr_gen_vld   (st_wen)
            );
            // wdata gen
            logic [39:0]                  fx_re_tdata;
            logic [39:0]                  fx_im_tdata;
            logic [39:0]                  b_fx_im_tdata;
            logic [FX_DATA_WIDTH-1:0]     b_fx_im_tdata_r;
            logic [FX_DATA_WIDTH-1:0]     fx_re_tdata_r;
            logic [FX_DATA_WIDTH-1:0]     fx_im_tdata_r;

            assign {fx_im_tdata, fx_re_tdata} = pre_st_wdata;
            assign b_fx_im_tdata = ~fx_im_tdata + 1;

            always_ff @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    fx_re_tdata_r   <= '0;
                    fx_im_tdata_r   <= '0;
                    b_fx_im_tdata_r <= '0;
                end else begin
                    fx_re_tdata_r   <= fx_re_tdata[FX_DATA_WIDTH-1:0];
                    fx_im_tdata_r   <= fx_im_tdata[FX_DATA_WIDTH-1:0];
                    b_fx_im_tdata_r <= b_fx_im_tdata[FX_DATA_WIDTH-1:0];
                end
            end

            assign st_wdata = b_im ? {fx_re_tdata_r, b_fx_im_tdata_r} : {fx_re_tdata_r, fx_im_tdata_r};
        end

    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            wr_sel <= 1'b0;
        end
        else if (wr_undone[wr_sel] & pre_st_rdy) begin
            wr_sel <= ~wr_sel;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            wr_undone <= {BUF_NUM{1'b0}};
        end
        else begin
            if (wr_cnt == '1) begin
                wr_undone[wr_sel] <= 1'b1;
            end
            if (st_rd_done) begin
                wr_undone[~wr_sel] <= 1'b0;
            end
        end
    end

    assign pre_st_rdy = ~&wr_undone;
    assign st_sel = wr_sel;
    assign st_vld = |wr_undone;

endmodule : wr_cnt

module rd_cnt #(
    parameter CNT_NUM       = 4096,
    parameter STAGE         = 0,
    parameter ADDR_WIDTH    = 13,
    parameter BANK_NUM      = 4,
    parameter BRAM_LATENCY  = 1
) (
    input                         clk,
    input                         rst_n,
    input                         st_vld,
    input                         aft_st_rdy,

    output logic [ADDR_WIDTH-1:0] aft_st_raddr,
    output logic                  aft_st_rd,
    output logic                  st_rd_done,

    // only for fft
    output logic                  fft_rd_st_ptr

);
    logic rd_incr;
    logic [$clog2(CNT_NUM)-1:0]rd_cnt;
    assign rd_incr = st_vld & aft_st_rdy;

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rd_cnt <= '0;
        end
        else if (rd_incr) begin
            rd_cnt <= rd_cnt + 1'b1;
        end
    end

    generate;
        if (STAGE == 0) begin
            logic [$clog2(BANK_NUM)-1:0]            raddr_high;
            logic [ADDR_WIDTH-$clog2(BANK_NUM)-1:0] raddr_low;
            assign raddr_high = (rd_cnt % BANK_NUM) << 1,
                   raddr_low  = rd_cnt >> 2;

            always_ff @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    aft_st_raddr <= '0;
                end
                else begin
                    aft_st_raddr <= {raddr_high, raddr_low};
                end
            end
        end
        if (STAGE == "FFT") begin
            always_ff @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    fft_rd_st_ptr <= 1'b0;
                end
                else if (rd_cnt == (CNT_NUM >> 1) - 1) begin
                    fft_rd_st_ptr <= 1'b1;
                end
                else if (rd_cnt == CNT_NUM - 1) begin
                    fft_rd_st_ptr <= 1'b0;
                end
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    aft_st_raddr <= '0;
                end
                else begin
                    aft_st_raddr <= fft_rd_st_ptr ? CNT_NUM - rd_cnt - 1 : rd_cnt;
                end
            end
        end

        if (STAGE == 2) begin
            always_ff @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    aft_st_raddr <= '0;
                end
                else begin
                    aft_st_raddr <= rd_cnt % 2048;
                end
            end
        end

        if (STAGE == 3) begin
            always_ff @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    aft_st_raddr <= '0;
                end
                else begin
                    aft_st_raddr <= rd_cnt;
                end
            end
        end
    endgenerate

    logic [BRAM_LATENCY:0]      rd_incr_r;
    always_ff @(posedge clk) begin
        rd_incr_r[0] <= rd_incr;
        for (int i=0; i<BRAM_LATENCY; ++i) begin
            rd_incr_r[i+1] <= rd_incr_r[i];
        end
    end

    assign aft_st_rd = rd_incr_r[BRAM_LATENCY];
    assign st_rd_done = rd_cnt == '1;
endmodule : rd_cnt
