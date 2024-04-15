//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: ENCODER
// Module Name: pp_st1
// Modify Date: 
//
// Description:
// ping pang buffer stage 1
//////////////////////////////////////////////////
module pp_st1 #(
    parameter DATA_WIDTH = 68,
    parameter ADDR_WIDTH = 12,
    parameter LATENCY    = 1,
    parameter STAGE      = 1,
    parameter BANK_NUM   = 4
) (
    input                           clk,
    input                           rst_n,

    input                           st1_sel,
    input  logic [DATA_WIDTH-1:0]   st1_wdata,
    input                           st1_wen,
    input  logic [ADDR_WIDTH-1:0]   st1_waddr,
    input  logic [ADDR_WIDTH-1:0]   st1_raddr,
    input  logic                    rd_stage_ptr,
    output logic [DATA_WIDTH*4-1:0] st1_rdata
);
    logic [ADDR_WIDTH-$clog2(BANK_NUM)-1:0]  waddr_0;
    logic [ADDR_WIDTH-$clog2(BANK_NUM)-1:0]  waddr_1;
    logic [ADDR_WIDTH-$clog2(BANK_NUM)-1:0]  raddr_0;
    logic [ADDR_WIDTH-$clog2(BANK_NUM)-1:0]  raddr_1;
    logic [DATA_WIDTH-1:0]    wdata_0;
    logic [DATA_WIDTH-1:0]    wdata_1;
    logic [DATA_WIDTH*4-1:0]  rdata_0;
    logic [DATA_WIDTH*4-1:0]  rdata_1;

    logic  [BANK_NUM-1:0]     wen_0;
    logic  [BANK_NUM-1:0]     wen_1;

    // sel == 0 wr 0 rd 1
    // sel == 1 wr 1 rd 0
    logic [BANK_NUM-1:0] st1_waddr_bank_sel;
    idx2oh #(.IDX_WIDTH($clog2(BANK_NUM))) u_idx2oh0 (.index(st1_waddr[$clog2(BANK_NUM)-1:0]), .one_hot(st1_waddr_bank_sel));
    always_comb begin
            raddr_0 = '0;
            raddr_1 = '0;
            waddr_0 = '0;
            waddr_1 = '0;
            wdata_0 = '0;
            wdata_1 = '0;
        if(~st1_sel) begin
            wen_0 = st1_waddr_bank_sel & {(BANK_NUM){st1_wen}};
            wen_1 = {(BANK_NUM){1'b0}};
            wdata_0 = st1_wdata;
            waddr_0 = st1_waddr[ADDR_WIDTH-1:$clog2(BANK_NUM)];
            raddr_1 = st1_raddr;
        end else begin
            wen_0 = {(BANK_NUM){1'b0}};
            wen_1 = st1_waddr_bank_sel & {(BANK_NUM){st1_wen}};
            wdata_1 = st1_wdata;
            waddr_1 = st1_waddr[ADDR_WIDTH-1:$clog2(BANK_NUM)];
            raddr_0 = st1_raddr;
        end
    end

    ram_bank #(
        .BANK_DATA_WIDTH (DATA_WIDTH*BANK_NUM),
        .ADDR_WIDTH      (ADDR_WIDTH-$clog2(BANK_NUM)),
        .LATENCY         (LATENCY),
        .BANK_NUM        (BANK_NUM),
        .STAGE           (STAGE)
    ) u_st1_ram0 (
        .clk             (clk),
        .raddr           (raddr_0),
        .waddr           (waddr_0),
        .wdata_per_bank  (wdata_0),
        .wdata           ('0),
        .wen             (wen_0),
        .rdata           (rdata_0)
    );

    ram_bank #(
        .BANK_DATA_WIDTH (DATA_WIDTH*BANK_NUM),
        .ADDR_WIDTH      (ADDR_WIDTH-$clog2(BANK_NUM)),
        .LATENCY         (LATENCY),
        .BANK_NUM        (BANK_NUM),
        .STAGE           (STAGE)
    ) u_st1_ram1 (
        .clk             (clk),
        .raddr           (raddr_1),
        .waddr           (waddr_1),
        .wdata_per_bank  (wdata_1),
        .wdata           ('0),
        .wen             (wen_1),
        .rdata           (rdata_1)
    );

    logic [LATENCY-1:0] st1_sel_r;
    logic [LATENCY:0]   rd_stage_ptr_r;
    logic [DATA_WIDTH*4-1:0] rdata_0_n;
    logic [DATA_WIDTH*4-1:0] rdata_1_n;

    always_comb begin
        rdata_0_n = rdata_0;
        rdata_1_n = rdata_1;
        if(rd_stage_ptr_r[LATENCY]) begin
            for(int i=0; i<4; i++) begin
                rdata_0_n[i*DATA_WIDTH+:DATA_WIDTH] = {rdata_0[((4-1-i)*DATA_WIDTH+DATA_WIDTH/2)+:(DATA_WIDTH/2)], ~rdata_0[(4-1-i)*DATA_WIDTH+:(DATA_WIDTH/2)]+1};
                rdata_1_n[i*DATA_WIDTH+:DATA_WIDTH] = {rdata_1[((4-1-i)*DATA_WIDTH+DATA_WIDTH/2)+:(DATA_WIDTH/2)], ~rdata_1[(4-1-i)*DATA_WIDTH+:(DATA_WIDTH/2)]+1};
            end
        end
    end

    always_ff @(posedge clk) begin
        st1_sel_r[0] <= st1_sel;
        for (int i=0; i<LATENCY-1; ++i) begin
            st1_sel_r[i+1] <= st1_sel_r[i];
        end
    end

    always_ff @(posedge clk) begin
        rd_stage_ptr_r[0] <= rd_stage_ptr;
        for (int i=0; i<LATENCY; ++i) begin
            rd_stage_ptr_r[i+1] <= rd_stage_ptr_r[i];
        end
    end

    always_comb begin
        if(~st1_sel_r[LATENCY-1]) begin
            st1_rdata = rdata_1_n;
        end else begin
            st1_rdata = rdata_0_n;
        end
    end

endmodule : pp_st1
