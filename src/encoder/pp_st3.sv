//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: ENCODER
// Module Name: pp_st3
// Modify Date: 
//
// Description:
// ping pang buffer stage 3
//////////////////////////////////////////////////
module pp_st3 #(
    parameter IN_DATA_WIDTH  = 64,
    parameter IN_ADDR_WIDTH  = 7,
    parameter OUT_DATA_WIDTH = 8192,
    parameter OUT_ADDR_WIDTH = 2,
    parameter LATENCY        = 1,
    parameter STAGE          = 3,
    parameter CHANNEL_NUM    = 4,
    parameter BANK_NUM      = CHANNEL_NUM
) (
    input                               clk,
    input                               rst_n,
    input                               st3_sel,
    input        [IN_DATA_WIDTH-1:0]    st3_wdata [CHANNEL_NUM],
    input                               st3_wen,
    input        [IN_ADDR_WIDTH-1:0]    st3_waddr,
    input        [OUT_ADDR_WIDTH-1:0]   st3_raddr,
    output logic [OUT_DATA_WIDTH-1:0]   st3_rdata
);

    logic [IN_ADDR_WIDTH-1:0]  waddr_0, waddr_1;
    logic [OUT_ADDR_WIDTH-1:0] raddr_0, raddr_1;
    logic [IN_DATA_WIDTH-1:0]  wdata_0 [CHANNEL_NUM], wdata_1 [CHANNEL_NUM];
    logic [OUT_DATA_WIDTH-1:0] rdata_0, rdata_1;
    logic wen_0, wen_1;

    // sel == 0 wr 0 rd 1
    // sel == 1 wr 1 rd 0
    always_comb begin
            raddr_0 = '0;
            raddr_1 = '0;
            waddr_0 = '0;
            waddr_1 = '0;
            wdata_0 = '{default: '0};
            wdata_1 = '{default: '0};
        if (~st3_sel) begin
            wen_0   = st3_wen;
            wen_1   = 1'b0;
            wdata_0 = st3_wdata;
            waddr_0 = st3_waddr;
            raddr_1 = st3_raddr;
        end
        else begin
            wen_0   = 1'b0;
            wen_1   = st3_wen;
            wdata_1 = st3_wdata;
            waddr_1 = st3_waddr;
            raddr_0 = st3_raddr;
        end
    end

    st3_bank #(
        .IN_ADDR_WIDTH  (IN_ADDR_WIDTH),
        .OUT_ADDR_WIDTH (OUT_ADDR_WIDTH),
        .IN_DATA_WIDTH  (IN_DATA_WIDTH),
        .OUT_DATA_WIDTH (OUT_DATA_WIDTH),
        .LATENCY        (LATENCY),
        .CHANNEL_NUM    (CHANNEL_NUM)
    ) u_st3_0 (
        .clk            (clk),
        .waddr_i        (waddr_0),
        .raddr_i        (raddr_0),
        .wdata_i        (wdata_0),
        .we_i           (wen_0),
        .re_i           (~wen_0),
        .rdata_o        (rdata_0)
    );

    st3_bank #(
        .IN_ADDR_WIDTH  (IN_ADDR_WIDTH),
        .OUT_ADDR_WIDTH (OUT_ADDR_WIDTH),
        .IN_DATA_WIDTH  (IN_DATA_WIDTH),
        .OUT_DATA_WIDTH (OUT_DATA_WIDTH),
        .LATENCY        (LATENCY),
        .CHANNEL_NUM    (CHANNEL_NUM)
    ) u_st3_1 (
        .clk            (clk),
        .waddr_i        (waddr_1),
        .raddr_i        (raddr_1),
        .wdata_i        (wdata_1),
        .we_i           (wen_1),
        .re_i           (~wen_1),
        .rdata_o        (rdata_1)
    );

    logic [LATENCY-1:0] st3_sel_r;

    always_ff @(posedge clk) begin
        st3_sel_r[0] <= st3_sel;
        for (int i=0; i<LATENCY-1; i++) begin
            st3_sel_r[i+1] <= st3_sel_r[i];
        end
    end

    always_comb begin
        if (~st3_sel_r[LATENCY-1]) begin
            st3_rdata = rdata_1;
        end
        else begin
            st3_rdata = rdata_0;
        end
    end

endmodule : pp_st3

module st3_bank #(
    parameter IN_ADDR_WIDTH  = 7,
    parameter OUT_ADDR_WIDTH = 2,
    parameter IN_DATA_WIDTH  = 64,
    parameter OUT_DATA_WIDTH = 8192,
    parameter LATENCY        = 1,
    parameter CHANNEL_NUM    = 4
) (
    input                               clk,
    input        [IN_ADDR_WIDTH-1:0]    waddr_i,
    input        [OUT_ADDR_WIDTH-1:0]   raddr_i,
    input        [IN_DATA_WIDTH-1:0]    wdata_i [CHANNEL_NUM],
    input                               we_i,
    input                               re_i,
    output logic [OUT_DATA_WIDTH-1:0]   rdata_o
);
    logic [OUT_DATA_WIDTH-1:0] mem [CHANNEL_NUM];
    (* MAX_FANOUT = 100 *) logic [OUT_DATA_WIDTH-1:0] mem_reg [LATENCY-1:0];

    always_ff @(posedge clk) begin
        if (we_i) begin
            for (int i=0; i<CHANNEL_NUM; i++) begin
                mem[i][IN_DATA_WIDTH*waddr_i+:IN_DATA_WIDTH] <= wdata_i[i];
            end
        end
    end

    always_ff @(posedge clk) begin
        if (re_i)
            mem_reg[0] <= mem[raddr_i];
    end

    always_ff @(posedge clk) begin
        for (int i=0; i<LATENCY-1; i++)
            mem_reg[i+1] <= mem_reg[i];
    end

    assign rdata_o = mem_reg[LATENCY-1];

endmodule : st3_bank