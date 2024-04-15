//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: ENCODER
// Module Name: tf_buf
// Modify Date: 
//
// Description:
// mixed twiddle factor rom for encoder
//////////////////////////////////////////////////
module tf_buf #(
    parameter DATA_WIDTH  = 68,
    parameter ADDR_WIDTH  = 11,
    parameter LATENCY     = 1,
    parameter CHANNEL_NUM = 4
) (
    input                           clk,

    input  logic [ADDR_WIDTH-1:0]   raddr,
    output logic [DATA_WIDTH*CHANNEL_NUM-1:0] rdata [CHANNEL_NUM]
);
    rom #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .LATENCY   (LATENCY),
        .INIT_FILE ("")
    ) u_rom_00 (
        .clk        (clk),
        .raddr_i    (raddr),
        .rdata_o    (rdata[0][0+:DATA_WIDTH])
    );

    rom #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .LATENCY   (LATENCY),
        .INIT_FILE ("")
    ) u_rom_10 (
        .clk        (clk),
        .raddr_i    (raddr),
        .rdata_o    (rdata[1][0+:DATA_WIDTH])
    );

    rom #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .LATENCY   (LATENCY),
        .INIT_FILE ("")
    ) u_rom_20 (
        .clk        (clk),
        .raddr_i    (raddr),
        .rdata_o    (rdata[2][0+:DATA_WIDTH])
    );

    rom #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .LATENCY   (LATENCY),
        .INIT_FILE ("")
    ) u_rom_30 (
        .clk        (clk),
        .raddr_i    (raddr),
        .rdata_o    (rdata[3][0+:DATA_WIDTH])
    );

    rom #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .LATENCY   (LATENCY),
        .INIT_FILE ("")
    ) u_rom_01 (
        .clk        (clk),
        .raddr_i    (raddr),
        .rdata_o    (rdata[0][DATA_WIDTH+:DATA_WIDTH])
    );

    rom #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .LATENCY   (LATENCY),
        .INIT_FILE ("")
    ) u_rom_11 (
        .clk        (clk),
        .raddr_i    (raddr),
        .rdata_o    (rdata[1][DATA_WIDTH+:DATA_WIDTH])
    );

    rom #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .LATENCY   (LATENCY),
        .INIT_FILE ("")
    ) u_rom_21 (
        .clk        (clk),
        .raddr_i    (raddr),
        .rdata_o    (rdata[2][DATA_WIDTH+:DATA_WIDTH])
    );

    rom #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .LATENCY   (LATENCY),
        .INIT_FILE ("")
    ) u_rom_31 (
        .clk        (clk),
        .raddr_i    (raddr),
        .rdata_o    (rdata[3][DATA_WIDTH+:DATA_WIDTH])
    );

    rom #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .LATENCY   (LATENCY),
        .INIT_FILE ("")
    ) u_rom_02 (
        .clk        (clk),
        .raddr_i    (raddr),
        .rdata_o    (rdata[0][2*DATA_WIDTH+:DATA_WIDTH])
    );

    rom #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .LATENCY   (LATENCY),
        .INIT_FILE ("")
    ) u_rom_12 (
        .clk        (clk),
        .raddr_i    (raddr),
        .rdata_o    (rdata[1][2*DATA_WIDTH+:DATA_WIDTH])
    );

    rom #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .LATENCY   (LATENCY),
        .INIT_FILE ("")
    ) u_rom_22 (
        .clk        (clk),
        .raddr_i    (raddr),
        .rdata_o    (rdata[2][2*DATA_WIDTH+:DATA_WIDTH])
    );

    rom #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .LATENCY   (LATENCY),
        .INIT_FILE ("")
    ) u_rom_32 (
        .clk        (clk),
        .raddr_i    (raddr),
        .rdata_o    (rdata[3][2*DATA_WIDTH+:DATA_WIDTH])
    );


    rom #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .LATENCY   (LATENCY),
        .INIT_FILE ("")
    ) u_rom_03 (
        .clk        (clk),
        .raddr_i    (raddr),
        .rdata_o    (rdata[0][3*DATA_WIDTH+:DATA_WIDTH])
    );

    rom #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .LATENCY   (LATENCY),
        .INIT_FILE ("")
    ) u_rom_13 (
        .clk        (clk),
        .raddr_i    (raddr),
        .rdata_o    (rdata[1][3*DATA_WIDTH+:DATA_WIDTH])
    );

    rom #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .LATENCY   (LATENCY),
        .INIT_FILE ("")
    ) u_rom_23 (
        .clk        (clk),
        .raddr_i    (raddr),
        .rdata_o    (rdata[2][3*DATA_WIDTH+:DATA_WIDTH])
    );

    rom #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .LATENCY   (LATENCY),
        .INIT_FILE ("")
    ) u_rom_33 (
        .clk        (clk),
        .raddr_i    (raddr),
        .rdata_o    (rdata[3][3*DATA_WIDTH+:DATA_WIDTH])
    );


endmodule : tf_buf

module rom #(
    parameter DATA_WIDTH = 68,
    parameter ADDR_WIDTH = 13,
    parameter LATENCY    = 1,
    parameter INIT_FILE  = ""
) (
    input                         clk,
    input  logic [ADDR_WIDTH-1:0] raddr_i,
    output logic [DATA_WIDTH-1:0] rdata_o
);
    logic [DATA_WIDTH-1:0] mem [(1<<ADDR_WIDTH)-1:0];
    (* MAX_FANOUT = 100 *) logic [DATA_WIDTH-1:0] mem_reg [LATENCY-1:0];

    initial begin
        $readmemb(INIT_FILE, mem);
    end

    always_ff @(posedge clk) begin
        mem_reg[0] <= mem[raddr_i];
    end


    always_ff @(posedge clk) begin
        for(int i=0; i<LATENCY-1;i++)
            mem_reg[i+1] <= mem_reg[i];
    end

    assign rdata_o = mem_reg[LATENCY-1];
endmodule : rom

// module tf_buf_tb;
//     parameter PERIOD = 10;
//     parameter ADDR_WIDTH = 13;
//     parameter DATA_WIDTH = 68;

//     bit clk;
//     logic [ADDR_WIDTH-1:0]   raddr;
//     logic [DATA_WIDTH*4-1:0] rdata;
//     always #(PERIOD/2) clk = ~clk;

//     initial begin
//         clk = 1'b0;
//         repeat(10) @(posedge clk);
//         # 0.1
//         for(raddr = '0; raddr != '1; raddr++) begin
//             @(posedge clk);
//             # 0.1
//             $display("ADDR = %d, DATA = %b", raddr, rdata[0+:DATA_WIDTH]);
//         end
//         $finish;
//     end

//     tf_buf #(
//         .DATA_WIDTH (DATA_WIDTH),
//         .ADDR_WIDTH (ADDR_WIDTH),
//         .LATENCY    (1)
//     ) u_tf_buf (
//         .clk    (clk),
//         .raddr  (raddr),
//         .rdata  (rdata)
//     );
// endmodule