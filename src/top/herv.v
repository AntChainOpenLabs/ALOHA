//================================================
//
//  herv
//  herv top file for FPGA
//  Author: Yanheng Lu(yanheng.lyh@ablibaba-inc.com)
//  Date: 20230515
//
//================================================

module herv(
     input  wire            clk                 ,
     input  wire            rst_n               ,
     //AXI_LITE CONFIG//
     input  wire [31 : 0]   axi_cfg_awaddr      ,
     input  wire [2 : 0]    axi_cfg_awprot      ,
     input  wire            axi_cfg_awvalid     ,
     output wire            axi_cfg_awready     ,

     input  wire [31 : 0]   axi_cfg_wdata       ,
     input  wire [3 : 0]    axi_cfg_wstrb       ,
     input  wire            axi_cfg_wvalid      ,
     output wire            axi_cfg_wready      ,

     output wire            axi_cfg_bvalid      ,
     output wire [1 : 0]    axi_cfg_bresp       ,
     input  wire            axi_cfg_bready      ,

     input  wire [31 : 0]   axi_cfg_araddr      ,
     input  wire [2 : 0]    axi_cfg_arprot      ,
     input  wire            axi_cfg_arvalid     ,
     output wire            axi_cfg_arready     ,

     output wire [31 : 0]   axi_cfg_rdata       ,
     output wire [1 : 0]    axi_cfg_rresp       ,
     output wire            axi_cfg_rvalid      ,
     input  wire            axi_cfg_rready      ,

     //AXI_DATA//
     output wire [11 : 0]   axi_awid            ,
     output wire [63 : 0]   axi_awaddr          ,
     output wire [7 : 0]    axi_awlen           ,
     output wire [2 : 0]    axi_awsize          ,
     output wire [1 : 0]    axi_awburst         ,
     output wire            axi_awlock          ,
     output wire [3 : 0]    axi_awcache         ,
     output wire [2 : 0]    axi_awprot          ,
     output wire            axi_awvalid         ,
     input  wire            axi_awready         ,
     output wire [511 : 0]  axi_wdata           ,
     output wire [63 : 0]   axi_wstrb           ,
     output wire            axi_wlast           ,
     output wire            axi_wvalid          ,
     input  wire            axi_wready          ,
     input  wire [11 : 0]   axi_bid             ,
     input  wire [1 : 0]    axi_bresp           ,
     input  wire            axi_bvalid          ,
     output wire            axi_bready          ,
     output wire [11 : 0]   axi_arid            ,
     output wire [63 : 0]   axi_araddr          ,
     output wire [7 : 0]    axi_arlen           ,
     output wire [2 : 0]    axi_arsize          ,
     output wire [1 : 0]    axi_arburst         ,
     output wire            axi_arlock          ,
     output wire [3 : 0]    axi_arcache         ,
     output wire [2 : 0]    axi_arprot          ,
     output wire            axi_arvalid         ,
     input  wire            axi_arready         ,
     input  wire [11 : 0]   axi_rid             ,
     input  wire [511 : 0]  axi_rdata           ,
     input  wire [1 : 0]    axi_rresp           ,
     input  wire            axi_rlast           ,
     input  wire            axi_rvalid          ,
     output wire            axi_rready
 );

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

  parameter URAM_ADDR_WIDTH     = 'd12;
  parameter BANK_NUM            = 'd4;
  parameter SPM_ADDR_WIDTH      = $clog2(BANK_NUM) + URAM_ADDR_WIDTH;
  parameter NUM_LANE            = 128;
  parameter DATA_WIDTH          = 64;
  parameter NB_PIPE             = 2;
  parameter AXI_ADDR_WIDTH      = 64;
  parameter AXI_DATA_WIDTH      = 512;
  parameter AXI_XFER_SIZE_WIDTH = 32;
  parameter INCLUDE_DATA_FIFO   = 0;

    mem_top #(
        .URAM_ADDR_WIDTH       ( URAM_ADDR_WIDTH     ),
        .BANK_NUM              ( BANK_NUM            ),
        .SPM_ADDR_WIDTH        ( SPM_ADDR_WIDTH      ),
        .NUM_LANE              ( NUM_LANE            ),
        .DATA_WIDTH            ( DATA_WIDTH          ),
        .NB_PIPE               ( NB_PIPE             ),
        .AXI_ADDR_WIDTH        ( AXI_ADDR_WIDTH      ),
        .AXI_DATA_WIDTH        ( AXI_DATA_WIDTH      ),
        .AXI_XFER_SIZE_WIDTH   ( AXI_XFER_SIZE_WIDTH ),
        .INCLUDE_DATA_FIFO     ( INCLUDE_DATA_FIFO   )
    ) u_mem_top (
        .clk                   ( clk                 ),
        .rst_n                 ( rst_n               ),
        .axi_awvalid           ( axi_awvalid         ),
        .axi_awready           ( axi_awready         ),
        .axi_awaddr            ( axi_awaddr          ),
        .axi_awlen             ( axi_awlen           ),
        .axi_wvalid            ( axi_wvalid          ),
        .axi_wready            ( axi_wready          ),
        .axi_wdata             ( axi_wdata           ),
        .axi_wstrb             ( axi_wstrb           ),
        .axi_wlast             ( axi_wlast           ),
        .axi_bvalid            ( axi_bvalid          ),
        .axi_bready            ( axi_bready          ),
        .axi_arvalid           ( axi_arvalid         ),
        .axi_arready           ( axi_arready         ),
        .axi_araddr            ( axi_araddr          ),
        .axi_arlen             ( axi_arlen           ),
        .axi_rvalid            ( axi_rvalid          ),
        .axi_rready            ( axi_rready          ),
        .axi_rdata             ( axi_rdata           ),
        .axi_rlast             ( axi_rlast           ),
        .axi_cfg_awaddr        ( axi_cfg_awaddr      ),
        .axi_cfg_awvalid       ( axi_cfg_awvalid     ),
        .axi_cfg_awready       ( axi_cfg_awready     ),
        .axi_cfg_wdata         ( axi_cfg_wdata       ),
        .axi_cfg_wstrb         ( axi_cfg_wstrb       ),
        .axi_cfg_wvalid        ( axi_cfg_wvalid      ),
        .axi_cfg_wready        ( axi_cfg_wready      ),
        .axi_cfg_bresp         ( axi_cfg_bresp       ),
        .axi_cfg_bvalid        ( axi_cfg_bvalid      ),
        .axi_cfg_bready        ( axi_cfg_bready      ),
        .axi_cfg_araddr        ( axi_cfg_araddr      ),
        .axi_cfg_arvalid       ( axi_cfg_arvalid     ),
        .axi_cfg_arready       ( axi_cfg_arready     ),
        .axi_cfg_rdata         ( axi_cfg_rdata       ),
        .axi_cfg_rresp         ( axi_cfg_rresp       ),
        .axi_cfg_rvalid        ( axi_cfg_rvalid      ),
        .axi_cfg_rready        ( axi_cfg_rready      ),
        .i_encode_wr_en        ( 'b0                 ),
        .i_encode_wr_addr      ( 'b0                 ),
        .i_encode_wr_data      ( 'b0                 ),
        .encode_axis_tvalid    (                     ),
        .encode_axis_tready    ( 'b0                 ),
        .encode_axis_tlast     (                     ),
        .encode_axis_tdata     (                     ),
        .encode2spm_base_addr  (                     ),
        .encode_cfg_start      (                     ),
        .poly_id_o             ( 'b0                 ),
        .poly_id_i             (                     ),
        .i_vp_rd_addr          ( 'b0                 ),
        .i_vp_wr_en            ( 'b0                 ),
        .i_vp_wr_addr          ( 'b0                 ),
        .i_vp_wr_data          ( 'b0                 ),
        .o_vp_rd_data          (                     ),
        .o_ksk_wr_en           (                     ),
        .o_ksk_addr            (                     ),
        .o_ksk_wr_data         (                     )
    );

endmodule
