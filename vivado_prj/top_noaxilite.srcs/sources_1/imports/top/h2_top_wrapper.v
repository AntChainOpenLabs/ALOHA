`include "vp_defines.vh"
`include "common_defines.vh"

module h2_top_wrapper #(
        parameter AXI_ADDR_WIDTH        = 64,
        parameter AXI_DATA_WIDTH        = 512
    )(
        input                   clk,
        input                   rst_n,

        // to ddr
        output  wire                          axi_awvalid,
        input   wire                          axi_awready,
        output  wire [AXI_ADDR_WIDTH-1:0]     axi_awaddr,
        output  wire [7:0]                    axi_awlen,
        output  wire                          axi_wvalid,
        input   wire                          axi_wready,
        output  wire [AXI_DATA_WIDTH-1:0]     axi_wdata,
        output  wire [AXI_DATA_WIDTH/8-1:0]   axi_wstrb,
        output  wire                          axi_wlast,
        input   wire                          axi_bvalid,
        output  wire                          axi_bready,
        output  wire                          axi_arvalid,
        input   wire                          axi_arready,
        output  wire [AXI_ADDR_WIDTH-1:0]     axi_araddr,
        output  wire [7:0]                    axi_arlen,
        input   wire                          axi_rvalid,
        output  wire                          axi_rready,
        input   wire [AXI_DATA_WIDTH-1:0]     axi_rdata,
        input   wire                          axi_rlast,

        // from arm
        input   wire [31:0]                   axi_cfg_awaddr,
        input   wire                          axi_cfg_awvalid,
        output  wire                          axi_cfg_awready,
        input   wire [31:0]                   axi_cfg_wdata,
        input   wire [3:0]                    axi_cfg_wstrb,
        input   wire                          axi_cfg_wvalid,
        output  wire                          axi_cfg_wready,
        output  wire [1:0]                    axi_cfg_bresp,
        output  wire                          axi_cfg_bvalid,
        input   wire                          axi_cfg_bready,
        input   wire [31:0]                   axi_cfg_araddr,
        input   wire                          axi_cfg_arvalid,
        output  wire                          axi_cfg_arready,
        output  wire [31:0]                   axi_cfg_rdata,
        output  wire [1:0]                    axi_cfg_rresp,
        output  wire                          axi_cfg_rvalid,
        input   wire                          axi_cfg_rready
    );

    h2_top #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH)
    )i_h2_top(
        .clk(clk),
        .rst_n(rst_n),

        .axi_awvalid(axi_awvalid),
        .axi_awready(axi_awready),
        .axi_awaddr(axi_awaddr),
        .axi_awlen(axi_awlen),
        .axi_wvalid(axi_wvalid),
        .axi_wready(axi_wready),
        .axi_wdata(axi_wdata),
        .axi_wstrb(axi_wstrb),
        .axi_wlast(axi_wlast),
        .axi_bvalid(axi_bvalid),
        .axi_bready(axi_bready),
        .axi_arvalid(axi_arvalid),
        .axi_arready(axi_arready),
        .axi_araddr(axi_araddr),
        .axi_arlen(axi_arlen),
        .axi_rvalid(axi_rvalid),
        .axi_rready(axi_rready),
        .axi_rdata(axi_rdata),
        .axi_rlast(axi_rlast),

        .axi_cfg_awaddr(axi_cfg_awaddr),
        .axi_cfg_awvalid(axi_cfg_awvalid),
        .axi_cfg_awready(axi_cfg_awready),
        .axi_cfg_wdata(axi_cfg_wdata),
        .axi_cfg_wstrb(axi_cfg_wstrb),
        .axi_cfg_wvalid(axi_cfg_wvalid),
        .axi_cfg_wready(axi_cfg_wready),
        .axi_cfg_bresp(axi_cfg_bresp),
        .axi_cfg_bvalid(axi_cfg_bvalid),
        .axi_cfg_bready(axi_cfg_bready),
        .axi_cfg_araddr(axi_cfg_araddr),
        .axi_cfg_arvalid(axi_cfg_arvalid),
        .axi_cfg_arready(axi_cfg_arready),
        .axi_cfg_rdata(axi_cfg_rdata),
        .axi_cfg_rresp(axi_cfg_rresp),
        .axi_cfg_rvalid(axi_cfg_rvalid),
        .axi_cfg_rready(axi_cfg_rready)
    );

endmodule