//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: VP
// Module Name: vp_top_tb
// Modify Date: 
//
// Description:
// VP integrated verification testbench
//////////////////////////////////////////////////

`timescale 1ns/100ps
`include "vp_defines.vh"
`include "common_defines.vh"

module top;
    localparam ISRAM_ADDR_WIDTH = $clog2(`IRAM_DEPTH);
    logic[`INST_WIDTH - 1:0] isram[0:`IRAM_DEPTH - 1];
    longint unsigned i;

    initial begin
        for(i = 0;i < `IRAM_DEPTH;i++) begin
            isram[i] = 0;
        end
        
        $readmemh("encode_post.mem", isram, 0);
        $readmemh("mul_plain.mem", isram, 64);
        $readmemh("hom_add.mem", isram, 160);
        $readmemh("keyswitch.mem", isram, 256);
        $writememh("isram_file.mem", isram);
    end
endmodule