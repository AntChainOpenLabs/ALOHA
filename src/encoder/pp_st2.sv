//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: ENCODER
// Module Name: pp_st2
// Modify Date: 
//
// Description:
// ping pang buffer stage 2
//////////////////////////////////////////////////
module pp_st2 #(
    parameter DATA_WIDTH = 68,
    parameter ADDR_WIDTH = 11,
    parameter LATENCY    = 1,
    parameter STAGE      = 2,
    parameter BANK_NUM   = 4
) (
    input                           clk,
    input                           rst_n,
    input                           st2_sel,
    input  logic [DATA_WIDTH*4-1:0] st2_wdata,
    input                           st2_wen,
    input  logic [ADDR_WIDTH-1:0]   st2_waddr,
    input  logic [ADDR_WIDTH-1:0]   st2_raddr,
    output logic [DATA_WIDTH*4-1:0] st2_rdata
);
    logic [ADDR_WIDTH-1:0]    waddr_0;
    logic [ADDR_WIDTH-1:0]    waddr_1;
    logic [ADDR_WIDTH-1:0]    raddr_0;
    logic [ADDR_WIDTH-1:0]    raddr_1;
    logic [DATA_WIDTH*4-1:0]  wdata_0;
    logic [DATA_WIDTH*4-1:0]  wdata_1;
    logic [DATA_WIDTH*4-1:0]  rdata_0;
    logic [DATA_WIDTH*4-1:0]  rdata_1;

    logic  [BANK_NUM-1:0]     wen_0;
    logic  [BANK_NUM-1:0]     wen_1;

    // sel == 0 wr 0 rd 1
    // sel == 1 wr 1 rd 0
    always_comb begin
            raddr_0 = '0;
            raddr_1 = '0;
            waddr_0 = '0;
            waddr_1 = '0;
            wdata_0 = '0;
            wdata_1 = '0;
        if (~st2_sel) begin
            wen_0   = {(BANK_NUM){st2_wen}};
            wen_1   = {(BANK_NUM){1'b0}};
            wdata_0 = st2_wdata;
            waddr_0 = st2_waddr;
            raddr_1 = st2_raddr;
        end
        else begin
            wen_0   = {(BANK_NUM){1'b0}};
            wen_1   = {(BANK_NUM){st2_wen}};
            wdata_1 = st2_wdata;
            waddr_1 = st2_waddr;
            raddr_0 = st2_raddr;
        end
    end

    ram_bank #(
        .BANK_DATA_WIDTH (DATA_WIDTH*BANK_NUM),
        .ADDR_WIDTH      (ADDR_WIDTH),
        .LATENCY         (LATENCY),
        .BANK_NUM        (BANK_NUM),
        .STAGE           (STAGE)
    ) u_st2_ram0 (
        .clk            (clk),
        .raddr          (raddr_0),
        .waddr          (waddr_0),
        .wdata          (wdata_0),
        .wdata_per_bank ('0),
        .wen            (wen_0),
        .rdata          (rdata_0)
    );

    ram_bank #(
        .BANK_DATA_WIDTH (DATA_WIDTH*BANK_NUM),
        .ADDR_WIDTH      (ADDR_WIDTH),
        .LATENCY         (LATENCY),
        .BANK_NUM        (BANK_NUM),
        .STAGE           (STAGE)
    ) u_st2_ram1 (
        .clk            (clk),
        .raddr          (raddr_1),
        .waddr          (waddr_1),
        .wdata          (wdata_1),
        .wdata_per_bank ('0),
        .wen            (wen_1),
        .rdata          (rdata_1)
    );

    logic [LATENCY-1:0] st2_sel_r;

    always_ff @(posedge clk) begin
        st2_sel_r[0] <= st2_sel;
        for (int i=0; i<LATENCY-1; i++) begin
            st2_sel_r[i+1] <= st2_sel_r[i];
        end
    end

    always_comb begin
        if (~st2_sel_r[LATENCY-1]) begin
            st2_rdata = rdata_1;
        end
        else begin
            st2_rdata = rdata_0;
        end
    end

endmodule : pp_st2

// module pp_st2_tb;
//     parameter PERIOD = 10;
//     parameter DATA_WIDTH = 68;
//     parameter ADDR_WIDTH = 11;
//     parameter LATENCY    = 1;
//     parameter BANK_NUM   = 4;
//     parameter STAGE      = 2;
//     logic clk;
//     logic rst_n;

//     logic                    st2_sel;
//     logic [DATA_WIDTH*4-1:0] st2_wdata;
//     logic                    st2_wen;
//     logic [ADDR_WIDTH-1:0]   st2_waddr;
//     logic [ADDR_WIDTH-1:0]   st2_raddr;
//     logic [DATA_WIDTH*4-1:0] st2_rdata;
//     always #(PERIOD/2) clk = ~clk;

//     initial begin
//         clk = 1'b0;
//         rst_n = 1'b0;
//         st2_sel = 1'b0;
//         st2_waddr = '0;
//         st2_raddr = '0;
//         st2_wen   = '0;
//         st2_wdata = '0;

//         repeat(10) @(posedge clk);
//         rst_n = 1'b1;
//         # 0.1
//         st2_wen = '1;
//         st2_wdata = std::randomize();
//         @(posedge clk);
//         # 0.1
//         st2_sel = 1'b1;
//         st2_wen = '0;
//         repeat(100) @(posedge clk);
//         $finish;
//     end

//     pp_st2 #(

//     ) u_pp_st2 (
//         .clk         (clk),
//         .rst_n       (rst_n),
//         .st2_sel     (st2_sel),
//         .st2_wdata   (st2_wdata),
//         .st2_wen     (st2_wen),
//         .st2_waddr   (st2_waddr),
//         .st2_raddr   (st2_raddr),
//         .st2_rdata   (st2_rdata)
//     );
//     initial begin
//         $fsdbDumpfile("pp_st2.fsdb");
//         $fsdbDumpvars("+all");
//     end
// endmodule