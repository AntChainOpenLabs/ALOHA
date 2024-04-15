//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: ENCODER
// Module Name: pp_st0
// Modify Date: 
//
// Description:
// ping pang buffer stage 0
//////////////////////////////////////////////////
module pp_st0 #(
    parameter IN_DATA_WIDTH  = 512,
    parameter IN_ADDR_WIDTH  = 10,
    parameter OUT_DATA_WIDTH = 64,
    parameter OUT_ADDR_WIDTH = 13,
    parameter LATENCY        = 1,
    parameter STAGE          = 0,
    parameter BANK_NUM       = 8

) (
    input                               clk,
    input                               rst_n,

    input  logic                        st0_sel,
    input  logic [IN_ADDR_WIDTH-1:0]    st0_waddr,
    input  logic [IN_DATA_WIDTH-1:0]    st0_wdata,
    input  logic                        st0_wen,

    input  logic [OUT_ADDR_WIDTH-1:0]   st0_raddr,
    input  logic                        st0_ren,
    output logic [OUT_DATA_WIDTH-1:0]   st0_re,
    output logic [OUT_DATA_WIDTH-1:0]   st0_im

);

    logic [OUT_ADDR_WIDTH-$clog2(BANK_NUM)-1:0] raddr_0;
    logic [IN_ADDR_WIDTH-1:0]                   waddr_0;
    logic [OUT_ADDR_WIDTH-$clog2(BANK_NUM)-1:0] raddr_1;
    logic [IN_ADDR_WIDTH-1:0]                   waddr_1;
    logic [IN_DATA_WIDTH-1:0] wdata_0;
    logic [IN_DATA_WIDTH-1:0] wdata_1;
    logic [IN_DATA_WIDTH-1:0] rdata_0;
    logic [IN_DATA_WIDTH-1:0] rdata_1;
    logic wen_0;
    logic wen_1;

    always_comb begin
            raddr_0 = '0;
            raddr_1 = '0;
            waddr_0 = '0;
            waddr_1 = '0;
            wdata_0 = '0;
            wdata_1 = '0;
        if(~st0_sel) begin
            waddr_0 = st0_waddr[IN_ADDR_WIDTH-1:0];
            raddr_1 = st0_raddr[OUT_ADDR_WIDTH-$clog2(BANK_NUM)-1:0];
            wdata_0 = st0_wdata;
            wen_0   = st0_wen;
            wen_1   = 1'b0;
        end else begin
            waddr_1 = st0_waddr[IN_ADDR_WIDTH-1:0];
            raddr_0 = st0_raddr[OUT_ADDR_WIDTH-$clog2(BANK_NUM)-1:0];
            wdata_1 = st0_wdata;
            wen_1   = st0_wen;
            wen_0   = 1'b0;
        end
    end

    ram_bank #(
        .BANK_DATA_WIDTH (IN_DATA_WIDTH),
        .ADDR_WIDTH      (IN_ADDR_WIDTH),
        .LATENCY         (LATENCY),
        .BANK_NUM        (BANK_NUM)
    ) u_st0_ram_0 (
        .clk            (clk),
        .raddr          (raddr_0),
        .waddr          (waddr_0),
        .wdata          (wdata_0),
        .wdata_per_bank ('0),
        .wen            ({(BANK_NUM){wen_0}}),
        .rdata          (rdata_0)
    );

    ram_bank #(
        .BANK_DATA_WIDTH (IN_DATA_WIDTH),
        .ADDR_WIDTH      (IN_ADDR_WIDTH),
        .LATENCY         (LATENCY),
        .BANK_NUM        (BANK_NUM)
    ) u_st0_ram_1 (
        .clk            (clk),
        .raddr          (raddr_1),
        .waddr          (waddr_1),
        .wdata          (wdata_1),
        .wen            ({(BANK_NUM){wen_1}}),
        .wdata_per_bank ('0),
        .rdata          (rdata_1)
    );

    logic [LATENCY-1:0] st0_sel_r;
    logic [$clog2(BANK_NUM)-1:0] st0_raddr_r [LATENCY-1:0];

    always_ff @(posedge clk) begin
        st0_sel_r[0] <= st0_sel;
        for(int i=0; i<LATENCY-1; i++) begin
            st0_sel_r[i+1] <= st0_sel_r[i];
        end
    end

    always_ff @(posedge clk) begin
        st0_raddr_r[0] <= st0_raddr[OUT_ADDR_WIDTH-1-:$clog2(BANK_NUM)];
        for(int i=0; i<LATENCY-1; i++) begin
            st0_raddr_r[i+1] <= st0_raddr_r[i];
        end
    end

    always_comb begin
        if(~st0_sel_r[LATENCY-1]) begin
            st0_re = rdata_1[st0_raddr_r[LATENCY-1]*OUT_DATA_WIDTH+:OUT_DATA_WIDTH];
            st0_im = rdata_1[(st0_raddr_r[LATENCY-1]+1)*OUT_DATA_WIDTH+:OUT_DATA_WIDTH];
        end else begin
            st0_re = rdata_0[st0_raddr_r[LATENCY-1]*OUT_DATA_WIDTH+:OUT_DATA_WIDTH];
            st0_im = rdata_0[(st0_raddr_r[LATENCY-1]+1)*OUT_DATA_WIDTH+:OUT_DATA_WIDTH];
        end
    end

endmodule : pp_st0


