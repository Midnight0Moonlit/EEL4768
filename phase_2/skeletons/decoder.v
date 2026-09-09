`default_nettype none

module decoder (
    input  wire [31:0] i_inst,
    output wire        o_legal,
    output wire        o_halt,
    output wire [ 4:0] o_rs1,
    output wire [ 4:0] o_rs2,
    output wire [ 4:0] o_rd,
    output wire [31:0] o_immediate,
    output wire        o_op1_sel,
    output wire        o_op2_sel,
    output wire [ 2:0] o_alu_opsel,
    output wire        o_alu_sub,
    output wire        o_alu_unsigned,
    output wire        o_alu_arith,
    output wire        o_branch,
    output wire        o_jump,
    output wire        o_branch_equal,
    output wire        o_branch_unsigned,
    output wire        o_branch_invert,
    output wire        o_dmem_ren,
    output wire        o_dmem_wen,
    output wire [ 1:0] o_dmem_align,
    output wire        o_dmem_memb,
    output wire        o_dmem_memh,
    output wire        o_dmem_memw,
    output wire        o_dmem_memu,
    output wire [ 3:0] o_rd_sel,
    output wire        o_pc_sel
);

    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;

    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [4:0] rd;

    assign opcode = i_inst[6:0];
    assign rd     = i_inst[11:7];
    assign funct3 = i_inst[14:12];
    assign rs1    = i_inst[19:15];
    assign rs2    = i_inst[24:20];
    assign funct7 = i_inst[31:25];

    /*
     * RV32I opcodes
     */
    localparam [6:0] OPC_LOAD   = 7'b0000011;
    localparam [6:0] OPC_OPIMM  = 7'b0010011;
    localparam [6:0] OPC_AUIPC  = 7'b0010111;
    localparam [6:0] OPC_STORE  = 7'b0100011;
    localparam [6:0] OPC_OP     = 7'b0110011;
    localparam [6:0] OPC_LUI    = 7'b0110111;
    localparam [6:0] OPC_BRANCH = 7'b1100011;
    localparam [6:0] OPC_JALR   = 7'b1100111;
    localparam [6:0] OPC_JAL    = 7'b1101111;
    localparam [6:0] OPC_SYSTEM = 7'b1110011;

    /*
     * Instruction legality checks
     */

    // R-type instructions.
    // funct7 = 0000000 for normal instructions.
    // funct7 = 0100000 is allowed only for SUB and SRA.
    wire valid_op;
    assign valid_op =
        (opcode == OPC_OP) &&
        (
            ((funct7 == 7'b0000000) &&
             ((funct3 == 3'b000) ||
              (funct3 == 3'b001) ||
              (funct3 == 3'b010) ||
              (funct3 == 3'b011) ||
              (funct3 == 3'b100) ||
              (funct3 == 3'b101) ||
              (funct3 == 3'b110) ||
              (funct3 == 3'b111))) ||
            ((funct7 == 7'b0100000) &&
             ((funct3 == 3'b000) ||
              (funct3 == 3'b101)))
        );

    // I-type ALU instructions.
    wire valid_opimm;
    assign valid_opimm =
        (opcode == OPC_OPIMM) &&
        (
            (funct3 == 3'b000) || // ADDI
            (funct3 == 3'b010) || // SLTI
            (funct3 == 3'b011) || // SLTIU
            (funct3 == 3'b100) || // XORI
            (funct3 == 3'b110) || // ORI
            (funct3 == 3'b111) || // ANDI
            ((funct3 == 3'b001) &&
             (funct7 == 7'b0000000)) || // SLLI
            ((funct3 == 3'b101) &&
             ((funct7 == 7'b0000000) ||
              (funct7 == 7'b0100000)))   // SRLI/SRAI
        );

    // Load instructions: LB, LH, LW, LBU, LHU.
    wire valid_load;
    assign valid_load =
        (opcode == OPC_LOAD) &&
        (
            (funct3 == 3'b000) ||
            (funct3 == 3'b001) ||
            (funct3 == 3'b010) ||
            (funct3 == 3'b100) ||
            (funct3 == 3'b101)
        );

    // Store instructions: SB, SH, SW.
    wire valid_store;
    assign valid_store =
        (opcode == OPC_STORE) &&
        (
            (funct3 == 3'b000) ||
            (funct3 == 3'b001) ||
            (funct3 == 3'b010)
        );

    // Conditional branches: BEQ, BNE, BLT, BGE, BLTU, BGEU.
    wire valid_branch;
    assign valid_branch =
        (opcode == OPC_BRANCH) &&
        (
            (funct3 == 3'b000) ||
            (funct3 == 3'b001) ||
            (funct3 == 3'b100) ||
            (funct3 == 3'b101) ||
            (funct3 == 3'b110) ||
            (funct3 == 3'b111)
        );

    wire valid_jalr;
    assign valid_jalr =
        (opcode == OPC_JALR) &&
        (funct3 == 3'b000);

    wire valid_jal;
    assign valid_jal = (opcode == OPC_JAL);

    wire valid_lui;
    assign valid_lui = (opcode == OPC_LUI);

    wire valid_auipc;
    assign valid_auipc = (opcode == OPC_AUIPC);

    // Only EBREAK is legal in the SYSTEM opcode class.
    wire valid_ebreak;
    assign valid_ebreak = (i_inst == 32'h00100073);

    assign o_legal =
        valid_op      ||
        valid_opimm   ||
        valid_load    ||
        valid_store   ||
        valid_branch  ||
        valid_jalr    ||
        valid_jal     ||
        valid_lui     ||
        valid_auipc   ||
        valid_ebreak;

    assign o_halt = valid_ebreak;

    /*
     * Register fields
     *
     * rs1 and rs2 are don't-care for instructions that do not use them.
     * rd must be x0 for instructions that do not write a register.
     */
    assign o_rs1 =
        (valid_op ||
        valid_opimm ||
        valid_load ||
        valid_store ||
        valid_branch ||
        valid_jalr) ? rs1 : 5'd0;

    assign o_rs2 =
        (valid_op ||
        valid_store ||
        valid_branch) ? rs2 : 5'd0;

    assign o_rd =
        (valid_op    ||
         valid_opimm ||
         valid_load  ||
         valid_jalr  ||
         valid_jal   ||
         valid_lui   ||
         valid_auipc) ? rd : 5'd0;

    /*
     * Immediate generator
     *
     * Format encoding:
     * [0] = R, [1] = I, [2] = S,
     * [3] = B, [4] = U, [5] = J
     */
    wire [5:0] imm_format;

    assign imm_format =
        valid_op                         ? 6'b000001 :
        (valid_opimm || valid_load ||
         valid_jalr)                     ? 6'b000010 :
        valid_store                      ? 6'b000100 :
        valid_branch                     ? 6'b001000 :
        (valid_lui || valid_auipc)       ? 6'b010000 :
        valid_jal                        ? 6'b100000 :
                                           6'b000000;

    imm u_imm (
        .i_inst      (i_inst),
        .i_format    (imm_format),
        .o_immediate (o_immediate)
    );

    /*
     * ALU controls
     */
    assign o_op1_sel = valid_auipc;

    assign o_op2_sel =
        valid_opimm ||
        valid_load  ||
        valid_store ||
        valid_auipc ||
        valid_jalr;

    assign o_alu_opsel =
        (valid_op || valid_opimm) ? funct3 : 3'b000;

    assign o_alu_sub =
        valid_op &&
        (funct3 == 3'b000) &&
        (funct7 == 7'b0100000);

    assign o_alu_unsigned =
        (valid_op &&
         (funct3 == 3'b011)) ||
        (valid_opimm &&
         (funct3 == 3'b011)) ||
        (valid_branch &&
         funct3[1]);

    assign o_alu_arith =
        (valid_op || valid_opimm) &&
        (funct3 == 3'b101) &&
        (funct7 == 7'b0100000);

    /*
     * Branch and jump controls
     */
    assign o_branch = valid_branch;
    assign o_jump   = valid_jal || valid_jalr;

    assign o_branch_equal =
        valid_branch && !funct3[2];

    assign o_branch_unsigned =
        valid_branch && funct3[1];

    assign o_branch_invert =
        valid_branch && funct3[0];

    // Only JALR uses rs1 as the jump target base.
    assign o_pc_sel = valid_jalr;

    /*
     * Data-memory controls
     */
    assign o_dmem_ren = valid_load;
    assign o_dmem_wen = valid_store;

    assign o_dmem_memb =
        (valid_load || valid_store) &&
        (funct3[1:0] == 2'b00);

    assign o_dmem_memh =
        (valid_load || valid_store) &&
        (funct3[1:0] == 2'b01);

    assign o_dmem_memw =
        (valid_load || valid_store) &&
        (funct3[1:0] == 2'b10);

    assign o_dmem_align =
        o_dmem_memw ? 2'b11 :
        o_dmem_memh ? 2'b01 :
                       2'b00;

    // LBU and LHU are the only unsigned loads.
    assign o_dmem_memu =
        valid_load &&
        ((funct3 == 3'b100) ||
         (funct3 == 3'b101));

    /*
     * Register writeback select
     *
     * [0] = ALU result
     * [1] = immediate
     * [2] = PC + 4
     * [3] = memory
     */
    assign o_rd_sel =
        (valid_op ||
         valid_opimm ||
         valid_auipc) ? 4'b0001 :
        valid_lui     ? 4'b0010 :
        (valid_jal ||
         valid_jalr)  ? 4'b0100 :
        valid_load    ? 4'b1000 :
                        4'b0000;

endmodule

`default_nettype wire