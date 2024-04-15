//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: 
// Module Name: expander
// Modify Date:

// Description: decode Instruction to opcodes, see
    // u8 o_op_b0r;
    // u8 o_op_b0w;
    // u8 o_op_b1r;
    // u8 o_op_b1w;
    // u8 o_op_alu;
    // u64 o_scalar_alu;
    // u8 o_op_muxo;
    // u8 o_op_muxi;
    // u8 o_op_ls;
    // u64 o_scalar_ls;
//////////////////////////////////////////////////

`include "vp_defines.vh"
module expander #(
    parameter INST_WIDTH        = `INST_WIDTH       ,
    parameter CONFIG_OP_WIDTH   = `CONFIG_OP_WIDTH  ,
    parameter MUXO_OP_WIDTH     = `MUXO_OP_WIDTH    ,
    parameter MUXI_OP_WIDTH     = `MUXI_OP_WIDTH    ,
    parameter RW_OP_WIDTH       = `RW_OP_WIDTH      ,     // address + enable
    parameter ALU_OP_WIDTH      = `ALU_OP_WIDTH     ,
    parameter ICONN_OP_WIDTH    = `ICONN_OP_WIDTH   ,
    parameter NTT_OP_WIDTH      = `NTT_OP_WIDTH     ,
    parameter LSU_OP_WIDTH      = `LSU_OP_WIDTH     ,
    parameter SCALAR_WIDTH      = `SCALAR_WIDTH 
)(
    input                                   clk,
    input                                   rst_n,
    // from/to IQueue & PC      
    input                                   i_decode_en,
    input         [INST_WIDTH-1:0]          i_inst,
    output                                  o_decode_en,
    output   reg                            o_expander_break,
    // from/to VXU/VMU
    // config
    output   reg  [CONFIG_OP_WIDTH-1:0]     o_op_config,
    output   reg  [SCALAR_WIDTH-1:0]        o_scalar_config,
    // vxu
    output   reg  [RW_OP_WIDTH-1:0]         o_op_b0r,
    output   reg  [RW_OP_WIDTH-1:0]         o_op_b0w,
    output   reg  [RW_OP_WIDTH-1:0]         o_op_b1r,
    output   reg  [RW_OP_WIDTH-1:0]         o_op_b1w,
    output   reg  [ALU_OP_WIDTH-1:0]        o_op_alu,
    output   reg  [SCALAR_WIDTH-1:0]        o_scalar_alu,
    output   reg  [ICONN_OP_WIDTH-1:0]      o_op_iconn,
    output   reg  [SCALAR_WIDTH-1:0]        o_scalar_iconn,
    output   reg  [NTT_OP_WIDTH-1:0]        o_op_ntt,
    output   reg  [MUXO_OP_WIDTH-1:0]       o_op_muxo,
    output   reg  [MUXI_OP_WIDTH-1:0]       o_op_muxi,
    // vmu
    output   reg  [LSU_OP_WIDTH-1:0]        o_op_ls,
    output   reg  [SCALAR_WIDTH-1:0]        o_scalar_ls,
    input    logic[SCALAR_WIDTH - 1:0]      i_csr_vp_step
);

// Funct6
localparam FUNCT6_VL        =   6'b000100;
localparam FUNCT6_MODQ      =   6'b001000;
localparam FUNCT6_MODIQ     =   6'b001100;
localparam FUNCT6_BREAK     =   6'b010000;
localparam FUNCT6_NOP       =   6'b000000;
localparam FUNCT6_FQMUL     =   6'b000001;
localparam FUNCT6_FQADD     =   6'b000101;
localparam FUNCT6_FQSUB     =   6'b001001;
localparam FUNCT6_FQMOD     =   6'b001101;
localparam FUNCT6_VCP       =   6'b010001;
localparam FUNCT6_VAUT      =   6'b010101;
localparam FUNCT6_ROLI      =   6'b011001;
localparam FUNCT6_NTT       =   6'b000010;
localparam FUNCT6_INTT      =   6'b000110;
localparam FUNCT6_VLE       =   6'b000011;
localparam FUNCT6_VSE       =   6'b000111;

// Funct3
localparam FUNCT3_VVV       =   3'b000;
localparam FUNCT3_VVS       =   3'b001;
localparam FUNCT3_VSV       =   3'b010;
localparam FUNCT3_VSS       =   3'b011;

// opConfig
localparam OP_CONFIG_NONE   =   `CONFIG_OP_WIDTH'b00;
localparam OP_CONFIG_VLEN   =   `CONFIG_OP_WIDTH'b01;
localparam OP_CONFIG_MODQ   =   `CONFIG_OP_WIDTH'b10;
localparam OP_CONFIG_MODIQ  =   `CONFIG_OP_WIDTH'b11;

// opALU
localparam OP_ALU_MULVV     =   `ALU_OP_WIDTH'b00000;
localparam OP_ALU_MULVS     =   `ALU_OP_WIDTH'b00100;
localparam OP_ALU_ADDVV     =   `ALU_OP_WIDTH'b00001;
localparam OP_ALU_ADDVS     =   `ALU_OP_WIDTH'b00101;
localparam OP_ALU_SUBVV     =   `ALU_OP_WIDTH'b00010;
localparam OP_ALU_SUBVS     =   `ALU_OP_WIDTH'b00110;
localparam OP_ALU_SUBSV     =   `ALU_OP_WIDTH'b01010;
localparam OP_ALU_MODV      =   `ALU_OP_WIDTH'b00011;
localparam OP_ALU_CT        =   `ALU_OP_WIDTH'b10000;
localparam OP_ALU_GS        =   `ALU_OP_WIDTH'b10011;
localparam OP_ALU_MADDVS    =   `ALU_OP_WIDTH'b10101;
localparam OP_ALU_MSUBVS    =   `ALU_OP_WIDTH'b10110;
localparam OP_ALU_MSUBSV    =   `ALU_OP_WIDTH'b11010;

