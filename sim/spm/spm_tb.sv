import axi_vip_pkg::*;
import axi_vip_0_pkg::*;
import axi_vip_1_pkg::*;
`timescale 1ns/100ps
module spm_tb;
parameter URAM_ADDR_WIDTH       = 12;
parameter BANK_NUM              = 4;
parameter SPM_ADDR_WIDTH        = $clog2(BANK_NUM) + URAM_ADDR_WIDTH;
parameter NUM_LANE              = 128;
parameter DATA_WIDTH            = 64;
parameter NB_PIPE               = 2;
parameter PERIOD                = 10;
parameter AXI_ADDR_WIDTH        = 64;
parameter AXI_DATA_WIDTH        = 512;
parameter AXI_XFER_SIZE_WIDTH   = 32;
parameter INCLUDE_DATA_FIFO     = 0;
parameter test_num              = 1000;
parameter RES_FILE_PATH         = "";
parameter AXI_SLV_VIP_MEM_INIT  = "";
parameter ST0_ADDR_WIDTH        = 13;
parameter ST0_DATA_WIDTH        = 64;
parameter ST1_ADDR_WIDTH        = 12;
parameter ST1_DATA_WIDTH        = 68;
parameter ST2_DATA_WIDTH        = 68;
parameter ST2_ADDR_WIDTH        = 11;
parameter POLY_POWER            = 8192;
parameter CHANNEL_NUM           = 4;
parameter MOD_WIDTH             = 64;
parameter ST3_ADDR_WIDTH        = 7;
parameter ST3_DATA_WIDTH        = 64;
parameter ST4_ADDR_WIDTH        = 2;
parameter ST4_DATA_WIDTH        = 8192;
parameter MOD_0                 = 64'd576460825317867521;
parameter MOD_1                 = 64'd576460924102115329;
parameter ID_WIDTH              = 11;

// vp
logic                               clk;
logic                               rst_n;
logic [SPM_ADDR_WIDTH-1:0]          i_vp_rd_addr;
logic                               i_vp_wr_en;
logic [SPM_ADDR_WIDTH-1:0]          i_vp_wr_addr;
logic [NUM_LANE*DATA_WIDTH-1:0]     i_vp_wr_data;
logic [NUM_LANE*DATA_WIDTH-1:0]     o_vp_rd_data;

// encoder
logic                               i_encode_wr_en;
logic [SPM_ADDR_WIDTH-1:0]          i_encode_wr_addr;
logic [NUM_LANE*DATA_WIDTH-1:0]     i_encode_wr_data;

// axi with ddr
logic                               axi_awvalid;
logic                               axi_awready;
logic   [AXI_ADDR_WIDTH-1:0]        axi_awaddr;
logic   [7:0]                       axi_awlen;
logic                               axi_wvalid;
logic                               axi_wready;
logic   [AXI_DATA_WIDTH-1:0]        axi_wdata;
logic   [AXI_DATA_WIDTH/8-1:0]      axi_wstrb;
logic                               axi_wlast;
logic                               axi_bvalid;
logic                               axi_bready;

logic                               axi_arvalid;
logic                               axi_arready;
logic    [AXI_ADDR_WIDTH-1:0]       axi_araddr;
logic    [7:0]                      axi_arlen;
logic                               axi_rvalid;
logic                               axi_rready;
logic    [AXI_DATA_WIDTH-1:0]       axi_rdata;
logic                               axi_rlast;

// axilite config
logic     [31:0]                    axi_cfg_awaddr;
logic                               axi_cfg_awvalid;
logic                               axi_cfg_awready;
logic     [31:0]                    axi_cfg_wdata;
logic     [3:0]                     axi_cfg_wstrb;
logic                               axi_cfg_wvalid;
logic                               axi_cfg_wready;
logic     [1:0]                     axi_cfg_bresp;
logic                               axi_cfg_bvalid;
logic                               axi_cfg_bready;
logic     [31:0]                    axi_cfg_araddr;
logic                               axi_cfg_arvalid;
logic                               axi_cfg_arready;
logic     [31:0]                    axi_cfg_rdata;
logic     [1:0]                     axi_cfg_rresp;
logic                               axi_cfg_rvalid;
logic                               axi_cfg_rready;

// encoder
logic                               encode_axis_tvalid;
logic                               encode_axis_tready;
logic                               encode_axis_tlast;
logic    [AXI_DATA_WIDTH-1:0]       encode_axis_tdata;
logic    [SPM_ADDR_WIDTH-1:0]       encode2spm_base_addr;
logic    [ID_WIDTH-1:0]             poly_id_i;
logic    [ID_WIDTH-1:0]             poly_id_o;
logic                               encode_cfg_start;

logic unsigned [63:0]               mtest_data0;
logic unsigned [63:0]               mtest_data1;
logic unsigned [63:0]               mtest_data2;
logic unsigned [63:0]               mtest_data3;
logic unsigned [63:0]               mtest_data4;
logic unsigned [63:0]               mtest_data5;
logic unsigned [63:0]               mtest_data6;
logic unsigned [63:0]               mtest_data7;
logic [AXI_DATA_WIDTH-1:0]          frd_data;
xil_axi_ulong cnt;
integer clr;
integer res;
int vp_cnt;

always #(PERIOD/2) clk = ~clk;
axi_vip_0_slv_mem_t slv_agent;
axi_vip_1_mst_t mst_agent;

    mem_top #(
        .URAM_ADDR_WIDTH         (URAM_ADDR_WIDTH),
        .BANK_NUM                (BANK_NUM),
        .SPM_ADDR_WIDTH          (SPM_ADDR_WIDTH),
        .NUM_LANE                (NUM_LANE),
        .DATA_WIDTH              (DATA_WIDTH),
        .NB_PIPE                 (NB_PIPE),
        .AXI_ADDR_WIDTH          (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH          (AXI_DATA_WIDTH),
        .AXI_XFER_SIZE_WIDTH     (AXI_XFER_SIZE_WIDTH),
        .INCLUDE_DATA_FIFO       (INCLUDE_DATA_FIFO)
    ) u_mem_top (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .axi_awvalid             (axi_awvalid),
        .axi_awready             (axi_awready),
        .axi_awaddr              (axi_awaddr),
        .axi_awlen               (axi_awlen),
        .axi_wvalid              (axi_wvalid),
        .axi_wready              (axi_wready),
        .axi_wdata               (axi_wdata),
        .axi_wstrb               (axi_wstrb),
        .axi_wlast               (axi_wlast),
        .axi_bvalid              (axi_bvalid),
        .axi_bready              (axi_bready),
        .axi_arvalid             (axi_arvalid),
        .axi_arready             (axi_arready),
        .axi_araddr              (axi_araddr),
        .axi_arlen               (axi_arlen),
        .axi_rvalid              (axi_rvalid),
        .axi_rready              (axi_rready),
        .axi_rdata               (axi_rdata),
        .axi_rlast               (axi_rlast),
        .axi_cfg_awaddr          (axi_cfg_awaddr),
        .axi_cfg_awvalid         (axi_cfg_awvalid),
        .axi_cfg_awready         (axi_cfg_awready),
        .axi_cfg_wdata           (axi_cfg_wdata),
        .axi_cfg_wstrb           (axi_cfg_wstrb),
        .axi_cfg_wvalid          (axi_cfg_wvalid),
        .axi_cfg_wready          (axi_cfg_wready),
        .axi_cfg_bresp           (axi_cfg_bresp),
        .axi_cfg_bvalid          (axi_cfg_bvalid),
        .axi_cfg_bready          (axi_cfg_bready),
        .axi_cfg_araddr          (axi_cfg_araddr),
        .axi_cfg_arvalid         (axi_cfg_arvalid),
        .axi_cfg_arready         (axi_cfg_arready),
        .axi_cfg_rdata           (axi_cfg_rdata),
        .axi_cfg_rresp           (axi_cfg_rresp),
        .axi_cfg_rvalid          (axi_cfg_rvalid),
        .axi_cfg_rready          (axi_cfg_rready),
        .i_encode_wr_en          (i_encode_wr_en),
        .i_encode_wr_addr        (i_encode_wr_addr),
        .i_encode_wr_data        (i_encode_wr_data),
        .poly_id_o               (poly_id_o),
        .encode_axis_tvalid      (encode_axis_tvalid),
        .encode_axis_tready      (encode_axis_tready),
        .encode_axis_tlast       (encode_axis_tlast),
        .encode_axis_tdata       (encode_axis_tdata),
        .encode2spm_base_addr    (encode2spm_base_addr),
        .encode_cfg_start        (encode_cfg_start),
        .poly_id_i               (poly_id_i),
        .i_vp_rd_addr            (i_vp_rd_addr),
        .i_vp_wr_en              (i_vp_wr_en),
        .i_vp_wr_addr            (i_vp_wr_addr),
        .i_vp_wr_data            (i_vp_wr_data),
        .o_vp_rd_data            (o_vp_rd_data),
        .o_ksk_wr_en             (),
        .o_ksk_addr              (),
        .o_ksk_wr_data           ()
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
        .clk                (clk),
        .rst_n              (rst_n),
        .m_axis_tvalid      (encode_axis_tvalid),
        .m_axis_tready      (encode_axis_tready),
        .m_axis_tdata       (encode_axis_tdata),
        .m_axis_tlast       (encode_axis_tlast),
        .ctrl_start         (encode_cfg_start),
        .encode2spm_base_addr(encode2spm_base_addr),
        .poly_id_i          (poly_id_i),
        .poly_id_o          (poly_id_o),
        .encode_wr_addr     (i_encode_wr_addr),
        .encode_wr_en       (i_encode_wr_en),
        .encode_wr_data     (i_encode_wr_data)
    );

    axi_vip_0 u_axi_vip_0 (
        .aclk(clk),
        .aresetn(rst_n),
        .s_axi_awaddr(axi_awaddr),
        .s_axi_awlen(axi_awlen),
        .s_axi_awburst(2'b01),
        .s_axi_awvalid(axi_awvalid),
        .s_axi_awready(axi_awready),
        .s_axi_wdata(axi_wdata),
        .s_axi_wlast(axi_wlast),
        .s_axi_wvalid(axi_wvalid),
        .s_axi_wready(axi_wready),
        .s_axi_bvalid(axi_bvalid),
        .s_axi_bready(axi_bready),
        .s_axi_araddr(axi_araddr),
        .s_axi_arlen(axi_arlen),
        .s_axi_arburst(2'b01),
        .s_axi_arvalid(axi_arvalid),
        .s_axi_arready(axi_arready),
        .s_axi_rdata(axi_rdata),
        .s_axi_rlast(axi_rlast),
        .s_axi_rvalid(axi_rvalid),
        .s_axi_rready(axi_rready)
    );

    axi_vip_1 u_axi_vip_1 (
        .aclk(clk),
        .aclken(1'b1),
        .aresetn(rst_n),
        .m_axi_awaddr(axi_cfg_awaddr),
        .m_axi_awvalid(axi_cfg_awvalid),
        .m_axi_awready(axi_cfg_awready),
        .m_axi_wdata(axi_cfg_wdata),
        .m_axi_wstrb(axi_cfg_wstrb),
        .m_axi_wvalid(axi_cfg_wvalid),
        .m_axi_wready(axi_cfg_wready),
        .m_axi_bresp(axi_cfg_bresp),
        .m_axi_bvalid(axi_cfg_bvalid),
        .m_axi_bready(axi_cfg_bready),
        .m_axi_araddr(axi_cfg_araddr),
        .m_axi_arvalid(axi_cfg_arvalid),
        .m_axi_arready(axi_cfg_arready),
        .m_axi_rdata(axi_cfg_rdata),
        .m_axi_rresp(axi_cfg_rresp),
        .m_axi_rvalid(axi_cfg_rvalid),
        .m_axi_rready(axi_cfg_rready)
    );

    task wait_random_time;
        repeat ({$random} % 10) @(posedge clk);
    endtask

    task wait_time;
        input int num;
        repeat (num) @(posedge clk);
    endtask

    task wait_rst_n;
        rst_n = 1'b0;
        repeat(20) @(posedge clk);
        rst_n = 1'b1;
    endtask

    task wr;
        input  [SPM_ADDR_WIDTH-1:0] addr;
        input  [NUM_LANE*DATA_WIDTH-1:0] data;
        output [SPM_ADDR_WIDTH-1:0] wr_addr;
        output logic wr_en;
        output [NUM_LANE*DATA_WIDTH-1:0] wr_data;

        wr_addr = addr;
        wr_en = 1'b1;
        wr_data = data;
    endtask

    task rd;
        input  [SPM_ADDR_WIDTH-1:0] addr;
        output [SPM_ADDR_WIDTH-1:0] rd_addr;
        output logic wr_en;
        rd_addr = addr;
        wr_en = 1'b0;
    endtask


    /*task spm_init;
        i_encode_wr_en = 1'b0;
        i_vp_wr_en = 1'b0;
    endtask*/

    localparam
        // misc
        version                 = 32'h104, // rd-only
        // DMA
        dma_wr_start            = 32'h22c, // wr-only
        dma_rd_start            = 32'h230, // wr-only
        dma_cmd                 = 32'h234,
        dma_spm_ptr             = 32'h238,
        dma_ddr_ptr_lo          = 32'hff023c,
        dma_ddr_ptr_hi          = 32'hff0240,
        dma_data_size_bytes     = 32'h244,
        // ENCODE
        ecd_rslt_ptr            = 32'h20c,
        // VP
        vp_pc                   = 32'h210,
        vp_start                = 32'h214, // wr-only
        csr_vp_src0_ptr         = 32'h218,
        csr_vp_src1_ptr         = 32'h21c,
        csr_vp_rslt_ptr         = 32'h220,
        csr_vp_rot_step         = 32'h224,
        csr_vp_ksk_ptr          = 32'h228,
        // GLOBAL DONE   | edc_id | vp_done | wr_done | rd_done
        glb_done                = 32'h208;

    task encode_cfg;
        input [AXI_ADDR_WIDTH-1:0] encoder_addr;
        mst_agent.AXI4LITE_WRITE_BURST(ecd_rslt_ptr, 0, encoder_addr, axi_cfg_bresp);
    endtask

    task rd_cfg;
        input [AXI_ADDR_WIDTH-1:0] ddr_addr;
        input [AXI_XFER_SIZE_WIDTH-1:0] size_bytes;
        input [AXI_ADDR_WIDTH-2:0] base_addr;
        input [31:0] command;
        input [ID_WIDTH-1:0] id;
        // logic [31:0] rd_start_val;
        // data_ptr
        mst_agent.AXI4LITE_WRITE_BURST(dma_ddr_ptr_lo, 0, ddr_addr[31:0], axi_cfg_bresp);
        mst_agent.AXI4LITE_WRITE_BURST(dma_ddr_ptr_hi, 0, ddr_addr[63:32], axi_cfg_bresp);
        // base_addr
        mst_agent.AXI4LITE_WRITE_BURST(dma_spm_ptr, 0, base_addr, axi_cfg_bresp);
        // size_bytes
        mst_agent.AXI4LITE_WRITE_BURST(dma_data_size_bytes, 0, size_bytes, axi_cfg_bresp);
        // cmd
        mst_agent.AXI4LITE_WRITE_BURST(dma_cmd, 0, command, axi_cfg_bresp);
        wait_time(5);
        // start
        mst_agent.AXI4LITE_WRITE_BURST(dma_rd_start, 0, {20'b0, id, 1'b1}, axi_cfg_bresp);
    endtask

    task wr_cfg;
        input [AXI_ADDR_WIDTH-1:0] ddr_addr;
        input [AXI_XFER_SIZE_WIDTH-1:0] size_bytes;
        input [AXI_ADDR_WIDTH-2:0] base_addr;
        // logic [31:0] wr_start_val;
        // data_ptr
        mst_agent.AXI4LITE_WRITE_BURST(dma_ddr_ptr_lo, 0, ddr_addr[31:0], axi_cfg_bresp);
        mst_agent.AXI4LITE_WRITE_BURST(dma_ddr_ptr_hi, 0, ddr_addr[63:32], axi_cfg_bresp);
        // base_addr
        mst_agent.AXI4LITE_WRITE_BURST(dma_spm_ptr, 0, base_addr, axi_cfg_bresp);
        // size_bytes
        mst_agent.AXI4LITE_WRITE_BURST(dma_data_size_bytes, 0, size_bytes, axi_cfg_bresp);
        wait_time(5);
        // start
        mst_agent.AXI4LITE_WRITE_BURST(dma_wr_start, 0, 32'b1, axi_cfg_bresp);
    endtask

    task wait_rd_done;
        logic [31:0] done_val;
        do begin
            mst_agent.AXI4LITE_READ_BURST(glb_done, 0, done_val, axi_cfg_rresp);
        end while(done_val[0] != 'b1);
    endtask

    task wait_wr_done;
        logic [31:0] done_val;
        do begin
            mst_agent.AXI4LITE_READ_BURST(glb_done, 0, done_val, axi_cfg_rresp);
        end while(done_val[1] != 'b1);
    endtask

    // init axi slv vip memory model via backdoor mem write
    // put 8192*4 data into mem
    task slv_mem_init;
        // addr_gen counter
        cnt = '0;
        clr = $fopen(AXI_SLV_VIP_MEM_INIT, "r");
        while(!$feof(clr)) begin
            $fscanf(clr, "%b", mtest_data0);
            $fscanf(clr, "%b", mtest_data1);
            $fscanf(clr, "%b", mtest_data2);
            $fscanf(clr, "%b", mtest_data3);
            $fscanf(clr, "%b", mtest_data4);
            $fscanf(clr, "%b", mtest_data5);
            $fscanf(clr, "%b", mtest_data6);
            $fscanf(clr, "%b", mtest_data7);
            frd_data = {mtest_data7, mtest_data6, mtest_data5, mtest_data4, mtest_data3, mtest_data2, mtest_data1, mtest_data0};
            slv_agent.mem_model.backdoor_memory_write(.addr(cnt), .payload(frd_data));
            cnt = cnt + 'd64;
        end
        $fclose(clr);
    endtask

    task tb_run;
        //spm_init;
        slv_mem_init;
        wait_rst_n;
        // rd_cfg(.ddr_addr('d4096), .size_bytes('d65535), .base_addr('d8192), .command('d1));
        // wait(spm_tb.u_spm_top.rd_done == 1'b1);
        // wait_random_time;
        // wr_cfg(.ddr_addr('d4096), .size_bytes('d65535), .base_addr('d8192));
        // wait(spm_tb.u_spm_top.wr_done == 1'b1);
        wait_random_time;
        encode_cfg(.encoder_addr('d0));
        rd_cfg(.ddr_addr('d0), .size_bytes('d65536), .base_addr('d0), .command('d2), .id('d1));
        wait_rd_done;
        encode_cfg(.encoder_addr('d256));
        rd_cfg(.ddr_addr('d65536), .size_bytes('d65536), .base_addr('d128), .command('d2), .id('d2));
        wait_wr_done;
    endtask

    task tb_monitor;
        int poly_cnt;
        poly_cnt = 128*2 - 1;
        vp_cnt = 0;
        res = $fopen(RES_FILE_PATH, "w");
        while(poly_cnt >= 0) begin
            if (spm_tb.u_encoder_top.u_controller.encode_wr_en) begin
                poly_cnt -= 1;
                wait_time(1);
            end else begin
                wait_time(1);
            end
        end
        while(vp_cnt <= 383) begin
            rd(vp_cnt, i_vp_rd_addr, i_vp_wr_en);
            if (!$isunknown(o_vp_rd_data)) begin
                for(int i=0; i<128; i++) begin
                    $fwrite(res, "%d \n", $signed(o_vp_rd_data[i*64+:64]));
                end
            end
            vp_cnt += 1;
            wait_time(1);
        end
        wait_time(10);
        $fclose(res);
    endtask


    initial begin
        clk = 1'b0;
        slv_agent = new("SLV_VIP", spm_tb.u_axi_vip_0.inst.IF);
        mst_agent = new("MST_VIP", spm_tb.u_axi_vip_1.inst.IF);
        slv_agent.start_slave();
        mst_agent.start_master();
        fork
            tb_run;
            tb_monitor;
        join
        $finish;
    end

endmodule