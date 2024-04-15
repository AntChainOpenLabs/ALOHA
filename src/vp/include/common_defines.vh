//////////////////////////////////////////////////
// Author: 
// Email: 
//
// Project Name: MVP
// Module Name: common_defines
// Modify Date: 
// Description: Attributes of common modules (modadd, modsub, etc.)
//////////////////////////////////////////////////

`ifndef __COMMON_DEFINES_VH__
`define __COMMON_DEFINES_VH__

`timescale 1ns/100ps

`define COMMON_DATA_LENGTH      4096
`define COMMON_BRAM_DELAY       1       // delay of Block RAM
`define COMMON_IMUL_DELAY       1       // delay of Int 64 multiplication
`define COMMON_BLAST_DELAY      1       // delay of Last pipeline stages of Barrett Reduction
`define COMMON_MODMUL_DELAY     4       // `COMMON_MUL_DELAY*3+`COMMON_BLAST_DELAY       // delay of ModMul module
`define COMMON_MODADD_DELAY     1       // delay of ModAdd module
`define COMMON_MODSUB_DELAY     1       // delay of ModSub module
`define COMMON_MODSUBRED_DELAY  2       // delay of ModSubRed module

// VP MODULE_DELAY:
`define COMMON_AGEN_DELAY       1       // Gen address
`define COMMON_VMU_DELAY        19       // Unit mem operation for (pipeline total length)
`define COMMON_MEMR_DELAY       2       // Memory read cycles, i.e., SPM
`define COMMON_MEMW_DELAY       1       // Memory write cycles, i.e., SPM

`define PROJECT_ROOT            ""    // Please config the PROJECT_PATH

`define max(a, b) (((a) > (b)) ? (a) : (b))
`define min(a, b) (((a) < (b)) ? (a) : (b))

`endif // __COMMON_DEFINES_VH__
