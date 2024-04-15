module axil_parse #(
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32
) (
    input   logic                           clk,
    input   logic                           rst_n,
    input   logic                           clk_en,
    input   logic [AXI_ADDR_WIDTH-1:0]      awaddr,
    input   logic                           awvalid,
    output  logic                           awready,
    input   logic [AXI_DATA_WIDTH-1:0]      wdata,
    input   logic [AXI_DATA_WIDTH/8-1:0]    wstrb,
    input   logic                           wvalid,
    output  logic                           wready,
    output  logic [1:0]                     bresp,
    output  logic                           bvalid,
    input   logic                           bready,
    input   logic [AXI_ADDR_WIDTH-1:0]      araddr,
    input   logic                           arvalid,
    output  logic                           arready,
    output  logic [AXI_DATA_WIDTH-1:0]      rdata,
    output  logic [1:0]                     rresp,
    output  logic                           rvalid,
    input   logic                           rready,

    // interact with dma
    output  logic                           axi_wr_start,
    output  logic                           axi_rd_start,

    input   logic                           axi_wr_done,
    input   logic                           axi_rd_done,
    input   logic [10:0]                    poly_id_o,

    output  logic [31:0]                    axi_rd_command,
    output  logic [63:0]                    base_addr,
    output  logic [63:0]                    data_ptr,
    output  logic [31:0]                    data_size_bytes,
    output  logic [31:0]                    encode_base_addr,
    output  logic [10:0]                    poly_id_i,

    input   logic                           i_vp_done,
    output  logic [31:0]                    o_vp_pc,
    output  logic                           o_vp_start,
    output  logic [31:0]                    o_csr_vp_src0_ptr,
    output  logic [31:0]                    o_csr_vp_src1_ptr,
    output  logic [31:0]                    o_csr_vp_rslt_ptr,
    output  logic [31:0]                    o_csr_vp_rot_step
);

    localparam
        // misc
        version                 = 16'h104, // rd-only
        // DMA
        dma_wr_start            = 16'h22c, // wr-only
        dma_rd_start            = 16'h230, // wr-only
        dma_cmd                 = 16'h234,
        dma_spm_ptr             = 16'h238,
        dma_ddr_ptr_lo          = 16'h23c,
        dma_ddr_ptr_hi          = 16'h240,
        dma_data_size_bytes     = 16'h244,
        // ENCODE
        ecd_rslt_ptr            = 16'h20c,
        // VP
        vp_pc                   = 16'h210,
        vp_start                = 16'h214, // wr-only
        csr_vp_src0_ptr         = 16'h218,
        csr_vp_src1_ptr         = 16'h21c,
        csr_vp_rslt_ptr         = 16'h220,
        csr_vp_rot_step         = 16'h224,
        csr_vp_ksk_ptr          = 16'h228,
        // GLOBAL DONE   | edc_id | vp_done | wr_done | rd_done
        glb_done                = 16'h208;

    typedef enum logic [1:0] { WRIDLE, WRDATA, WRRESP, WRRESET } wr_fsm_t;
    typedef enum logic [1:0] { RDIDLE, RDDATA, RDRESET } rd_fsm_t;

    wr_fsm_t wstate;
    wr_fsm_t wnext;
    rd_fsm_t rstate;
    rd_fsm_t rnext;

    logic  [31:0]   waddr;
    logic  [31:0]   wmask;
    logic           aw_hs;
    logic           w_hs;
    logic  [31:0]   rdata_r;
    logic           ar_hs;
    logic           r_hs;
    logic  [31:0]   raddr;

    // internal register
    logic           int_wr_start;
    logic           int_rd_start;
    logic  [31:0]   int_command;
    logic  [63:0]   int_base_addr;
    logic  [31:0]   int_encode_base_addr;
    logic  [31:0]   int_data_ptr_lo;
    logic  [31:0]   int_data_ptr_hi;
    logic  [10:0]   int_poly_id_i;
    logic  [31:0]   int_data_size_bytes;
    logic  [31:0]   int_vp_pc;
    logic           int_vp_start;
    logic  [31:0]   int_csr_vp_src0_ptr;
    logic  [31:0]   int_csr_vp_src1_ptr;
    logic  [31:0]   int_csr_vp_rslt_ptr;
    logic  [31:0]   int_csr_vp_rot_step;
    // axi write
    assign awready = (wstate == WRIDLE);
    assign wready  = (wstate == WRDATA);
    assign bresp   = 2'b00; // OKAY
    assign bvalid  = (wstate == WRRESP);
    assign wmask   = {{8{wstrb[3]}}, {8{wstrb[2]}}, {8{wstrb[1]}}, {8{wstrb[0]}}};
    assign aw_hs   = awvalid & awready;
    assign w_hs    = wvalid & wready;

    // write state
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            wstate <= WRRESET;
        end
        else if (clk_en) begin
            wstate <= wnext;
        end
    end

    always_comb begin
        case (wstate)
            WRIDLE: wnext = awvalid ? WRDATA : WRIDLE;
            WRDATA: wnext = w_hs    ? WRRESP : WRDATA;
            WRRESP: wnext = bready  ? WRIDLE : WRRESP;
            default:wnext = WRIDLE;
        endcase
    end

    always_ff @(posedge clk) begin
        if (clk_en) begin
            if (aw_hs) begin
                waddr <= awaddr[31:0];
            end
        end
    end

    // read fsm
    assign arready = (rstate == RDIDLE);
    assign rdata   = rdata_r;
    assign rresp   = 2'b00; // OKAY
    assign rvalid  = (rstate == RDDATA);
    assign ar_hs   = arvalid & arready;
    assign r_hs    = rvalid & rready;
    assign raddr   = araddr[31:0];

    // read state
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            rstate <= RDRESET;
        end
        else if (clk_en) begin
            rstate <= rnext;
        end
    end

    always_comb begin
        case (rstate)
            RDIDLE: rnext = arvalid ? RDDATA : RDIDLE;
            RDDATA: rnext = r_hs    ? RDIDLE : RDDATA;
            default:rnext = RDIDLE;
        endcase
    end

    always_ff @(posedge clk) begin
        if (clk_en) begin
            if (ar_hs) begin
                case (raddr[15:0])
                    version:                rdata_r <= 32'h20230605;
                    glb_done:               rdata_r <= 32'(signed'({poly_id_o, i_vp_done, axi_wr_done, axi_rd_done}));
                    dma_cmd:                rdata_r <= int_command[31:0];
                    dma_spm_ptr:            rdata_r <= int_base_addr;
                    dma_ddr_ptr_hi:         rdata_r <= int_data_ptr_hi;
                    dma_ddr_ptr_lo:         rdata_r <= int_data_ptr_lo;
                    dma_data_size_bytes:    rdata_r <= int_data_size_bytes;
                    ecd_rslt_ptr:           rdata_r <= int_encode_base_addr;
                    vp_pc:                  rdata_r <= int_vp_pc;
                    csr_vp_src0_ptr:        rdata_r <= int_csr_vp_src0_ptr;
                    csr_vp_src1_ptr:        rdata_r <= int_csr_vp_src1_ptr;
                    csr_vp_rslt_ptr:        rdata_r <= int_csr_vp_rslt_ptr;
                    csr_vp_rot_step:        rdata_r <= int_csr_vp_rot_step;

                    default:                rdata_r <= '0;
                endcase
            end
        end
    end

    // register logic
    assign axi_wr_start         = int_wr_start;
    assign axi_rd_start         = int_rd_start;
    assign o_vp_start           = int_vp_start;
    assign axi_rd_command       = int_command;
    assign base_addr            = int_base_addr;
    assign data_ptr             = {int_data_ptr_hi, int_data_ptr_lo};
    assign data_size_bytes      = int_data_size_bytes;
    assign encode_base_addr     = int_encode_base_addr;
    assign poly_id_i            = int_poly_id_i;
    assign o_vp_pc              = int_vp_pc;

    assign o_csr_vp_src0_ptr    = int_csr_vp_src0_ptr;
    assign o_csr_vp_src1_ptr    = int_csr_vp_src1_ptr;
    assign o_csr_vp_rslt_ptr    = int_csr_vp_rslt_ptr;
    assign o_csr_vp_rot_step    = int_csr_vp_rot_step;

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            int_wr_start        <= '0;
            int_rd_start        <= '0;
            int_vp_start        <= '0;
            int_poly_id_i       <= '0;
        end
        else if (clk_en) begin
            if (w_hs && waddr[15:0] == dma_wr_start) begin
                int_wr_start <= wdata;
            end
            else begin
                int_wr_start <= '0;
            end

            if (w_hs && waddr[15:0] == dma_rd_start) begin
                {int_poly_id_i, int_rd_start} <= wdata;
            end
            else begin
                int_rd_start  <= '0;
                int_poly_id_i <= '0;
            end

            if (w_hs && waddr[15:0] == vp_start) begin
                int_vp_start  <= wdata;
            end
            else begin
                int_vp_start  <= '0;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            int_command         <= '0;
            int_base_addr       <= '0;
            int_data_ptr_hi     <= '0;
            int_data_ptr_lo     <= '0;
            int_data_size_bytes <= '0;
            int_vp_pc           <= '0;
            int_csr_vp_src0_ptr <= '0;
            int_csr_vp_src1_ptr <= '0;
            int_csr_vp_rslt_ptr <= '0;
            int_csr_vp_rot_step <= '0;
        end
        else if (clk_en) begin

            if (w_hs && waddr[15:0] == dma_cmd) begin
                int_command <= (wdata[31:0] & wmask) | (int_command[31:0] & ~wmask);
            end

            if (w_hs && waddr[15:0] == dma_spm_ptr) begin
                int_base_addr <= (wdata[31:0] & wmask) | (int_base_addr[31:0] & ~wmask);
            end

            if (w_hs && waddr[15:0] == dma_ddr_ptr_lo) begin
                int_data_ptr_lo <= (wdata[31:0] & wmask) | (int_data_ptr_lo[31:0] & ~wmask);
            end

            if (w_hs && waddr[15:0] == dma_ddr_ptr_hi) begin
                int_data_ptr_hi <= (wdata[31:0] & wmask) | (int_data_ptr_hi[31:0] & ~wmask);
            end

            if (w_hs && waddr[15:0] == dma_data_size_bytes) begin
                int_data_size_bytes <= (wdata[31:0] & wmask) | (int_data_size_bytes[31:0] & ~wmask);
            end

            if (w_hs && waddr[15:0] == ecd_rslt_ptr) begin
                int_encode_base_addr <= (wdata[31:0] & wmask) | (int_encode_base_addr[31:0] & ~wmask);
            end

            if (w_hs && waddr[15:0] == vp_pc) begin
                int_vp_pc <= (wdata[31:0] & wmask) | (int_vp_pc[31:0] & ~wmask);
            end

            if (w_hs && waddr[15:0] == csr_vp_src0_ptr) begin
                int_csr_vp_src0_ptr <= (wdata[31:0] & wmask) | (int_csr_vp_src0_ptr[31:0] & ~wmask);
            end

            if (w_hs && waddr[15:0] == csr_vp_src1_ptr) begin
                int_csr_vp_src1_ptr <= (wdata[31:0] & wmask) | (int_csr_vp_src1_ptr[31:0] & ~wmask);
            end

            if (w_hs && waddr[15:0] == csr_vp_rslt_ptr) begin
                int_csr_vp_rslt_ptr <= (wdata[31:0] & wmask) | (int_csr_vp_rslt_ptr[31:0] & ~wmask);
            end

            if (w_hs && waddr[15:0] == csr_vp_rot_step) begin
                int_csr_vp_rot_step <= (wdata[31:0] & wmask) | (int_csr_vp_rot_step[31:0] & ~wmask);
            end

        end
    end

endmodule