//o_op_ls
localparam OP_VMU_NONE      = `LSU_OP_WIDTH'b00;
localparam OP_VMU_LOAD      = `LSU_OP_WIDTH'b01;
localparam OP_VMU_STORE     = `LSU_OP_WIDTH'b10;

wire [5:0]                  inst_funct6;
wire                        inst_mask;
wire [4:0]                  inst_vs2;
wire [4:0]                  inst_vs1;
wire [2:0]                  inst_funct3;
wire [4:0]                  inst_vd;
wire [6:0]                  inst_rvcode;
wire [SCALAR_WIDTH-1:0]     inst_imm;

assign inst_funct6   = i_inst[31+SCALAR_WIDTH-1:26+SCALAR_WIDTH];
assign inst_mask     = i_inst[26+SCALAR_WIDTH-1:25+SCALAR_WIDTH];
assign inst_vs2      = i_inst[25+SCALAR_WIDTH-1:20+SCALAR_WIDTH];
assign inst_vs1      = i_inst[20+SCALAR_WIDTH-1:15+SCALAR_WIDTH];
assign inst_funct3   = i_inst[15+SCALAR_WIDTH-1:12+SCALAR_WIDTH];
assign inst_vd       = i_inst[12+SCALAR_WIDTH-1: 7+SCALAR_WIDTH];
assign inst_rvcode   = i_inst[ 7+SCALAR_WIDTH-1: 0+SCALAR_WIDTH];
assign inst_imm      = i_inst[ 0+SCALAR_WIDTH-1: 0             ];


wire                        i_decode_en_wire;
wire                        o_decode_en_wire;

assign i_decode_en_wire = i_decode_en && (!o_expander_break);
assign o_decode_en = o_decode_en_wire && (!o_expander_break);
gnrl_dff_r #(1,`DECODE_DELAY) dec_opq_vld_dff (clk, rst_n, i_decode_en_wire, o_decode_en_wire);

