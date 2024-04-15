import axi_vip_pkg::*;
import axi_vip_0_pkg::*;
import axi_vip_1_pkg::*;
`timescale 1ns/100ps
module herv_tb;
parameter PERIOD                = 10;
parameter AXI_ADDR_WIDTH        = 64;
parameter AXI_DATA_WIDTH        = 512;
parameter AXI_XFER_SIZE_WIDTH   = 32;
parameter WFILE_PATH            = "";
parameter RFILE_PATH            = "";
parameter ID_WIDTH              = 11;
parameter NB_PIPE               = 2;
bit clk;
bit rst_n;
always #(PERIOD/2) clk = ~clk;
axi_vip_1_slv_mem_t slv_agent;
axi_vip_0_mst_t mst_agent;

logic [31 : 0]   axi_cfg_awaddr  ;
logic [2 : 0]    axi_cfg_awprot  ;
logic            axi_cfg_awvalid ;
logic            axi_cfg_awready ;
logic [31 : 0]   axi_cfg_wdata   ;
logic [3 : 0]    axi_cfg_wstrb   ;
logic            axi_cfg_wvalid  ;
logic            axi_cfg_wready  ;
logic            axi_cfg_bvalid  ;
logic [1 : 0]    axi_cfg_bresp   ;
logic            axi_cfg_bready  ;
logic [31 : 0]   axi_cfg_araddr  ;
logic [2 : 0]    axi_cfg_arprot  ;
logic            axi_cfg_arvalid ;
logic            axi_cfg_arready ;
logic [31 : 0]   axi_cfg_rdata   ;
logic [1 : 0]    axi_cfg_rresp   ;
logic            axi_cfg_rvalid  ;
logic            axi_cfg_rready  ;
logic [11 : 0]   axi_awid     ;
logic [63 : 0]   axi_awaddr   ;
logic [7 : 0]    axi_awlen    ;
logic [2 : 0]    axi_awsize   ;
logic [1 : 0]    axi_awburst  ;
logic            axi_awlock   ;
logic [3 : 0]    axi_awcache  ;
logic [2 : 0]    axi_awprot   ;
logic            axi_awvalid  ;
logic            axi_awready  ;
logic [511 : 0]  axi_wdata    ;
logic [63 : 0]   axi_wstrb    ;
logic            axi_wlast    ;
logic            axi_wvalid   ;
logic            axi_wready   ;
logic [11 : 0]   axi_bid      ;
logic [1 : 0]    axi_bresp    ;
logic            axi_bvalid   ;
logic            axi_bready   ;
logic [11 : 0]   axi_arid     ;
logic [63 : 0]   axi_araddr   ;
logic [7 : 0]    axi_arlen    ;
logic [2 : 0]    axi_arsize   ;
logic [1 : 0]    axi_arburst  ;
logic            axi_arlock   ;
logic [3 : 0]    axi_arcache  ;
logic [2 : 0]    axi_arprot   ;
logic            axi_arvalid  ;
logic            axi_arready  ;
logic [11 : 0]   axi_rid      ;
logic [511 : 0]  axi_rdata    ;
logic [1 : 0]    axi_rresp    ;
logic            axi_rlast    ;
logic            axi_rvalid   ;
logic            axi_rready   ;
logic            rd_en_r[NB_PIPE-1:0];

assign axi_cfg_arprot = '0;
assign axi_cfg_awprot = '0;

    herv u_herv (
        .clk                 (clk),
        .rst_n               (rst_n),
        .axi_cfg_awaddr      (axi_cfg_awaddr),
        .axi_cfg_awprot      (axi_cfg_awprot),
        .axi_cfg_awvalid     (axi_cfg_awvalid),
        .axi_cfg_awready     (axi_cfg_awready),
        .axi_cfg_wdata       (axi_cfg_wdata),
        .axi_cfg_wstrb       (axi_cfg_wstrb),
        .axi_cfg_wvalid      (axi_cfg_wvalid),
        .axi_cfg_wready      (axi_cfg_wready),
        .axi_cfg_bvalid      (axi_cfg_bvalid),
        .axi_cfg_bresp       (axi_cfg_bresp),
        .axi_cfg_bready      (axi_cfg_bready),
        .axi_cfg_araddr      (axi_cfg_araddr),
        .axi_cfg_arprot      (axi_cfg_arprot),
        .axi_cfg_arvalid     (axi_cfg_arvalid),
        .axi_cfg_arready     (axi_cfg_arready),
        .axi_cfg_rdata       (axi_cfg_rdata),
        .axi_cfg_rresp       (axi_cfg_rresp),
        .axi_cfg_rvalid      (axi_cfg_rvalid),
        .axi_cfg_rready      (axi_cfg_rready),
        .axi_awid            (axi_awid),
        .axi_awaddr          (axi_awaddr),
        .axi_awlen           (axi_awlen),
        .axi_awsize          (axi_awsize),
        .axi_awburst         (axi_awburst),
        .axi_awlock          (axi_awlock),
        .axi_awcache         (axi_awcache),
        .axi_awprot          (axi_awprot),
        .axi_awvalid         (axi_awvalid),
        .axi_awready         (axi_awready),
        .axi_wdata           (axi_wdata),
        .axi_wstrb           (axi_wstrb),
        .axi_wlast           (axi_wlast),
        .axi_wvalid          (axi_wvalid),
        .axi_wready          (axi_wready),
        .axi_bid             (axi_bid),
        .axi_bresp           (axi_bresp),
        .axi_bvalid          (axi_bvalid),
        .axi_bready          (axi_bready),
        .axi_arid            (axi_arid),
        .axi_araddr          (axi_araddr),
        .axi_arlen           (axi_arlen),
        .axi_arsize          (axi_arsize),
        .axi_arburst         (axi_arburst),
        .axi_arlock          (axi_arlock),
        .axi_arcache         (axi_arcache),
        .axi_arprot          (axi_arprot),
        .axi_arvalid         (axi_arvalid),
        .axi_arready         (axi_arready),
        .axi_rid             (axi_rid),
        .axi_rdata           (axi_rdata),
        .axi_rresp           (axi_rresp),
        .axi_rlast           (axi_rlast),
        .axi_rvalid          (axi_rvalid),
        .axi_rready          (axi_rready)
    );

    axi_vip_1 u_axi_vip_1 (
      .aclk                     (clk),
      .aresetn                  (rst_n),
      .s_axi_awid               (axi_awid),
      .s_axi_awaddr             (axi_awaddr),
      .s_axi_awlen              (axi_awlen),
      .s_axi_awsize             (axi_awsize),
      .s_axi_awburst            (axi_awburst),
      .s_axi_awlock             (axi_awlock),
      .s_axi_awcache            (axi_awcache),
      .s_axi_awprot             (axi_awprot),
      .s_axi_awvalid            (axi_awvalid),
      .s_axi_awready            (axi_awready),
      .s_axi_wdata              (axi_wdata),
      .s_axi_wstrb              (axi_wstrb),
      .s_axi_wlast              (axi_wlast),
      .s_axi_wvalid             (axi_wvalid),
      .s_axi_wready             (axi_wready),
      .s_axi_bid                (axi_bid),
      .s_axi_bresp              (axi_bresp),
      .s_axi_bvalid             (axi_bvalid),
      .s_axi_bready             (axi_bready),
      .s_axi_arid               (axi_arid),
      .s_axi_araddr             (axi_araddr),
      .s_axi_arlen              (axi_arlen),
      .s_axi_arsize             (axi_arsize),
      .s_axi_arburst            (axi_arburst),
      .s_axi_arlock             (axi_arlock),
      .s_axi_arcache            (axi_arcache),
      .s_axi_arprot             (axi_arprot),
      .s_axi_arvalid            (axi_arvalid),
      .s_axi_arready            (axi_arready),
      .s_axi_rid                (axi_rid),
      .s_axi_rdata              (axi_rdata),
      .s_axi_rresp              (axi_rresp),
      .s_axi_rlast              (axi_rlast),
      .s_axi_rvalid             (axi_rvalid),
      .s_axi_rready             (axi_rready)
    );

    axi_vip_0 u_axi_vip_0 (
        .aclk               (clk),
        .aresetn            (rst_n),
        .m_axi_awaddr       (axi_cfg_awaddr),
        .m_axi_awvalid      (axi_cfg_awvalid),
        .m_axi_awready      (axi_cfg_awready),
        .m_axi_wdata        (axi_cfg_wdata),
        .m_axi_wstrb        (axi_cfg_wstrb),
        .m_axi_wvalid       (axi_cfg_wvalid),
        .m_axi_wready       (axi_cfg_wready),
        .m_axi_bresp        (axi_cfg_bresp),
        .m_axi_bvalid       (axi_cfg_bvalid),
        .m_axi_bready       (axi_cfg_bready),
        .m_axi_araddr       (axi_cfg_araddr),
        .m_axi_arvalid      (axi_cfg_arvalid),
        .m_axi_arready      (axi_cfg_arready),
        .m_axi_rdata        (axi_cfg_rdata),
        .m_axi_rresp        (axi_cfg_rresp),
        .m_axi_rvalid       (axi_cfg_rvalid),
        .m_axi_rready       (axi_cfg_rready)
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


    task tb_run;
        wait_rst_n;
        rd_cfg(.ddr_addr('h1000), .size_bytes('d65535), .base_addr('d8192), .command('d1), .id('d0));
        wait_rd_done;
        wait_random_time;
        wr_cfg(.ddr_addr('h1000), .size_bytes('d65535), .base_addr('d8192));
        wait_wr_done;
        wait_time(10);
    endtask

    int wfid;
    int rfid;
    task tb_monitor;
        wfid = $fopen(WFILE_PATH, "w");
        rfid = $fopen(RFILE_PATH, "w");
        wait(herv_tb.u_herv.u_mem_top.i_axi_en);
        fork
            monitor_wr;
            monitor_rd;
        join
    endtask

    task monitor_wr;
        wait(herv_tb.u_herv.u_mem_top.axi_rd_wren);
        while (herv_tb.u_herv.u_mem_top.axi_rd_wren) begin
            @(posedge clk);
            $fwrite(wfid, "%h \n", $unsigned(herv_tb.u_herv.u_mem_top.axi_rd_wrdata));
        end
    endtask

    task monitor_rd;
        wait(rd_en_r[NB_PIPE-1] & !herv_tb.u_herv.u_mem_top.wr_done);
        while (!herv_tb.u_herv.u_mem_top.wr_done) begin
            if (rd_en_r[NB_PIPE-1])
                $fwrite(rfid, "%h \n", $unsigned(herv_tb.u_herv.u_mem_top.axi_wr_rddata));
            @(posedge clk);
        end
    endtask


    always_ff @(posedge clk) begin
        rd_en_r[0] <= herv_tb.u_herv.u_mem_top.axi_wr_rden;
        for (int i=0; i<NB_PIPE-1; ++i) begin
            rd_en_r[i+1] <= rd_en_r[i];
        end
    end

    initial begin
        clk = 1'b0;
        slv_agent = new("SLV_VIP", herv_tb.u_axi_vip_1.inst.IF);
        mst_agent = new("MST_VIP", herv_tb.u_axi_vip_0.inst.IF);
        slv_agent.start_slave();
        mst_agent.start_master();
        // tb_run;
        fork
            tb_run;
            tb_monitor;
        join_any
        $fclose(wfid);
        $fclose(rfid);
        $finish;
    end

endmodule