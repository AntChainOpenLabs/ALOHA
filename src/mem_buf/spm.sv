//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: SPM
// Module Name: spm
// Modify Date: 
//
// Description:
// ScratchPad Memory
//////////////////////////////////////////////////
module spm #(
    parameter URAM_ADDR_WIDTH = 12,
    parameter BANK_NUM = 4,
    parameter NUM_LANE = 128,
    parameter DATA_WIDTH = 64,
    parameter NB_PIPE = 3,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 512,

    localparam SPM_ADDR_WIDTH = $clog2(BANK_NUM) + URAM_ADDR_WIDTH
) (
    input                                   clk,
    input                                   rst_n,

    // from vp
    input  [SPM_ADDR_WIDTH-1:0]             i_vp_rd_addr,
    input                                   i_vp_wr_en,
    input  [SPM_ADDR_WIDTH-1:0]             i_vp_wr_addr,
    input  [NUM_LANE*DATA_WIDTH-1:0]        i_vp_wr_data,

    // to vp
    output logic [NUM_LANE*DATA_WIDTH-1:0]  o_vp_rd_data,

    input                                   i_axi_wr_en,
    input                                   i_axi_en,
    input  [AXI_ADDR_WIDTH-1:0]             i_axi_addr,
    input  [AXI_DATA_WIDTH-1:0]             i_axi_wr_data,
    output logic [AXI_DATA_WIDTH-1:0]       o_axi_rd_data,

    // from encoder
    input                                   i_encode_wr_en,
    input  [SPM_ADDR_WIDTH-1:0]             i_encode_wr_addr,
    input  [NUM_LANE*DATA_WIDTH-1:0]        i_encode_wr_data
);

    logic [SPM_ADDR_WIDTH-1:0] bank_addr_a;
    logic [NUM_LANE*DATA_WIDTH-1:0] bank_wr_data_a;
    logic [NUM_LANE*DATA_WIDTH-1:0] bank_rd_data_a [0:BANK_NUM-1];
    logic bank_wr_en_a;

    // port A input
    always_comb begin
        bank_addr_a = i_vp_wr_en ? i_vp_wr_addr : i_vp_rd_addr;
        bank_wr_data_a = i_vp_wr_data;
        bank_wr_en_a = i_vp_wr_en;
    end

    logic [BANK_NUM-1:0] bank_en_a;
    logic [$clog2(BANK_NUM)-1:0] bank_id_a;
    always_comb begin
        bank_id_a = bank_addr_a[URAM_ADDR_WIDTH+:$clog2(BANK_NUM)];
        for (int i=0; i<BANK_NUM; i++) begin
            bank_en_a[i] = (bank_id_a == i);
        end
    end

    // port A output
    logic [$clog2(BANK_NUM)-1:0] bank_id_a_r [0:NB_PIPE];
    assign bank_id_a_r[0] = bank_id_a;
    always_ff @(posedge clk) begin
        for (int i=0; i<NB_PIPE; i++) begin
            bank_id_a_r[i+1] <= bank_id_a_r[i];
        end
    end

    assign o_vp_rd_data = bank_rd_data_a[bank_id_a_r[NB_PIPE]];

    // port B input
    logic [SPM_ADDR_WIDTH-1:0] bank_addr_b [0:BANK_NUM-1];
    logic [NUM_LANE*DATA_WIDTH-1:0] bank_wr_data_b [0:BANK_NUM-1];
    logic [BANK_NUM-1:0] bank_wr_en_b;
    logic [BANK_NUM-1:0] bank_en_b;
    logic [NUM_LANE*DATA_WIDTH-1:0] bank_rd_data_b [0:BANK_NUM-1];

    logic [BANK_NUM-1:0] bank_encode_wr_en;
    logic [BANK_NUM-1:0] bank_axi_wr_en;
    logic [BANK_NUM-1:0] bank_axi_rd_en;
    logic [NUM_LANE-1:0] bank_col_mask [0:BANK_NUM-1];
    logic [NUM_LANE*DATA_WIDTH/AXI_DATA_WIDTH-1:0] col_mask[0:BANK_NUM-1];

    logic [$clog2(NUM_LANE*DATA_WIDTH/AXI_DATA_WIDTH)-1:0] axi_lo_addr;
    logic [SPM_ADDR_WIDTH-1:0] axi_hi_addr;
    assign axi_lo_addr = i_axi_addr; //>> ($clog2(AXI_DATA_WIDTH/8)));
    assign axi_hi_addr = i_axi_addr[$clog2(NUM_LANE*DATA_WIDTH/AXI_DATA_WIDTH)+:SPM_ADDR_WIDTH];//[$clog2(NUM_LANE)+$clog2(DATA_WIDTH/8)+:SPM_ADDR_WIDTH];

    always_comb begin
        integer i, j;
        for (i=0; i<BANK_NUM; i++) begin
            bank_encode_wr_en[i] = i_encode_wr_en & (i_encode_wr_addr[URAM_ADDR_WIDTH+:$clog2(BANK_NUM)] == i);
            bank_axi_wr_en[i] = i_axi_en & i_axi_wr_en & (axi_hi_addr[URAM_ADDR_WIDTH+:$clog2(BANK_NUM)] == i);
            bank_axi_rd_en[i] = i_axi_en & ~i_axi_wr_en & (axi_hi_addr[URAM_ADDR_WIDTH+:$clog2(BANK_NUM)] == i);

            bank_wr_data_b[i] = '0;
            bank_col_mask[i] = '0;
            bank_en_b[i] = 1'b0;
            bank_wr_en_b[i] = 1'b0;
            col_mask[i] = 1'b0;
            bank_addr_b[i] = '0;

            if (bank_encode_wr_en[i]) begin
                bank_addr_b[i] = i_encode_wr_addr;
                bank_wr_data_b[i] = i_encode_wr_data;
                bank_en_b[i] = 1'b1;
                bank_wr_en_b[i] = 1'b1;
                bank_col_mask[i] = {NUM_LANE{1'b1}};
            end
            if (bank_axi_wr_en[i]) begin
                bank_addr_b[i] = axi_hi_addr;
                bank_en_b[i] = 1'b1;
                bank_wr_en_b[i] = 1'b1;

                for (j=0; j<NUM_LANE*DATA_WIDTH/AXI_DATA_WIDTH; j++) begin
                    bank_wr_data_b[i][j*AXI_DATA_WIDTH+:AXI_DATA_WIDTH] = (axi_lo_addr == j) ? i_axi_wr_data : '0;
                    bank_col_mask[i][j*(AXI_DATA_WIDTH/DATA_WIDTH)+:(AXI_DATA_WIDTH/DATA_WIDTH)] = (axi_lo_addr == j) ? {(AXI_DATA_WIDTH/DATA_WIDTH){1'b1}} : '0;
                end
            end
            if (bank_axi_rd_en[i]) begin
                bank_addr_b[i] = axi_hi_addr;
                bank_en_b[i] = 1'b1;
                bank_wr_en_b[i] = 1'b0;
                for (j=0; j<NUM_LANE*DATA_WIDTH/AXI_DATA_WIDTH; j++) begin
                    bank_col_mask[i][j*(AXI_DATA_WIDTH/DATA_WIDTH)+:(AXI_DATA_WIDTH/DATA_WIDTH)] = (axi_lo_addr == j) ? {(AXI_DATA_WIDTH/DATA_WIDTH){1'b1}} : '0;
                    col_mask[i][j] = (axi_lo_addr == j) ? 1'b1 : 1'b0;
                end
            end
        end
    end

    // port B output
    logic [$clog2(BANK_NUM)-1:0] bank_id_b_r [0:NB_PIPE-1];
    logic [$clog2(NUM_LANE*DATA_WIDTH/AXI_DATA_WIDTH)-1:0] col_mask_r [0:NB_PIPE-1];
    logic [$clog2(BANK_NUM)-1:0] bank_id_b_n;
    logic [$clog2(NUM_LANE*DATA_WIDTH/AXI_DATA_WIDTH)-1:0] col_mask_n;

    oh2idx #(
        .IDX_WIDTH($clog2(BANK_NUM))
    ) u_oh2idx_1 (
        .index  (bank_id_b_n),
        .one_hot(bank_axi_rd_en)
    );

    oh2idx #(
        .IDX_WIDTH($clog2(NUM_LANE*DATA_WIDTH/AXI_DATA_WIDTH))
    ) u_oh2idx_2 (
        .index  (col_mask_n),
        .one_hot(col_mask[bank_id_b_n])
    );



    always_ff @(posedge clk) begin
        if (|bank_axi_rd_en) begin
            bank_id_b_r[0] <= bank_id_b_n;
            col_mask_r[0] <= col_mask_n;
        end
        for (int i=0; i<NB_PIPE-1; i++) begin
            col_mask_r[i+1] <= col_mask_r[i];
            bank_id_b_r[i+1] <= bank_id_b_r[i];
        end
    end

    logic [NUM_LANE*DATA_WIDTH-1:0] axi_rd_data;
    always_comb begin
        axi_rd_data = bank_rd_data_b[bank_id_b_r[NB_PIPE-1]];
    end

    assign o_axi_rd_data = axi_rd_data[col_mask_r[NB_PIPE-1]*AXI_DATA_WIDTH+:AXI_DATA_WIDTH];


    generate
        genvar i;
        for (i=0; i<BANK_NUM; i++) begin
            spm_bank #(
                .NUM_LANE        (NUM_LANE),
                .URAM_ADDR_WIDTH (URAM_ADDR_WIDTH),
                .URAM_DEPTH      (1<<URAM_ADDR_WIDTH),
                .DATA_WIDTH      (DATA_WIDTH),
                .NB_PIPE         (NB_PIPE)
            ) u_spm_bank (
                .clk                (clk),
                .i_bank_addr_a      (bank_addr_a[URAM_ADDR_WIDTH-1:0]),
                .i_bank_wr_data_a   (bank_wr_data_a),
                .i_bank_en_a        (bank_en_a[i]),
                .i_bank_wr_en_a     (bank_wr_en_a),
                .o_bank_rd_data_a   (bank_rd_data_a[i]),
                .i_bank_addr_b      (bank_addr_b[i][URAM_ADDR_WIDTH-1:0]),
                .i_bank_wr_data_b   (bank_wr_data_b[i]),
                .i_bank_en_b        (bank_en_b[i]),
                .i_bank_wr_en_b     (bank_wr_en_b[i]),
                .i_bank_col_mask    (bank_col_mask[i]),
                .o_bank_rd_data_b   (bank_rd_data_b[i])
            );
        end
    endgenerate


endmodule