// o_expander_break, a pulse signal
always @(posedge clk) begin
    if (!rst_n) begin
        o_expander_break <= 1'b0;
    end
    else begin
        case ({inst_funct6,i_decode_en_wire})
            {FUNCT6_BREAK,1'b1}:o_expander_break <= 1'b1;
            default:o_expander_break <= 1'b0;
        endcase
    end
end

// OpConfig, ScalarConfig
always @(posedge clk) begin
    case (inst_funct6)
        FUNCT6_VL       :   begin
                            o_op_config     <= OP_CONFIG_VLEN;
                            o_scalar_config <= inst_imm;
        end
        FUNCT6_MODQ     :   begin 
                            o_op_config <= OP_CONFIG_MODQ;
                            o_scalar_config <= inst_imm;
        end
        FUNCT6_MODIQ    :   begin 
                            o_op_config <= OP_CONFIG_MODIQ;
                            o_scalar_config <= inst_imm;
        end
        default         :   begin 
                            o_op_config <= OP_CONFIG_NONE;
                            o_scalar_config <= 0;
        end
    endcase
end
    
// o_op_b0r, o_op_b1r, o_op_alu, o_scalar_alu, o_op_muxo
always @(posedge clk) begin
    case (inst_funct6)
    FUNCT6_FQMUL: // begin vfqmul
    begin
        case (inst_funct3)
        FUNCT3_VVV:
        begin                         // vfqmul.vv
            if ((inst_vs1 & 1'b1) == 0) // inst_vs1 even VREG
            begin
                /* opcode */
                o_op_b0r <= {inst_vs1,1'b1}; // LSb <= 1, i.e., enabled
                o_op_b1r <= {inst_vs2,1'b1};
                o_op_alu <= OP_ALU_MULVV;
                o_scalar_alu <= 'b0;
                o_op_muxo <= 'b0100;
            end
            else
            begin
                /* opcode */
                o_op_b0r <= {inst_vs2,1'b1};
                o_op_b1r <= {inst_vs1,1'b1};
                o_op_alu <= OP_ALU_MULVV;
                o_scalar_alu <= 'b0;
                o_op_muxo <= 'b1000; // o_op_muxo <= 'b010000 should also pass
            end
        end // end vfqmul.vv

        FUNCT3_VVS:
        begin                         // vfqmul.vs
            if ((inst_vs1 & 'b1) == 0) // inst_vs1 even VREG
            begin
                /* opcode */
                o_op_b0r <= {inst_vs1,1'b1}; // LSb <= 1, i.e., enabled
                o_op_b1r <= 'b000000;
                o_op_alu <= OP_ALU_MULVS;
                o_scalar_alu <= inst_imm;
                o_op_muxo <= 'b0100;
            end
            else
            begin
                /* opcode */
                o_op_b0r <= 'b000000;
                o_op_b1r <= {inst_vs1,1'b1};
                o_op_alu <= OP_ALU_MULVS;
                o_scalar_alu <= inst_imm;
                o_op_muxo <= 'b1000; // o_op_muxo <= 'b010000 should also pass
            end
            
        end // end vfqmul.vs
        default begin
            /* opcode */
            o_op_b0r <= 'b000000;
            o_op_b1r <= 'b000000;
            o_op_alu <= OP_ALU_MULVV;
            o_scalar_alu <= 0;
            o_op_muxo <= 'b0000; 
        end
        endcase
    end     // end vfqmul
    FUNCT6_FQADD:
    begin // begin vfqadd
        case (inst_funct3)
        FUNCT3_VVV:
        begin                         // vfqadd.vv
            if ((inst_vs1 & 'b1) == 0) // inst_vs1 even VREG
            begin
                /* opcode */
                o_op_b0r <= {inst_vs1,1'b1}; // LSb <= 1, i.e., enabled
                o_op_b1r <= {inst_vs2,1'b1};
                o_op_alu <= OP_ALU_ADDVV;
                o_scalar_alu <= 'b0;
                o_op_muxo <= 'b0100;
            end
            else
            begin
                /* opcode */
                o_op_b0r <= {inst_vs2,1'b1};
                o_op_b1r <= {inst_vs1,1'b1};
                o_op_alu <= OP_ALU_ADDVV;
                o_scalar_alu <= 'b0;
                o_op_muxo <= 'b1000;
            end
            
        end // end vfqadd.vv

        FUNCT3_VVS:
        begin                         // vfqadd.vs
            if ((inst_vs1 & 'b1) == 0) // inst_vs1 even VREG
            begin
                /* opcode */
                o_op_b0r <= {inst_vs1,1'b1}; // LSb <= 1, i.e., enabled
                o_op_b1r <= 'b000000;
                o_op_alu <= OP_ALU_ADDVS;
                o_scalar_alu <= inst_imm;
                o_op_muxo <= 'b0100;
            end
            else
            begin
                /* opcode */
                o_op_b0r <= 'b000000;
                o_op_b1r <= {inst_vs1,1'b1};
                o_op_alu <= OP_ALU_ADDVS;
                o_scalar_alu <= inst_imm;
                o_op_muxo <= 'b1000;
            end
            
        end // end vfqadd.vs
        default begin
            /* opcode */
            o_op_b0r <= 'b000000;
            o_op_b1r <= 'b000000;
            o_op_alu <= OP_ALU_ADDVV;
            o_scalar_alu <= 0;
            o_op_muxo <= 'b0000; 
        end        
        endcase
        
    end // end vfqadd
    FUNCT6_FQSUB:
    begin // begin vfqsub
        case (inst_funct3)
        FUNCT3_VVV:
        begin                         // vfqsub.vv
            if ((inst_vs1 & 'b1) == 0) // inst_vs1 even VREG
            begin
                /* opcode */
                o_op_b0r <= {inst_vs1,1'b1}; // LSb <= 1, i.e., enabled
                o_op_b1r <= {inst_vs2,1'b1};
                o_op_alu <= OP_ALU_SUBVV;
                o_scalar_alu <= 'b0;
                o_op_muxo <= 'b0100;
            end
            else
            begin
                /* opcode */
                o_op_b0r <= {inst_vs2,1'b1};
                o_op_b1r <= {inst_vs1,1'b1};
                o_op_alu <= OP_ALU_SUBVV;
                o_scalar_alu <= 'b0;
                o_op_muxo <= 'b1000;
            end
            
        end // end vfqsub.vv

        FUNCT3_VVS:
        begin                         // vfqsub.vs
            if ((inst_vs1 & 'b1) == 0) // inst_vs1 even VREG
            begin
                /* opcode */
                o_op_b0r <= {inst_vs1,1'b1}; // LSb <= 1, i.e., enabled
                o_op_b1r <= 'b000000;
                o_op_alu <= OP_ALU_SUBVS;
                o_scalar_alu <= inst_imm;
                o_op_muxo <= 'b0100;
            end
            else
            begin
                /* opcode */
                o_op_b0r <= 'b000000;
                o_op_b1r <= {inst_vs1,1'b1};
                o_op_alu <= OP_ALU_SUBVS;
                o_scalar_alu <= inst_imm;
                o_op_muxo <= 'b1000;
            end
            
        end // end vfqsub.vs
        FUNCT3_VSV:
        begin                         // vfqsub.sv
            if ((inst_vs2 & 'b1) == 0) // inst_vs1 even VREG
            begin
                /* opcode */
                o_op_b0r <= {inst_vs2,1'b1}; // LSb <= 1, i.e., enabled
                o_op_b1r <= 'b000000;
                o_op_alu <= OP_ALU_SUBSV;
                o_scalar_alu <= inst_imm;
                o_op_muxo <= 'b0100;
            end
            else
            begin
                /* opcode */
                o_op_b0r <= 'b000000;
                o_op_b1r <= {inst_vs2,1'b1};
                o_op_alu <= OP_ALU_SUBSV;
                o_scalar_alu <= inst_imm;
                o_op_muxo <= 'b1000;
            end
            
        end // end vfqsub.sv
        default begin
            /* opcode */
            o_op_b0r <= 'b000000;
            o_op_b1r <= 'b000000;
            o_op_alu <= OP_ALU_SUBVV;
            o_scalar_alu <= 0;
            o_op_muxo <= 'b000000; 
        end
        endcase
    end // end vfqsub
    FUNCT6_FQMOD:
    begin                         // vfqmod
        if ((inst_vs1 & 'b1) == 0) // inst_vs1 even VREG
        begin
            /* opcode */
            o_op_b0r <= {inst_vs1,1'b1}; // LSb <= 1, i.e., enabled
            o_op_b1r <= 'b000000;
            o_op_alu <= OP_ALU_MODV;
            o_scalar_alu <= 'b0;
            o_op_muxo <= 'b0100;
        end
        else
        begin
            /* opcode */
            o_op_b0r <= 'b000000;
            o_op_b1r <= {inst_vs1,1'b1};
            o_op_alu <= OP_ALU_MODV;
            o_scalar_alu <= 'b0;
            o_op_muxo <= 'b1000;
        end
        
    end // vfqmod
    FUNCT6_VCP:
    begin                         // vcpy
        if ((inst_vs1 & 'b1) == 0) // inst_vs1 even VREG
        begin
            /* opcode */
            o_op_b0r <= {inst_vs1,1'b1}; // LSb <= 1, i.e., enabled
            o_op_b1r <= 'b000000;
            o_op_alu <= OP_ALU_ADDVS;
            o_scalar_alu <= 'b0;
            o_op_muxo <= 'b0100;
        end
        else
        begin
            /* opcode */
            o_op_b0r <= 'b000000;
            o_op_b1r <= {inst_vs1,1'b1};
            o_op_alu <= OP_ALU_ADDVS;
            o_scalar_alu <= 'b0;
            o_op_muxo <= 'b1000;
        end
        
    end // vcpy
    FUNCT6_NTT:
    begin                         // vntt
        if ((inst_vs1 & 'b1) == 'b0) // vs1 even VREG
        begin
            /* opcode */
            o_op_b0r <= {inst_vs1,1'b1};
            o_op_b1r <= 'b000000;
            o_op_alu <= OP_ALU_CT;
            o_scalar_alu <= 'b0;
            o_op_muxo <= 'b0000;
        end
        else
        begin
            /* opcode */
            o_op_b0r <= 'b000000; 
            o_op_b1r <= {inst_vs1,1'b1};
            o_op_alu <= OP_ALU_CT;
            o_scalar_alu <= 'b0;
            o_op_muxo <= 'b0010;
        end
    end // vntt
    FUNCT6_INTT:
    begin                         // vintt
        if ((inst_vs1 & 'b1) == 0) // vs1 even VREG
        begin
            /* opcode */
            o_op_b0r <= {inst_vs1,1'b1};
            o_op_b1r <= 'b000000;
            o_op_alu <= OP_ALU_GS;
            o_scalar_alu <= 'b0;
            o_op_muxo <= 'b0000;
        end
        else
        begin
            /* opcode */
            o_op_b0r <= 'b000000; 
            o_op_b1r <= {inst_vs1,1'b1};
            o_op_alu <= OP_ALU_GS;
            o_scalar_alu <= 'b0;
            o_op_muxo <= 'b1000;
        end
    end // vintt
    FUNCT6_VAUT:
    begin
        if ((inst_vs1 & 'b1) == 'b0) // vs1 even VREG
        begin
            /* opcode */
            o_op_b0r <= {inst_vs1,1'b1};
            o_op_b1r <= 'b000000;
            o_op_alu <= OP_ALU_MULVV;
            o_scalar_alu <= 'b0;
            o_op_muxo <= 'b0000;
        end
        else
        begin
            /* opcode */
            o_op_b0r <= 'b000000; 
            o_op_b1r <= {inst_vs1,1'b1};
            o_op_alu <= OP_ALU_MULVV;
            o_scalar_alu <= 'b0;
            o_op_muxo <= 'b0010;
        end
    end //vaut
    FUNCT6_ROLI:
    begin
        if ((inst_vs1 & 'b1) == 0) // vs1 even VREG
        begin
            /* opcode */
            o_op_b0r <= {inst_vs1,1'b1};
            o_op_b1r <= 'b000000;
            o_op_alu <= OP_ALU_MULVV;
            o_scalar_alu <= 'b0;
            o_op_muxo <= 'b0000;
        end
        else
        begin
            /* opcode */
            o_op_b0r <= 'b000000; 
            o_op_b1r <= {inst_vs1,1'b1};
            o_op_alu <= OP_ALU_MULVV;
            o_scalar_alu <= 'b0;
            o_op_muxo <= 'b0010;
        end
    end //vroli
    FUNCT6_VSE:
    begin                         // vse
        if ((inst_vs1 & 'b1) == 0) // inst_vs1 even VREG
        begin
            /* opcode */
            o_op_b0r <= {inst_vs1,1'b1}; // LSb <= 1, i.e., enabled
            o_op_b1r <= 'b000000;
            o_op_alu <= OP_ALU_MULVV;    // actually, NOP
            o_scalar_alu <= 'b0;
            o_op_muxo <= 'b000000;
        end
        else
        begin
            /* opcode */
            o_op_b0r <= 'b000000;
            o_op_b1r <= {inst_vs1,1'b1};
            o_op_alu <= OP_ALU_MULVV;    // actually, NOP
            o_scalar_alu <= 'b0;
            o_op_muxo <= 'b000001;
        end
        
    end // vse
    default:
    begin
        /* opcode */
        o_op_b0r <= 'b000000;
        o_op_b1r <= 'b000000;
        o_op_alu <= OP_ALU_MULVV;
        o_scalar_alu <= 'b0;
        o_op_muxo <= 'b000000;
    end
    endcase
    end

    always @(posedge clk) begin
    // o_op_iconn, o_scalar_iconn
    case (inst_funct6)
    FUNCT6_NTT:
    begin
        o_op_iconn <= 'b100;
        o_scalar_iconn <= 'b0;
    end
    FUNCT6_INTT:
    begin
        o_op_iconn <= 'b101;
        o_scalar_iconn <= 'b0;
    end
    FUNCT6_VAUT:
    begin
        o_op_iconn <= 'b001;
        o_scalar_iconn <= i_csr_vp_step + inst_imm;
    end
    FUNCT6_ROLI:
    begin
        o_op_iconn <= 'b010;
        o_scalar_iconn <= inst_imm;
    end
    default:
    begin
        /* opcode */
        o_op_iconn <= 'b000;
        o_scalar_iconn <= 'b0;
    end
    endcase
    end
    
    always @(posedge clk) begin
    // o_op_ntt
    case (inst_funct6)      
    FUNCT6_NTT:
    begin
        o_op_ntt <= 'b010;
    end
    FUNCT6_INTT:
    begin
        o_op_ntt <= 'b011;
    end
    default:
    begin
        /* opcode */
        o_op_ntt <= 'b000;
    end
    endcase
    end

    always @(posedge clk) begin
    // o_op_b1w, o_op_b0w, MUXI
    case (inst_funct6 & 6'b000011) // Last 2 bits of funct6
    2'b01: // all vfq cpy
    begin
        if ((inst_vd & 'b1) == 0)
        begin
            o_op_b0w  <= {inst_vd,1'b1};
            o_op_b1w  <= 'b000000;
            o_op_muxi <= (((inst_funct6 == FUNCT6_ROLI) || (inst_funct6 == FUNCT6_VAUT)) == 1'b1)? 'b0100:'b0000;
        end
        else
        begin
            o_op_b0w  <= 'b000000;
            o_op_b1w  <= {inst_vd,1'b1};
            o_op_muxi <= (((inst_funct6 == FUNCT6_ROLI) || (inst_funct6 == FUNCT6_VAUT)) == 1'b1)? 'b0001:'b0000;
        end
        
    end // end  vfq cpy
    2'b10: // vntt/vintt
    begin
        case (inst_funct6)
        FUNCT6_NTT:
        begin
            if ((inst_vd & 'b1) == 0)
            begin
                o_op_b0w  <= {inst_vd,1'b1};
                o_op_b1w  <= 'b000000;
                o_op_muxi <= 'b0000;
            end
            else
            begin
                o_op_b0w  <= 'b000000;
                o_op_b1w  <= {inst_vd,1'b1};
                o_op_muxi <= 'b0000;
            end
        end
        FUNCT6_INTT:
        begin
            if ((inst_vd & 'b1) == 0)
            begin
                o_op_b0w  <= {inst_vd,1'b1};
                o_op_b1w  <= 'b000000;
                o_op_muxi <= 'b0100;
            end
            else
            begin
                o_op_b0w  <= 'b000000;
                o_op_b1w  <= {inst_vd,1'b1};
                o_op_muxi <= 'b0001;
            end
        end
        default:
        begin
            
        end
        endcase
    end
    2'b11:
    begin
        if (inst_funct6 == 6'b000011)
        begin // vle
            if ((inst_vd & 'b1) == 0)
            begin
                o_op_b0w  <= {inst_vd,1'b1};
                o_op_b1w  <= 'b000000;
                o_op_muxi <= 'b1100;
            end
            else
            begin
                o_op_b0w  <= 'b000000;
                o_op_b1w  <= {inst_vd,1'b1};
                o_op_muxi <= 'b0011;
            end
        end
        else begin
            o_op_b0w  <= 'b000000;
            o_op_b1w  <= 'b000000;
            o_op_muxi <= 'b0000;
        end
    end // end vle
    default:
    begin
        /* opcode */
        o_op_b0w  <= 'b000000;
        o_op_b1w  <= 'b000000;
        o_op_muxi <= 'b0000;
    end
    endcase
end

always @(posedge clk) begin
    // o_op_ls, o_scalar_ls;
    case (inst_funct6)
    6'b000011: // vle
    begin
        o_op_ls <= OP_VMU_LOAD; // load
        o_scalar_ls <= inst_imm;
        
    end              // vle
    6'b000111: // vse
    begin
        o_op_ls <= OP_VMU_STORE; // store
        o_scalar_ls <= inst_imm;
        
    end // vse
    default:
    begin
        /* opcode */
        o_op_ls <= OP_VMU_NONE;
        o_scalar_ls <= 'b0;
    end
    endcase
end

endmodule