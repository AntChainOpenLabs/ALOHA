//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: KSK
// Module Name: ksk_mem
// Modify Date: 
//
// Description:
// KSK Memory
//////////////////////////////////////////////////
module ksk_mem #(
    parameter DATA_WIDTH = 64,
    parameter NUM_LANE = 128,
    parameter NB_PIPE = 1,
    parameter KSK_MEM_DEPTH = 9216,
    parameter AXI_DATA_WIDTH = 512,
    parameter AXI_ADDR_WIDTH = 64,

    localparam KSK_ADDR_WIDTH = $clog2(KSK_MEM_DEPTH)
) (
    input                                   clk,
    input                                   rst_n,

    // vp
    input  [KSK_ADDR_WIDTH-1:0]             i_vp_rd_addr,
    input                                   i_vp_rd_en,
    output logic [NUM_LANE*DATA_WIDTH-1:0]  o_vp_rd_data,

    // axi
    input                                   i_axi_wr_en,
    input  [AXI_ADDR_WIDTH-1:0]             i_axi_addr,
    input  [AXI_DATA_WIDTH-1:0]             i_axi_wr_data
);

    genvar j;

    localparam URAM_ADDR_WIDTH = 13;
    localparam BRAM_ADDR_WIDTH = 10;

    logic [NUM_LANE-1:0] axi_col_mask;
    logic [NUM_LANE*DATA_WIDTH-1:0] axi_wr_data;
    logic [$clog2(NUM_LANE*DATA_WIDTH/AXI_DATA_WIDTH)-1:0] axi_lo_addr;
    logic [KSK_ADDR_WIDTH-1:0] axi_hi_addr;

    assign axi_lo_addr = i_axi_addr[$clog2(NUM_LANE*DATA_WIDTH/AXI_DATA_WIDTH)-1:0];
    assign axi_hi_addr = i_axi_addr[$clog2(NUM_LANE*DATA_WIDTH/AXI_DATA_WIDTH)+:KSK_ADDR_WIDTH];

    always_comb begin
        integer i;
        for (i=0; i<NUM_LANE*DATA_WIDTH/AXI_DATA_WIDTH; i++) begin
            axi_col_mask[i*(AXI_DATA_WIDTH/DATA_WIDTH)+:(AXI_DATA_WIDTH/DATA_WIDTH)] = (axi_lo_addr == i) ? {(AXI_DATA_WIDTH/DATA_WIDTH){1'b1}} : '0;
            axi_wr_data[i*AXI_DATA_WIDTH+:AXI_DATA_WIDTH] = (axi_lo_addr == i) ? i_axi_wr_data : '0;
        end
    end

    logic in_uram, in_bram;
    logic in_uram_r [0:NB_PIPE], in_bram_r [0:NB_PIPE];
    logic en_r [0:NB_PIPE];
    logic [NUM_LANE*DATA_WIDTH-1:0]  uram_vp_rd_data, bram_vp_rd_data;

    assign in_uram_r[0] = in_uram;
    assign in_bram_r[0] = in_bram;
    assign en_r[0]      = i_vp_rd_en;

    generate
        for(j = 0;j < NB_PIPE;j++) begin
            always_ff @(posedge clk) begin
                in_uram_r[j+1] <= in_uram_r[j];
                in_bram_r[j+1] <= in_bram_r[j];
                en_r[j+1]      <= en_r[j];
            end
        end
    endgenerate

    /*always_ff @(posedge clk) begin
        for (int i=0; i<NB_PIPE; ++i) begin
            in_uram_r[i+1] <= in_uram_r[i];
            in_bram_r[i+1] <= in_bram_r[i];
            en_r[i+1]      <= en_r[i];
        end
    end*/

    assign o_vp_rd_data = en_r[NB_PIPE] & in_uram_r[NB_PIPE] ? uram_vp_rd_data :
                            en_r[NB_PIPE] & in_bram_r[NB_PIPE] ? bram_vp_rd_data : '0;

    assign in_uram = ((i_vp_rd_addr[KSK_ADDR_WIDTH-1] == 0) & i_vp_rd_en) || ((axi_hi_addr[KSK_ADDR_WIDTH-1] == 0) & i_axi_wr_en);
    assign in_bram = (i_vp_rd_en | i_axi_wr_en) & !in_uram;

    spm_bank #(
        .NUM_LANE         (NUM_LANE),
        .URAM_ADDR_WIDTH  (URAM_ADDR_WIDTH),
        .URAM_DEPTH       (1<<URAM_ADDR_WIDTH),
        .DATA_WIDTH       (DATA_WIDTH),
        .NB_PIPE          (NB_PIPE)
    ) u_spm_bank (
        .clk               (clk),
        .i_bank_addr_a     (i_vp_rd_addr),
        .i_bank_wr_data_a  ('0),
        .i_bank_en_a       (in_uram & i_vp_rd_en),
        .i_bank_wr_en_a    ('0),
        .o_bank_rd_data_a  (uram_vp_rd_data),
        .i_bank_addr_b     (axi_hi_addr),
        .i_bank_wr_data_b  (axi_wr_data),
        .i_bank_en_b       (in_uram & i_axi_wr_en),
        .i_bank_wr_en_b    (i_axi_wr_en),
        .i_bank_col_mask   (axi_col_mask),
        .o_bank_rd_data_b  ()
    );

    ksk_bram_bank #(
        .NUM_LANE    (NUM_LANE),
        .ADDR_WIDTH  (BRAM_ADDR_WIDTH),
        .DEPTH       (1<<BRAM_ADDR_WIDTH),
        .DATA_WIDTH  (DATA_WIDTH),
        .NB_PIPE     (NB_PIPE)
    ) u_ksk_bram_bank (
        .clk          (clk),
        .addr         (i_axi_wr_en ? axi_hi_addr : i_vp_rd_en ? i_vp_rd_addr : '0),
        .wen          (in_bram & i_axi_wr_en),
        .ren          (in_bram & i_vp_rd_en),
        .wmask        (axi_col_mask),
        .wdata        (axi_wr_data),
        .rdata        (bram_vp_rd_data)
    );

endmodule