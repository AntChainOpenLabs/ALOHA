module tb_ksk_mem;
    parameter PERIOD = 10;
    parameter DATA_WIDTH = 64;
    parameter NUM_LANE = 128;
    parameter NB_PIPE = 1;
    parameter KSK_MEM_DEPTH = 9216;
    parameter AXI_DATA_WIDTH = 512;
    parameter AXI_ADDR_WIDTH = 64;
    localparam KSK_ADDR_WIDTH = $clog2(KSK_MEM_DEPTH);

    parameter VP_CNT = 9216;

    bit clk;

    logic [AXI_ADDR_WIDTH-1:0] waddr;
    logic [AXI_DATA_WIDTH-1:0] wdata;
    logic                      wen;

    logic [KSK_ADDR_WIDTH-1:0]  raddr;
    logic                       ren;
    logic [NUM_LANE*DATA_WIDTH-1:0]  o_vp_rd_data;

    int vp_cnt;
    logic [AXI_DATA_WIDTH-1:0] wr_data;

    int wfid;


    initial begin
        clk = 0;
        wen = 0;
        ren = 0;
        repeat(10) @(posedge clk);
        axi_wr;
        fork
            vp_rd;
            vp_monitor;
        join
        $system("rm wr_ksk.txt");
        $finish;

    end

    always #(PERIOD/2) clk = ~clk;

    task wait_comb;
        # 0.1;
    endtask

    task axi_wr;
        waddr = '0;
        wfid = $fopen("./wr_ksk.txt", "w");
        repeat(VP_CNT<<4) begin
            std::randomize(wdata);
            wen = 1'b1;
            // $display("wr_addr = %0d, wr_data = %h", waddr, wdata);
            $fwrite(wfid, "%h \n", $unsigned(wdata));
            @(posedge clk);
            wait_comb;
            waddr = waddr + 1;
        end
        wait_comb;
        wen = 0;
        $fclose(wfid);
    endtask

    task vp_rd;
        raddr = '0;
        repeat(VP_CNT) begin
            ren = 1'b1;
            @(posedge clk);
            wait_comb;
            raddr = raddr + 1'b1;
        end
        wait_comb;
        ren = 0;
        repeat(10) @(posedge clk);
    endtask

    task vp_monitor;
        wfid = $fopen("./wr_ksk.txt", "r");
        vp_cnt = VP_CNT;
        wait(ren);
        repeat(NB_PIPE+1) @(posedge clk);
        while (vp_cnt > 0) begin
            // $display("rd_data = %h", o_vp_rd_data);
            for (int i=0; i<16; ++i) begin
                $fscanf(wfid, "%h", wr_data);
                assert(wr_data == o_vp_rd_data[i*AXI_DATA_WIDTH+:AXI_DATA_WIDTH]) $display("\033[32m wr_data = %h \t rd_data = %h \033[0m", wr_data, o_vp_rd_data[i*AXI_DATA_WIDTH+:AXI_DATA_WIDTH]);
                else $display("wr_data = %h \t rd_data = %h", wr_data, o_vp_rd_data[i*AXI_DATA_WIDTH+:AXI_DATA_WIDTH]);
            end
            vp_cnt --;
            @(posedge clk);
        end
        $fclose(wfid);
    endtask


    ksk_mem #(
        .DATA_WIDTH      (DATA_WIDTH),
        .NUM_LANE        (NUM_LANE),
        .NB_PIPE         (NB_PIPE),
        .KSK_MEM_DEPTH   (KSK_MEM_DEPTH),
        .AXI_DATA_WIDTH  (AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH  (AXI_ADDR_WIDTH)
    ) u_ksk_mem (
        .clk            (clk),
        .rst_n          (),
        .i_vp_rd_addr   (raddr),
        .i_vp_rd_en     (ren),
        .o_vp_rd_data   (o_vp_rd_data),
        .i_axi_wr_en    (wen),
        .i_axi_addr     (waddr),
        .i_axi_wr_data  (wdata)
    );
    initial begin
        $fsdbDumpfile("top.fsdb");
        $fsdbDumpvars("+all");
        // $fsdbDumpMDA();
    end
endmodule