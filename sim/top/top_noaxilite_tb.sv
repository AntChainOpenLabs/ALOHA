`timescale 1ns/1ns

package op_type_t;
    typedef enum logic[3:0]
    {
        load_cipher = 1,
        store_cipher = 2,
        encode = 3,//actually is the combination of encode and encode_post
        encode_post = 4,//not supported for now
        mul_plain = 5,
        hom_add = 6,
        rotate = 7
    }_type;
endpackage

typedef struct
{
    op_type_t::_type op_type;
    logic[31:0] spm_addr;
    logic[63:0] dram_addr;
    logic[31:0] spm_addr_src1;
    logic[31:0] spm_addr_src2;
    logic[31:0] step;
}op_info_t;

typedef struct
{
    string filename;
    longint unsigned offset;
}file_offset_pair_t;

typedef file_offset_pair_t file_offset_pair_array_t[$];

typedef string string_array_t[$];

module top_noaxilite_tb;
    localparam DDR_ADDR_WIDTH = 26;//Byte Address
    localparam DDR_DATA_WIDTH = 512;
    localparam DDR_MEM_DEPTH = (2 ** DDR_ADDR_WIDTH) >> $clog2(DDR_DATA_WIDTH / 8);
    localparam DATA_WIDTH = 64;
    localparam DOUBLE_DATA_WIDTH = 64;
    localparam POLY_ELEMENT_NUM = 8192;
    localparam DMA_LOAD_POLY_NUM = 'd4;
    localparam DRAM_ENCODER_BASE = 64'd0;
    localparam DRAM_VP_BASE = 64'd10485760;

    localparam REG_VP_PC = 'h210;
    localparam REG_VP_START = 'h214;
    localparam REG_VP_SRC1_PTR = 'h21c;
    localparam REG_VP_SRC2_PTR = 'h220;
    localparam REG_VP_DEST_PTR = 'h224;
    localparam REG_VP_ROT_STEP = 'h228;
    localparam REG_DMA_WR_START = 'h22c;
    localparam REG_DMA_RD_START = 'h230;
    localparam REG_DMA_CMD = 'h234;
    localparam REG_DMA_SPM_PTR = 'h238;
    localparam REG_DMA_DDR_PTR_LO = 'h23c;
    localparam REG_DMA_DDR_PTR_HI = 'h240;
    localparam REG_DMA_DATA_SIZE_BYTES = 'h244;
    localparam REG_GLB_DONE = 'h208;
    localparam REG_ECD_RSLT_PTR = 'h20c;

    localparam ISRAM_ENCODE_POST = 'd0;
    localparam ISRAM_MUL_PLAIN = 'd64;
    localparam ISRAM_HOM_ADD = 'd160;
    localparam ISRAM_KEYSWITCH = 'd256;

    localparam DMA_CMD_KSK = 'd0;
    localparam DMA_CMD_MEM = 'd1;
    localparam DMA_CMD_ENCODE = 'd2;

    parameter AXI_ADDR_WIDTH = 64;
    parameter AXI_DATA_WIDTH = 512;

    parameter LANE_NUM = 128;

    localparam DUMP_DRAM_ADDR = 64'h100000;

    logic clk;
    logic rst_n;

    logic                          axi_awvalid;
    logic                          axi_awready;
    logic [AXI_ADDR_WIDTH-1:0]     axi_awaddr;
    logic [7:0]                    axi_awlen;
    logic                          axi_wvalid;
    logic                          axi_wready;
    logic [AXI_DATA_WIDTH-1:0]     axi_wdata;
    logic [AXI_DATA_WIDTH/8-1:0]   axi_wstrb;
    logic                          axi_wlast;
    logic                          axi_bvalid;
    logic                          axi_bready;
    logic                          axi_arvalid;
    logic                          axi_arready;
    logic [AXI_ADDR_WIDTH-1:0]     axi_araddr;
    logic [7:0]                    axi_arlen;
    logic                          axi_rvalid;
    logic                          axi_rready;
    logic [AXI_DATA_WIDTH-1:0]     axi_rdata;
    logic                          axi_rlast;

    // from arm
    logic axi_wr_start;
    logic axi_rd_start;
    logic axi_wr_done;
    logic axi_rd_done;
    logic[10:0] poly_id_o;
    logic[31:0] axi_rd_command;
    logic[63:0] base_addr;
    logic[63:0] data_ptr;
    logic[31:0] data_size_bytes;
    logic[31:0] encode_base_addr;
    logic[10:0] poly_id_i;
    logic i_vp_done;
    logic[31:0] o_vp_pc;
    logic o_vp_start;
    logic[31:0] o_csr_vp_src0_ptr;
    logic[31:0] o_csr_vp_src1_ptr;
    logic[31:0] o_csr_vp_rslt_ptr;
    logic[31:0] o_csr_vp_rot_step;
    logic[31:0] o_csr_vp_ksk_ptr;

    h2_top_no_axilite h2_top_no_axilite_inst(
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
        .axi_wr_start(axi_wr_start),
        .axi_rd_start(axi_rd_start),
        .axi_wr_done(axi_wr_done),
        .axi_rd_done(axi_rd_done),
        .poly_id_o(poly_id_o),
        .axi_rd_command(axi_rd_command),
        .base_addr(base_addr),
        .data_ptr(data_ptr),
        .data_size_bytes(data_size_bytes),
        .encode_base_addr(encode_base_addr),
        .poly_id_i(poly_id_i),
        .i_vp_done(i_vp_done),
        .o_vp_pc(o_vp_pc),
        .o_vp_start(o_vp_start),
        .o_csr_vp_src0_ptr(o_csr_vp_src0_ptr),
        .o_csr_vp_src1_ptr(o_csr_vp_src1_ptr),
        .o_csr_vp_rslt_ptr(o_csr_vp_rslt_ptr),
        .o_csr_vp_rot_step(o_csr_vp_rot_step),
        .o_csr_vp_ksk_ptr(o_csr_vp_ksk_ptr)
    );

    tb_axi_bram i_ddr(
        .s_axi_aclk(clk),
        .s_axi_aresetn(rst_n),
        .s_axi_awid('d0),
        .s_axi_awaddr(axi_awaddr),
        .s_axi_awlen(axi_awlen),
        .s_axi_awsize('d6),
        .s_axi_awburst('d1),
        .s_axi_awlock('d0),
        .s_axi_awcache('d3),
        .s_axi_awprot('d0),
        .s_axi_awvalid(axi_awvalid),
        .s_axi_awready(axi_awready),
        .s_axi_wdata(axi_wdata),
        .s_axi_wstrb(axi_wstrb),
        .s_axi_wlast(axi_wlast),
        .s_axi_wvalid(axi_wvalid),
        .s_axi_wready(axi_wready),
        .s_axi_bid(),
        .s_axi_bresp(),
        .s_axi_bvalid(axi_bvalid),
        .s_axi_bready(axi_bready),
        .s_axi_arid('d0),
        .s_axi_araddr(axi_araddr),
        .s_axi_arlen(axi_arlen),
        .s_axi_arsize('d6),
        .s_axi_arburst('d1),
        .s_axi_arlock('d0),
        .s_axi_arcache('d3),
        .s_axi_arprot('d0),
        .s_axi_arvalid(axi_arvalid),
        .s_axi_arready(axi_arready),
        .s_axi_rid(),
        .s_axi_rdata(axi_rdata),
        .s_axi_rresp(),
        .s_axi_rlast(axi_rlast),
        .s_axi_rvalid(axi_rvalid),
        .s_axi_rready(axi_rready)
    );

    task wait_clk;
        @(posedge clk);
        #0.1;
    endtask

    task eval;
        #0.1;
    endtask

    task reset_assert;
        rst_n = 0;
        wait_clk();
    endtask

    task reset_deassert;
        rst_n = 1;
        wait_clk();
    endtask

    task reset;
        rst_n = 0;
        repeat(20) wait_clk();
        rst_n = 1;
        repeat(20) wait_clk();
    endtask

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    function void print_op(op_info_t op);
        case(op.op_type)
            op_type_t::load_cipher: $display("Load_Cipher(%0d, %0d)", op.spm_addr, op.dram_addr);
            op_type_t::store_cipher: $display("Store_Cipher(%0d, %0d)", op.dram_addr, op.spm_addr);
            op_type_t::encode: $display("Encode(%0d, %0d)", op.spm_addr, op.dram_addr);
            op_type_t::encode_post: $display("Encode_Post(%0d, %0d)", op.spm_addr, op.spm_addr_src1);
            op_type_t::mul_plain: $display("Mul_Plain(%0d, %0d, %0d)", op.spm_addr, op.spm_addr_src1, op.spm_addr_src2);
            op_type_t::hom_add: $display("Hom_Add(%0d, %0d, %0d)", op.spm_addr, op.spm_addr_src1, op.spm_addr_src2);
            op_type_t::rotate: $display("Rotate(%0d, %0d, %0d)", op.spm_addr, op.spm_addr_src1, op.step);
        endcase
    endfunction

    function op_info_t parse_op(logic[31:0] args[0:2]);
        logic[3:0] op;
        logic[31:0] spm_addr;
        op_info_t r;
        
        op = args[0][28 +: 4];
        spm_addr = args[0][13:0];

        case(op)
            1, 2: begin //load_cipher and store_cipher
                $cast(r.op_type, op);
                r.spm_addr = spm_addr;
                r.dram_addr = {args[1], args[2]};

                //TODO: error handle
            end

            3: begin //encode
                $cast(r.op_type, op);
                r.spm_addr = spm_addr;
                r.dram_addr = {args[1], args[2]};

                //TODO: error handle
            end

            4, 5, 6: begin //encode_post, mul_plain and hom_add
                $cast(r.op_type, op);
                r.spm_addr = spm_addr;
                r.spm_addr_src1 = args[1][13:0];
                r.spm_addr_src2 = args[2][13:0];

                //TODO: error handle
            end

            7: begin //rotate
                $cast(r.op_type, op);
                r.spm_addr = spm_addr;
                r.step = args[1][13:0];
                r.spm_addr_src1 = args[2][13:0];

                //TODO: error handle
            end

            default: begin //unknown op
                //TODO: error handle
            end
        endcase

        return r;
    endfunction

    function automatic string_array_t string_split(string str, string sep = ",");
        string_array_t r;
        longint unsigned offset = 0;
        int i;

        for(i = 0;i < str.len();i++) begin
            if(str.getc(i) == sep.getc(0)) begin
                if(i > offset) begin
                    r.push_back(str.substr(offset, i - 1));
                    offset = i + 1;
                end
            end
        end

        if(offset < str.len()) begin
            r.push_back(str.substr(offset, str.len() - 1));
        end

        return r;
    endfunction

    function automatic file_offset_pair_array_t parse_file_offset_arg(string arg);
        file_offset_pair_array_t r;
        string_array_t lines;
        string_array_t str_args;
        file_offset_pair_t item;

        lines = string_split(arg, "#");

        foreach(lines[i]) begin
            str_args = string_split(lines[i], ",");
            item.filename = str_args[0];
            $sscanf(str_args[1], "%d", item.offset);
            r.push_back(item);
        end

        return r;
    endfunction

    logic[DDR_DATA_WIDTH - 1:0] ddr_init_mem[0:DDR_MEM_DEPTH - 1];

    task automatic load_dram_data();
        $readmemh(`DRAM_INPUT_FILE, ddr_init_mem);
        force i_ddr.i_ddr_mem_bank_512b.base_bank.mem_bank = ddr_init_mem;
        wait_clk();
        release i_ddr.i_ddr_mem_bank_512b.base_bank.mem_bank;
    endtask

    op_info_t op_list[$];

    task automatic parse_op_list();
        logic[31:0] args[0:2];
        int f;

        f = $fopen(`PROGRAM, "r");

        if(!f) begin
            $error("Program file open failed!");
            $finish;
        end

        while($fscanf(f, "%h,%h,%h", args[0], args[1], args[2]) == 3) begin
            op_list.push_back(parse_op(args));
        end

        $fclose(f);

        foreach(op_list[i]) begin
            print_op(op_list[i]);
        end
    endtask

    task automatic load_ksk(input logic[63:0] dram_addr);
        logic[31:0] rdata;
        logic[63:0] dram_addr_t;

        dram_addr_t = dram_addr;

        axi_rd_command = DMA_CMD_KSK;
        base_addr = 0;
        data_ptr = dram_addr_t;
        data_size_bytes = 3 * 12 * POLY_ELEMENT_NUM * DATA_WIDTH / 8;
        axi_rd_start = 1;
        wait_clk();
        axi_rd_start = 0;
        wait_clk();

        while(1) begin
            if(axi_rd_done === 'b1) begin
                break;
            end

            wait_clk();
        end
    endtask

    task automatic run_vp(input logic[31:0] spm_addr_dest, input logic[31:0] spm_addr_src1, input logic[31:0] spm_addr_src2, input logic[31:0] step, input logic[31:0] ksk_ptr, input logic[31:0] pc);
        logic[31:0] rdata;

        o_vp_pc = pc;
        o_csr_vp_src0_ptr = spm_addr_src1;
        o_csr_vp_src1_ptr = spm_addr_src2;
        o_csr_vp_rslt_ptr = spm_addr_dest;
        o_csr_vp_rot_step = step;
        o_csr_vp_ksk_ptr = ksk_ptr;
        o_vp_start = 1;
        wait_clk();
        o_vp_start = 0;
        wait_clk();

        while(1) begin
            if(i_vp_done === 'b1) begin
                break;
            end

            wait_clk();
        end
    endtask

    task automatic run_encode(input longint inst_id, input logic[31:0] spm_addr_dest, input logic[63:0] dram_addr);
        logic[31:0] rdata;
        logic[63:0] dram_addr_t;

        dram_addr_t = DRAM_ENCODER_BASE + dram_addr;

        axi_rd_command = DMA_CMD_ENCODE;
        base_addr = spm_addr_dest;
        encode_base_addr = spm_addr_dest;
        data_ptr = dram_addr_t;
        data_size_bytes = POLY_ELEMENT_NUM * DOUBLE_DATA_WIDTH / 8;
        poly_id_i = poly_id_o + 1;
        axi_rd_start = 1;
        wait_clk();
        axi_rd_start = 0;
        wait_clk();

        while(1) begin
            if(poly_id_o == poly_id_i) begin
                break;
            end

            wait_clk();
        end

        copy_spm_to_dram(DUMP_DRAM_ADDR, spm_addr_dest);
        dump_sub_poly(inst_id, 0, DUMP_DRAM_ADDR);

        run_vp(spm_addr_dest, spm_addr_dest, 0, 0, 0, ISRAM_ENCODE_POST);
    endtask

    task automatic run_load_cipher(input logic[31:0] spm_addr_dest, input logic[63:0] dram_addr);
        logic[31:0] rdata;
        logic[63:0] dram_addr_t;

        dram_addr_t = DRAM_VP_BASE + dram_addr;

        axi_rd_command = DMA_CMD_MEM;
        base_addr = spm_addr_dest << $clog2(LANE_NUM * DATA_WIDTH / AXI_DATA_WIDTH);
        data_ptr = dram_addr_t;
        data_size_bytes = DMA_LOAD_POLY_NUM * POLY_ELEMENT_NUM * DATA_WIDTH / 8;
        axi_rd_start = 1;
        wait_clk();
        axi_rd_start = 0;
        wait_clk();

        while(1) begin
            if(axi_rd_done === 'b1) begin
                break;
            end

            wait_clk();
        end
    endtask

    task automatic run_store_cipher(input logic[63:0] dram_addr, input logic[31:0] spm_addr_src);
        logic[31:0] rdata;
        logic[63:0] dram_addr_t;

        dram_addr_t = DRAM_VP_BASE + dram_addr;

        axi_rd_command = DMA_CMD_MEM;
        base_addr = spm_addr_src << $clog2(LANE_NUM * DATA_WIDTH / AXI_DATA_WIDTH);
        data_ptr = dram_addr_t;
        data_size_bytes = DMA_LOAD_POLY_NUM * POLY_ELEMENT_NUM * DATA_WIDTH / 8;
        axi_wr_start = 1;
        wait_clk();
        axi_wr_start = 0;
        wait_clk();

        while(1) begin
            if(axi_wr_done === 'b1) begin
                break;
            end

            wait_clk();
        end
    endtask

    task automatic copy_spm_to_dram(input logic[63:0] dram_addr, input logic[31:0] spm_addr_src);
        logic[31:0] rdata;
        logic[63:0] dram_addr_t;

        dram_addr_t = dram_addr;

        axi_rd_command = DMA_CMD_MEM;
        base_addr = spm_addr_src << $clog2(LANE_NUM * DATA_WIDTH / AXI_DATA_WIDTH);
        data_ptr = dram_addr_t;
        data_size_bytes = DMA_LOAD_POLY_NUM * POLY_ELEMENT_NUM * DATA_WIDTH / 8;
        axi_wr_start = 1;
        wait_clk();
        axi_wr_start = 0;
        wait_clk();

        while(1) begin
            if(axi_wr_done === 'b1) begin
                break;
            end

            wait_clk();
        end
    endtask

    task run_mul_plain(input logic[31:0] spm_addr_dest, input logic[31:0] spm_addr_src1, input logic[31:0] spm_addr_src2);
        run_vp(spm_addr_dest, spm_addr_src1, spm_addr_src2, 0, 0, ISRAM_MUL_PLAIN);
    endtask

    task run_hom_add(input logic[31:0] spm_addr_dest, input logic[31:0] spm_addr_src1, input logic[31:0] spm_addr_src2);
        run_vp(spm_addr_dest, spm_addr_src1, spm_addr_src2, 0, 0, ISRAM_HOM_ADD);
    endtask

    task run_rotate(input logic[31:0] spm_addr_dest, input logic[31:0] spm_addr_src, input logic[31:0] step);
        run_vp(spm_addr_dest, spm_addr_src, 0, (3 ** step) % (POLY_ELEMENT_NUM * 2), ($clog2(step) - 1) * POLY_ELEMENT_NUM * 12 / LANE_NUM, ISRAM_KEYSWITCH);
    endtask

    logic[63:0] last_dram_addr;

    task automatic dump_poly(input longint unsigned inst_id, input logic[63:0] dram_addr);
        int f;
        longint unsigned i;
        logic[DATA_WIDTH - 1:0] x;
        logic[$clog2(DDR_MEM_DEPTH) + $clog2(DDR_DATA_WIDTH / DATA_WIDTH) - 1:0] cur_addr;
        logic[$clog2(DDR_MEM_DEPTH) - 1:0] addr_offset;
        logic[$clog2(DDR_DATA_WIDTH) - 1:0] bit_offset;

        $display("Dumping...");
        $display($sformatf("inst_%0d_out.txt", inst_id));

        f = $fopen($sformatf("inst_%0d_out.txt", inst_id), "w");

        if(!f) begin
            $error("File create failed!");
            $finish;
        end

        last_dram_addr = dram_addr;

        for(i = 0;i < DMA_LOAD_POLY_NUM * POLY_ELEMENT_NUM;i++) begin
            cur_addr = (dram_addr >> ($clog2(DATA_WIDTH / 8))) + i;
            addr_offset = cur_addr[$clog2(DDR_DATA_WIDTH / DATA_WIDTH) +: $clog2(DDR_MEM_DEPTH)];
            bit_offset = cur_addr[$clog2(DDR_DATA_WIDTH / DATA_WIDTH) - 1:0] * DATA_WIDTH;
            x = i_ddr.i_ddr_mem_bank_512b.base_bank.mem_bank[addr_offset] >> bit_offset;
            $fdisplay(f, "%0d", x);
        end

        $fclose(f);
    endtask

    task automatic dump_sub_poly(input longint unsigned inst_id, input longint unsigned sub_id, input logic[63:0] dram_addr);
        int f;
        longint unsigned i;
        logic[DATA_WIDTH - 1:0] x;
        logic[$clog2(DDR_MEM_DEPTH) + $clog2(DDR_DATA_WIDTH / DATA_WIDTH) - 1:0] cur_addr;
        logic[$clog2(DDR_MEM_DEPTH) - 1:0] addr_offset;
        logic[$clog2(DDR_DATA_WIDTH) - 1:0] bit_offset;

        $display("Dumping...");
        $display($sformatf("inst_%0d_%0d_out.txt", inst_id, sub_id));

        f = $fopen($sformatf("inst_%0d_%0d_out.txt", inst_id, sub_id), "w");

        if(!f) begin
            $error("File create failed!");
            $finish;
        end

        for(i = 0;i < DMA_LOAD_POLY_NUM * POLY_ELEMENT_NUM;i++) begin
            cur_addr = (dram_addr >> ($clog2(DATA_WIDTH / 8))) + i;
            addr_offset = cur_addr[$clog2(DDR_DATA_WIDTH / DATA_WIDTH) +: $clog2(DDR_MEM_DEPTH)];
            bit_offset = cur_addr[$clog2(DDR_DATA_WIDTH / DATA_WIDTH) - 1:0] * DATA_WIDTH;
            x = i_ddr.i_ddr_mem_bank_512b.base_bank.mem_bank[addr_offset] >> bit_offset;
            $fdisplay(f, "%0d", x);
        end

        $fclose(f);
    endtask

    task run;
        foreach(op_list[i]) begin
            $write("Execute: ");
            print_op(op_list[i]);

            case(op_list[i].op_type)
                op_type_t::load_cipher: begin
                    run_load_cipher(op_list[i].spm_addr, op_list[i].dram_addr);
                    copy_spm_to_dram(DUMP_DRAM_ADDR, op_list[i].spm_addr);
                    dump_poly(i, DUMP_DRAM_ADDR);
                end

                op_type_t::store_cipher: begin
                    run_store_cipher(op_list[i].dram_addr, op_list[i].spm_addr);
                    dump_poly(i, DRAM_VP_BASE + op_list[i].dram_addr);
                end

                op_type_t::encode: begin
                    run_encode(i, op_list[i].spm_addr, op_list[i].dram_addr);
                    copy_spm_to_dram(DUMP_DRAM_ADDR, op_list[i].spm_addr);
                    dump_poly(i, DUMP_DRAM_ADDR);
                end

                op_type_t::mul_plain: begin
                    run_mul_plain(op_list[i].spm_addr, op_list[i].spm_addr_src1, op_list[i].spm_addr_src2);
                    copy_spm_to_dram(DUMP_DRAM_ADDR, op_list[i].spm_addr);
                    dump_poly(i, DUMP_DRAM_ADDR);
                end

                op_type_t::hom_add: begin
                    run_hom_add(op_list[i].spm_addr, op_list[i].spm_addr_src1, op_list[i].spm_addr_src2);
                    copy_spm_to_dram(DUMP_DRAM_ADDR, op_list[i].spm_addr);
                    dump_poly(i, DUMP_DRAM_ADDR);
                end

                op_type_t::rotate: begin
                    run_rotate(op_list[i].spm_addr, op_list[i].spm_addr_src1, op_list[i].step);
                    copy_spm_to_dram(DUMP_DRAM_ADDR, op_list[i].spm_addr);
                    dump_poly(i, DUMP_DRAM_ADDR);
                end
            endcase
        end
    endtask

    longint unsigned expected_result[0:32767];
    
    task automatic load_expected_result();
        int i;
        int f;

        f = $fopen("case3_expected_result.txt", "r");

        if(!f) begin
            $error("Program file open failed!");
            $finish;
        end

        for(i = 0;i < 32768;i++) begin
            if($fscanf(f, "%d", expected_result[i]) != 1) begin
                $error("Expected result file error!");
                $finish;
            end
        end

        $fclose(f);
    endtask

    task automatic check_result(input logic[63:0] dram_addr);
        longint unsigned i;
        logic[DATA_WIDTH - 1:0] x;
        logic[$clog2(DDR_MEM_DEPTH) + $clog2(DDR_DATA_WIDTH / DATA_WIDTH) - 1:0] cur_addr;
        logic[$clog2(DDR_MEM_DEPTH) - 1:0] addr_offset;
        logic[$clog2(DDR_DATA_WIDTH) - 1:0] bit_offset;

        for(i = 0;i < 32768;i++) begin
            cur_addr = (dram_addr >> ($clog2(DATA_WIDTH / 8))) + i;
            addr_offset = cur_addr[$clog2(DDR_DATA_WIDTH / DATA_WIDTH) +: $clog2(DDR_MEM_DEPTH)];
            bit_offset = cur_addr[$clog2(DDR_DATA_WIDTH / DATA_WIDTH) - 1:0] * DATA_WIDTH;
            x = i_ddr.i_ddr_mem_bank_512b.base_bank.mem_bank[addr_offset] >> bit_offset;
            
            if(x != expected_result[i]) begin
                $display("ERROR: result is incorrect at %0d, expected %0d, actual %0d", i, expected_result[i], x);
                $finish;
            end
        end

        $display("TEST PASSED!");
    endtask

    task init();
        //enter reset state
        reset_assert();

        axi_wr_start = 0;
        axi_rd_start = 0;
        axi_rd_command = 0;
        base_addr = 0;
        data_ptr = 0;
        data_size_bytes = 0;
        encode_base_addr = 0;
        poly_id_i = 0;
        o_vp_pc = 0;
        o_vp_start = 0;
        o_csr_vp_src0_ptr = 0;
        o_csr_vp_src1_ptr = 0;
        o_csr_vp_rslt_ptr = 0;
        o_csr_vp_rot_step = 0;
        o_csr_vp_ksk_ptr = 0;

        //load expected result
        load_expected_result();
        //load dram data
        load_dram_data();
        //parse op list
        parse_op_list();
        //reset system
        reset();
        //dump_poly(0, 0);
        //load ksk
        load_ksk(64'(unsigned'(`KSK_DRAM_BASE_ADDR)));
    endtask

    initial begin
        init();
        run();
        repeat(100) wait_clk();
        check_result(last_dram_addr);
        $finish();
    end
endmodule