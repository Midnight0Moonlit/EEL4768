`default_nettype none

module hart #(
    // After reset, the program counter (PC) should be initialized to this
    // address and start executing instructions from there.
    parameter RESET_ADDR = 32'h00000000,
    // When set, pipeline forwarding optimizations are enabled.
    parameter FWD_EN = 1,
    // When set, register file bypassing is enabled.
    parameter BYPASS_EN = 1
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // Instruction fetch goes through a read only instruction memory (imem)
    // port. The port accepts a 32-bit address (e.g. from the program counter)
    // per cycle and combinationally returns a 32-bit instruction word. This
    // is not representative of a realistic memory interface; it has been
    // modeled as more similar to a DFF or SRAM to simplify phase 3. In
    // later phases, you will replace this with a more realistic memory.
    //
    // 32-bit read address for the instruction memory. This is expected to be
    // 4 byte aligned - that is, the two LSBs should be zero.
    output wire [31:0] o_imem_raddr,
    // Instruction word fetched from memory, available on the same cycle.
    input  wire [31:0] i_imem_rdata,
    // Data memory accesses go through a separate read/write data memory (dmem)
    // that is shared between read (load) and write (stored). The port accepts
    // a 32-bit address, read or write enable, and mask (explained below) each
    // cycle. Reads are combinational - values are available immediately after
    // updating the address and asserting read enable. Writes occur on (and
    // are visible at) the next clock edge.
    //
    // Read/write address for the data memory. This should be 32-bit aligned
    // (i.e. the two LSB should be zero). See `o_dmem_mask` for how to perform
    // half-word and byte accesses at unaligned addresses.
    output wire [31:0] o_dmem_addr,
    // When asserted, the memory will perform a read at the aligned address
    // specified by `i_addr` and return the 32-bit word at that address
    // immediately (i.e. combinationally). It is illegal to assert this and
    // `o_dmem_wen` on the same cycle.
    output wire        o_dmem_ren,
    // When asserted, the memory will perform a write to the aligned address
    // `o_dmem_addr`. When asserted, the memory will write the bytes in
    // `o_dmem_wdata` (specified by the mask) to memory at the specified
    // address on the next rising clock edge. It is illegal to assert this and
    // `o_dmem_ren` on the same cycle.
    output wire        o_dmem_wen,
    // The 32-bit word to write to memory when `o_dmem_wen` is asserted. When
    // write enable is asserted, the byte lanes specified by the mask will be
    // written to the memory word at the aligned address at the next rising
    // clock edge. The other byte lanes of the word will be unaffected.
    output wire [31:0] o_dmem_wdata,
    // The dmem interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    //
    // To perform a half-word read at address 0x00001002, align `o_dmem_addr`
    // to 0x00001000, assert `o_dmem_ren`, and set the mask to 0b1100 to
    // indicate that only the upper two bytes should be read. Only the upper
    // two bytes of `i_dmem_rdata` can be assumed to have valid data; to
    // calculate the final value of the `lh[u]` instruction, shift the rdata
    // word right by 16 bits and sign/zero extend as appropriate.
    //
    // To perform a byte write at address 0x00002003, align `o_dmem_addr` to
    // `0x00002003`, assert `o_dmem_wen`, and set the mask to 0b1000 to
    // indicate that only the upper byte should be written. On the next clock
    // cycle, the upper byte of `o_dmem_wdata` will be written to memory, with
    // the other three bytes of the aligned word unaffected. Remember to shift
    // the value of the `sb` instruction left by 24 bits to place it in the
    // appropriate byte lane.
    output wire [ 3:0] o_dmem_mask,
    // The 32-bit word read from data memory. When `o_dmem_ren` is asserted,
    // this will immediately reflect the contents of memory at the specified
    // address, for the bytes enabled by the mask. When read enable is not
    // asserted, or for bytes not set in the mask, the value is undefined.
    input  wire [31:0] i_dmem_rdata,
    // The output `retire` interface is used to signal to the testbench that
    // the CPU has completed and retired an instruction. A single cycle
    // implementation will assert this every cycle; however, a pipelined
    // implementation that needs to stall (due to internal hazards or waiting
    // on memory accesses) will not assert the signal on cycles where the
    // instruction in the writeback stage is not retiring.
    //
    // Asserted when an instruction is being retired this cycle. If this is
    // not asserted, the other retire signals are ignored and may be left invalid.
    output wire        o_retire_valid,
    // The 32 bit instruction word of the instrution being retired. This
    // should be the unmodified instruction word fetched from instruction
    // memory.
    output wire [31:0] o_retire_inst,
    // Asserted if the instruction produced a trap, due to an illegal
    // instruction, unaligned data memory access, or unaligned instruction
    // address on a taken branch or jump.
    output wire        o_retire_trap,
    // Asserted if the instruction is an `ebreak` instruction used to halt the
    // processor. This is used for debugging and testing purposes to end
    // a program.
    output wire        o_retire_halt,
    // The first register address read by the instruction being retired. If
    // the instruction does not read from a register (like `lui`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs1_raddr,
    // The second register address read by the instruction being retired. If
    // the instruction does not read from a second register (like `addi`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs2_raddr,
    // The first source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs1 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs1_rdata,
    // The second source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs2 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs2_rdata,
    // The destination register address written by the instruction being
    // retired. If the instruction does not write to a register (like `sw`),
    // this should be 5'd0.
    output wire [ 4:0] o_retire_rd_waddr,
    // The destination register data written to the register file in the
    // writeback stage by this instruction. If rd is 5'd0, this field is
    // ignored and can be treated as a don't care.
    output wire [31:0] o_retire_rd_wdata,
    output wire [31:0] o_retire_dmem_addr,
    output wire [ 3:0] o_retire_dmem_mask,
    output wire        o_retire_dmem_ren,
    output wire        o_retire_dmem_wen,
    output wire [31:0] o_retire_dmem_rdata,
    output wire [31:0] o_retire_dmem_wdata,
    // The current program counter of the instruction being retired - i.e.
    // the instruction memory address that the instruction was fetched from.
    output wire [31:0] o_retire_pc,
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    output wire [31:0] o_retire_next_pc

`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS
`endif
);

    // =========================================================================
    // Control & Opcodes Defines
    // =========================================================================
    localparam [6:0] OPCODE_R_TYPE = 7'b0110011;
    localparam [6:0] OPCODE_I_TYPE = 7'b0010011;
    localparam [6:0] OPCODE_LOAD   = 7'b0000011;
    localparam [6:0] OPCODE_STORE  = 7'b0100011;
    localparam [6:0] OPCODE_BRANCH = 7'b1100011;
    localparam [6:0] OPCODE_JALR   = 7'b1100111;
    localparam [6:0] OPCODE_JAL    = 7'b1101111;
    localparam [6:0] OPCODE_LUI    = 7'b0110111;
    localparam [6:0] OPCODE_AUIPC  = 7'b0010111;
    localparam [6:0] OPCODE_SYSTEM = 7'b1110011;

    localparam [3:0] ALU_ADD  = 4'd0;
    localparam [3:0] ALU_SUB  = 4'd1;
    localparam [3:0] ALU_SLL  = 4'd2;
    localparam [3:0] ALU_SLT  = 4'd3;
    localparam [3:0] ALU_SLTU = 4'd4;
    localparam [3:0] ALU_XOR  = 4'd5;
    localparam [3:0] ALU_SRL  = 4'd6;
    localparam [3:0] ALU_SRA  = 4'd7;
    localparam [3:0] ALU_OR   = 4'd8;
    localparam [3:0] ALU_AND  = 4'd9;

    // =========================================================================
    // Pipeline Control & Stall Signal Declarations
    // =========================================================================
    reg stall;
    reg flush_if_id;
    reg flush_id_ex;

    // =========================================================================
    // Register File Implementation
    // =========================================================================
    reg [31:0] rf [0:31];
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            rf[i] = 32'h00000000;
        end
    end

    // =========================================================================
    // Stage 1: Fetch (IF)
    // =========================================================================
    reg [31:0] pc_reg;
    wire [31:0] pc_next;
    
    // Jump / Branch redirection signals coming from EX stage
    wire        ex_branch_take;
    wire [31:0] ex_branch_target;

    assign pc_next = ex_branch_take ? ex_branch_target : (pc_reg + 32'd4);

    always @(posedge i_clk) begin
        if (i_rst) begin
            pc_reg <= RESET_ADDR;
        end else if (!stall) begin
            pc_reg <= pc_next;
        end
    end

    assign o_imem_raddr = pc_reg;

    // =========================================================================
    // IF / ID Pipeline Register
    // =========================================================================
    reg [31:0] if_id_pc;
    reg [31:0] if_id_inst;
    reg        if_id_valid;

    always @(posedge i_clk) begin
        if (i_rst || flush_if_id) begin
            if_id_pc    <= 32'h0;
            if_id_inst  <= 32'h00000013; // NOP (addi x0, x0, 0)
            if_id_valid <= 1'b0;
        end else if (!stall) begin
            if_id_pc    <= pc_reg;
            if_id_inst  <= i_imem_rdata;
            if_id_valid <= 1'b1;
        end
    end

    // =========================================================================
    // Stage 2: Instruction Decode (ID)
    // =========================================================================
    wire [31:0] id_inst = if_id_inst;
    wire [31:0] id_pc   = if_id_pc;

    wire [6:0] id_opcode = id_inst[6:0];
    wire [4:0] id_rd     = id_inst[11:7];
    wire [2:0] id_funct3 = id_inst[14:12];
    wire [4:0] id_rs1    = id_inst[19:15];
    wire [4:0] id_rs2    = id_inst[24:20];
    wire [6:0] id_funct7 = id_inst[31:25];

    // Source Register Read Decoders
    wire id_uses_rs1 = (id_opcode == OPCODE_R_TYPE)  ||
                       (id_opcode == OPCODE_I_TYPE)  ||
                       (id_opcode == OPCODE_LOAD)    ||
                       (id_opcode == OPCODE_STORE)   ||
                       (id_opcode == OPCODE_BRANCH)  ||
                       (id_opcode == OPCODE_JALR);

    wire id_uses_rs2 = (id_opcode == OPCODE_R_TYPE)  ||
                       (id_opcode == OPCODE_STORE)   ||
                       (id_opcode == OPCODE_BRANCH);

    wire [4:0] id_rs1_raddr = (id_uses_rs1 && if_id_valid) ? id_rs1 : 5'd0;
    wire [4:0] id_rs2_raddr = (id_uses_rs2 && if_id_valid) ? id_rs2 : 5'd0;

    // Immediate Decoder
    reg [31:0] id_imm;
    always @(*) begin
        case (id_opcode)
            OPCODE_I_TYPE, OPCODE_LOAD, OPCODE_JALR:
                id_imm = {{20{id_inst[31]}}, id_inst[31:20]};
            OPCODE_STORE:
                id_imm = {{20{id_inst[31]}}, id_inst[31:25], id_inst[11:7]};
            OPCODE_BRANCH:
                id_imm = {{20{id_inst[31]}}, id_inst[7], id_inst[30:25], id_inst[11:8], 1'b0};
            OPCODE_LUI, OPCODE_AUIPC:
                id_imm = {id_inst[31:12], 12'b0};
            OPCODE_JAL:
                id_imm = {{12{id_inst[31]}}, id_inst[19:12], id_inst[20], id_inst[30:21], 1'b0};
            default:
                id_imm = 32'b0;
        endcase
    end

    // Register File Read Logic with Register File Bypassing (WB -> ID)
    reg [31:0] id_wb_rf_wdata;
    reg [4:0]  mem_wb_rd_waddr;
    reg        mem_wb_reg_write;

    wire [31:0] rf_rs1_data = (id_rs1_raddr == 5'd0) ? 32'd0 : rf[id_rs1_raddr];
    wire [31:0] rf_rs2_data = (id_rs2_raddr == 5'd0) ? 32'd0 : rf[id_rs2_raddr];

    wire [31:0] id_rs1_rdata = (BYPASS_EN && mem_wb_reg_write && (mem_wb_rd_waddr != 5'd0) && (mem_wb_rd_waddr == id_rs1_raddr)) ?
                               id_wb_rf_wdata : rf_rs1_data;
    wire [31:0] id_rs2_rdata = (BYPASS_EN && mem_wb_reg_write && (mem_wb_rd_waddr != 5'd0) && (mem_wb_rd_waddr == id_rs2_raddr)) ?
                               id_wb_rf_wdata : rf_rs2_data;

    // Control Decoding
    reg       id_reg_write;
    reg       id_mem_ren;
    reg       id_mem_wen;
    reg [3:0] id_alu_op;
    reg       id_alu_src_b; // 0: rs2, 1: immediate
    reg       id_is_branch;
    reg       id_is_jal;
    reg       id_is_jalr;
    reg       id_illegal_inst;
    reg       id_ebreak;

    always @(*) begin
        id_reg_write    = 1'b0;
        id_mem_ren      = 1'b0;
        id_mem_wen      = 1'b0;
        id_alu_op       = ALU_ADD;
        id_alu_src_b    = 1'b0;
        id_is_branch    = 1'b0;
        id_is_jal       = 1'b0;
        id_is_jalr      = 1'b0;
        id_illegal_inst = 1'b0;
        id_ebreak       = 1'b0;

        if (if_id_valid) begin
            case (id_opcode)
                OPCODE_R_TYPE: begin
                    id_reg_write = 1'b1;
                    case (id_funct3)
                        3'b000: id_alu_op = (id_funct7[5]) ? ALU_SUB : ALU_ADD;
                        3'b001: id_alu_op = ALU_SLL;
                        3'b010: id_alu_op = ALU_SLT;
                        3'b011: id_alu_op = ALU_SLTU;
                        3'b100: id_alu_op = ALU_XOR;
                        3'b101: id_alu_op = (id_funct7[5]) ? ALU_SRA : ALU_SRL;
                        3'b110: id_alu_op = ALU_OR;
                        3'b111: id_alu_op = ALU_AND;
                    endcase
                end
                OPCODE_I_TYPE: begin
                    id_reg_write = 1'b1;
                    id_alu_src_b = 1'b1;
                    case (id_funct3)
                        3'b000: id_alu_op = ALU_ADD;
                        3'b001: id_alu_op = ALU_SLL;
                        3'b010: id_alu_op = ALU_SLT;
                        3'b011: id_alu_op = ALU_SLTU;
                        3'b100: id_alu_op = ALU_XOR;
                        3'b101: id_alu_op = (id_funct7[5]) ? ALU_SRA : ALU_SRL;
                        3'b110: id_alu_op = ALU_OR;
                        3'b111: id_alu_op = ALU_AND;
                    endcase
                end
                OPCODE_LOAD: begin
                    id_reg_write = 1'b1;
                    id_alu_src_b = 1'b1;
                    id_mem_ren   = 1'b1;
                    id_alu_op    = ALU_ADD;
                end
                OPCODE_STORE: begin
                    id_alu_src_b = 1'b1;
                    id_mem_wen   = 1'b1;
                    id_alu_op    = ALU_ADD;
                end
                OPCODE_BRANCH: begin
                    id_is_branch = 1'b1;
                end
                OPCODE_JAL: begin
                    id_reg_write = 1'b1;
                    id_is_jal    = 1'b1;
                end
                OPCODE_JALR: begin
                    id_reg_write = 1'b1;
                    id_alu_src_b = 1'b1;
                    id_is_jalr   = 1'b1;
                    id_alu_op    = ALU_ADD;
                end
                OPCODE_LUI, OPCODE_AUIPC: begin
                    id_reg_write = 1'b1;
                    id_alu_src_b = 1'b1;
                    id_alu_op    = ALU_ADD;
                end
                OPCODE_SYSTEM: begin
                    if (id_inst[31:7] == 25'b000000000001_00000_000_00000) begin
                        id_ebreak = 1'b1;
                    end else begin
                        id_illegal_inst = 1'b1;
                    end
                end
                default: id_illegal_inst = 1'b1;
            endcase
        end
    end

    wire [4:0] id_rd_waddr = (id_reg_write && if_id_valid) ? id_rd : 5'd0;

    // =========================================================================
    // ID / EX Pipeline Register
    // =========================================================================
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_inst;
    reg        id_ex_valid;
    reg [4:0]  id_ex_rs1_raddr;
    reg [4:0]  id_ex_rs2_raddr;
    reg [31:0] id_ex_rs1_rdata;
    reg [31:0] id_ex_rs2_rdata;
    reg [4:0]  id_ex_rd_waddr;
    reg [31:0] id_ex_imm;
    reg [2:0]  id_ex_funct3;
    reg        id_ex_reg_write;
    reg        id_ex_mem_ren;
    reg        id_ex_mem_wen;
    reg [3:0]  id_ex_alu_op;
    reg        id_ex_alu_src_b;
    reg        id_ex_is_branch;
    reg        id_ex_is_jal;
    reg        id_ex_is_jalr;
    reg        id_ex_illegal_inst;
    reg        id_ex_ebreak;

    always @(posedge i_clk) begin
        if (i_rst || flush_id_ex) begin
            id_ex_pc           <= 32'h0;
            id_ex_inst         <= 32'h00000013;
            id_ex_valid        <= 1'b0;
            id_ex_rs1_raddr    <= 5'd0;
            id_ex_rs2_raddr    <= 5'd0;
            id_ex_rs1_rdata    <= 32'd0;
            id_ex_rs2_rdata    <= 32'd0;
            id_ex_rd_waddr     <= 5'd0;
            id_ex_imm          <= 32'd0;
            id_ex_funct3       <= 3'd0;
            id_ex_reg_write    <= 1'b0;
            id_ex_mem_ren      <= 1'b0;
            id_ex_mem_wen      <= 1'b0;
            id_ex_alu_op       <= ALU_ADD;
            id_ex_alu_src_b    <= 1'b0;
            id_ex_is_branch    <= 1'b0;
            id_ex_is_jal       <= 1'b0;
            id_ex_is_jalr      <= 1'b0;
            id_ex_illegal_inst <= 1'b0;
            id_ex_ebreak       <= 1'b0;
        end else if (stall) begin
            id_ex_pc           <= 32'h0;
            id_ex_inst         <= 32'h00000013;
            id_ex_valid        <= 1'b0;
            id_ex_rs1_raddr    <= 5'd0;
            id_ex_rs2_raddr    <= 5'd0;
            id_ex_rs1_rdata    <= 32'd0;
            id_ex_rs2_rdata    <= 32'd0;
            id_ex_rd_waddr     <= 5'd0;
            id_ex_imm          <= 32'd0;
            id_ex_funct3       <= 3'd0;
            id_ex_reg_write    <= 1'b0;
            id_ex_mem_ren      <= 1'b0;
            id_ex_mem_wen      <= 1'b0;
            id_ex_alu_op       <= ALU_ADD;
            id_ex_alu_src_b    <= 1'b0;
            id_ex_is_branch    <= 1'b0;
            id_ex_is_jal       <= 1'b0;
            id_ex_is_jalr      <= 1'b0;
            id_ex_illegal_inst <= 1'b0;
            id_ex_ebreak       <= 1'b0;
        end else begin
            id_ex_pc           <= id_pc;
            id_ex_inst         <= id_inst;
            id_ex_valid        <= if_id_valid;
            id_ex_rs1_raddr    <= id_rs1_raddr;
            id_ex_rs2_raddr    <= id_rs2_raddr;
            id_ex_rs1_rdata    <= id_rs1_rdata;
            id_ex_rs2_rdata    <= id_rs2_rdata;
            id_ex_rd_waddr     <= id_rd_waddr;
            id_ex_imm          <= id_imm;
            id_ex_funct3       <= id_funct3;
            id_ex_reg_write    <= id_reg_write;
            id_ex_mem_ren      <= id_mem_ren;
            id_ex_mem_wen      <= id_mem_wen;
            id_ex_alu_op       <= id_alu_op;
            id_ex_alu_src_b    <= id_alu_src_b;
            id_ex_is_branch    <= id_is_branch;
            id_ex_is_jal       <= id_is_jal;
            id_ex_is_jalr      <= id_is_jalr;
            id_ex_illegal_inst <= id_illegal_inst;
            id_ex_ebreak       <= id_ebreak;
        end
    end

    // =========================================================================
    // Stage 3: Execute (EX)
    // =========================================================================
    reg [4:0]  ex_mem_rd_waddr;
    reg        ex_mem_reg_write;
    reg [31:0] ex_mem_alu_res;

    // Forwarding Unit
    reg [31:0] ex_operand_a;
    reg [31:0] ex_operand_b_forwarded;

    always @(*) begin
        // Forwarding for RS1
        if (FWD_EN && ex_mem_reg_write && (ex_mem_rd_waddr != 5'd0) && (ex_mem_rd_waddr == id_ex_rs1_raddr)) begin
            ex_operand_a = ex_mem_alu_res;
        end else if (FWD_EN && mem_wb_reg_write && (mem_wb_rd_waddr != 5'd0) && (mem_wb_rd_waddr == id_ex_rs1_raddr)) begin
            ex_operand_a = id_wb_rf_wdata;
        end else begin
            ex_operand_a = id_ex_rs1_rdata;
        end

        // Forwarding for RS2
        if (FWD_EN && ex_mem_reg_write && (ex_mem_rd_waddr != 5'd0) && (ex_mem_rd_waddr == id_ex_rs2_raddr)) begin
            ex_operand_b_forwarded = ex_mem_alu_res;
        end else if (FWD_EN && mem_wb_reg_write && (mem_wb_rd_waddr != 5'd0) && (mem_wb_rd_waddr == id_ex_rs2_raddr)) begin
            ex_operand_b_forwarded = id_wb_rf_wdata;
        end else begin
            ex_operand_b_forwarded = id_ex_rs2_rdata;
        end
    end

    // Select ALU B input
    wire [31:0] ex_operand_b = (id_ex_inst[6:0] == OPCODE_LUI)   ? id_ex_imm :
                               (id_ex_inst[6:0] == OPCODE_AUIPC) ? id_ex_imm :
                               id_ex_alu_src_b ? id_ex_imm : ex_operand_b_forwarded;

    wire [31:0] ex_alu_a = (id_ex_inst[6:0] == OPCODE_AUIPC) ? id_ex_pc : ex_operand_a;

    // ALU Calculation
    reg [31:0] ex_alu_res;
    always @(*) begin
        case (id_ex_alu_op)
            ALU_ADD:  ex_alu_res = ex_alu_a + ex_operand_b;
            ALU_SUB:  ex_alu_res = ex_alu_a - ex_operand_b;
            ALU_SLL:  ex_alu_res = ex_alu_a << ex_operand_b[4:0];
            ALU_SLT:  ex_alu_res = ($signed(ex_alu_a) <$signed(ex_operand_b)) ? 32'd1 : 32'd0;
            ALU_SLTU: ex_alu_res = (ex_alu_a < ex_operand_b) ? 32'd1 : 32'd0;
            ALU_XOR:  ex_alu_res = ex_alu_a ^ ex_operand_b;
            ALU_SRL:  ex_alu_res = ex_alu_a >> ex_operand_b[4:0];
            ALU_SRA:  ex_alu_res = $signed(ex_alu_a) >>> ex_operand_b[4:0];
            ALU_OR:   ex_alu_res = ex_alu_a | ex_operand_b;
            ALU_AND:  ex_alu_res = ex_alu_a & ex_operand_b;
            default:  ex_alu_res = 32'd0;
        endcase
    end

    // Branch Resolution
    reg ex_branch_condition;
    always @(*) begin
        case (id_ex_funct3)
            3'b000: ex_branch_condition = (ex_operand_a == ex_operand_b_forwarded);
            3'b001: ex_branch_condition = (ex_operand_a != ex_operand_b_forwarded);
            3'b100: ex_branch_condition = ($signed(ex_operand_a) <$signed(ex_operand_b_forwarded));
            3'b101: ex_branch_condition = ($signed(ex_operand_a) >=$signed(ex_operand_b_forwarded));
            3'b110: ex_branch_condition = (ex_operand_a < ex_operand_b_forwarded);
            3'b111: ex_branch_condition = (ex_operand_a >= ex_operand_b_forwarded);
            default: ex_branch_condition = 1'b0;
        endcase
    end

    assign ex_branch_take   = id_ex_valid && ((id_ex_is_branch && ex_branch_condition) || id_ex_is_jal || id_ex_is_jalr);
    
    wire [31:0] jalr_target = (ex_operand_a + id_ex_imm) & ~32'd1;
    assign ex_branch_target = id_ex_is_jalr ? jalr_target : (id_ex_pc + id_ex_imm);

    wire ex_inst_addr_misaligned = ex_branch_take && (ex_branch_target[1:0] != 2'b00);

    // Hazard Control Signals Logic
    always @(*) begin
        stall       = 1'b0;
        flush_if_id = 1'b0;
        flush_id_ex = 1'b0;

        // Load-use hazard detection
        if (id_ex_valid && id_ex_mem_ren && (id_ex_rd_waddr != 5'd0)) begin
            if ((id_rs1_raddr == id_ex_rd_waddr) || (id_rs2_raddr == id_ex_rd_waddr)) begin
                stall = 1'b1;
            end
        end

        // Pipeline Stalls when forwarding is disabled
        if (!FWD_EN) begin
            if (id_ex_valid && (id_ex_rd_waddr != 5'd0) && id_ex_reg_write) begin
                if ((id_rs1_raddr == id_ex_rd_waddr) || (id_rs2_raddr == id_ex_rd_waddr)) stall = 1'b1;
            end
            if (ex_mem_reg_write && (ex_mem_rd_waddr != 5'd0)) begin
                if ((id_rs1_raddr == ex_mem_rd_waddr) || (id_rs2_raddr == ex_mem_rd_waddr)) stall = 1'b1;
            end
        end

        // Control hazard flushes
        if (ex_branch_take) begin
            flush_if_id = 1'b1;
            flush_id_ex = 1'b1;
        end
    end

    // Final result calculation in EX stage
    wire [31:0] ex_final_res = (id_ex_is_jal || id_ex_is_jalr) ? (id_ex_pc + 32'd4) : ex_alu_res;

    // =========================================================================
    // EX / MEM Pipeline Register
    // =========================================================================
    reg [31:0] ex_mem_pc;
    reg [31:0] ex_mem_inst;
    reg        ex_mem_valid;
    reg [4:0]  ex_mem_rs1_raddr;
    reg [4:0]  ex_mem_rs2_raddr;
    reg [31:0] ex_mem_rs1_rdata;
    reg [31:0] ex_mem_rs2_rdata;
    reg [31:0] ex_mem_rs2_forwarded;
    reg [31:0] ex_mem_imm;
    reg [2:0]  ex_mem_funct3;
    reg        ex_mem_mem_ren;
    reg        ex_mem_mem_wen;
    reg        ex_mem_illegal_inst;
    reg        ex_mem_inst_misaligned;
    reg        ex_mem_ebreak;
    reg [31:0] ex_mem_next_pc;

    always @(posedge i_clk) begin
        if (i_rst) begin
            ex_mem_pc              <= 32'h0;
            ex_mem_inst            <= 32'h00000013;
            ex_mem_valid           <= 1'b0;
            ex_mem_rs1_raddr       <= 5'd0;
            ex_mem_rs2_raddr       <= 5'd0;
            ex_mem_rs1_rdata       <= 32'd0;
            ex_mem_rs2_rdata       <= 32'd0;
            ex_mem_rs2_forwarded   <= 32'd0;
            ex_mem_rd_waddr        <= 5'd0;
            ex_mem_imm             <= 32'd0;
            ex_mem_funct3          <= 3'd0;
            ex_mem_reg_write       <= 1'b0;
            ex_mem_mem_ren         <= 1'b0;
            ex_mem_mem_wen         <= 1'b0;
            ex_mem_alu_res         <= 32'd0;
            ex_mem_illegal_inst    <= 1'b0;
            ex_mem_inst_misaligned <= 1'b0;
            ex_mem_ebreak          <= 1'b0;
            ex_mem_next_pc         <= 32'd0;
        end else begin
            ex_mem_pc              <= id_ex_pc;
            ex_mem_inst            <= id_ex_inst;
            ex_mem_valid           <= id_ex_valid;
            ex_mem_rs1_raddr       <= id_ex_rs1_raddr;
            ex_mem_rs2_raddr       <= id_ex_rs2_raddr;
            ex_mem_rs1_rdata       <= id_ex_rs1_rdata;
            ex_mem_rs2_rdata       <= id_ex_rs2_rdata;
            ex_mem_rs2_forwarded   <= ex_operand_b_forwarded;
            ex_mem_rd_waddr        <= id_ex_rd_waddr;
            ex_mem_imm             <= id_ex_imm;
            ex_mem_funct3          <= id_ex_funct3;
            ex_mem_reg_write       <= id_ex_reg_write;
            ex_mem_mem_ren         <= id_ex_mem_ren;
            ex_mem_mem_wen         <= id_ex_mem_wen;
            ex_mem_alu_res         <= ex_final_res;
            ex_mem_illegal_inst    <= id_ex_illegal_inst;
            ex_mem_inst_misaligned <= ex_inst_addr_misaligned;
            ex_mem_ebreak          <= id_ex_ebreak;
            ex_mem_next_pc         <= ex_branch_take ? ex_branch_target : (id_ex_pc + 32'd4);
        end
    end

    // =========================================================================
    // Stage 4: Memory Access (MEM)
    // =========================================================================
    wire [31:0] mem_addr_raw = ex_mem_alu_res;
    assign o_dmem_addr = {mem_addr_raw[31:2], 2'b00};

    // Unaligned Memory Access Detection
    reg mem_data_misaligned;
    always @(*) begin
        mem_data_misaligned = 1'b0;
        if (ex_mem_valid && (ex_mem_mem_ren || ex_mem_mem_wen)) begin
            case (ex_mem_funct3[1:0])
                2'b01: if (mem_addr_raw[0] != 1'b0) mem_data_misaligned = 1'b1; // Half-word alignment
                2'b10: if (mem_addr_raw[1:0] != 2'b00) mem_data_misaligned = 1'b1; // Word alignment
                default: mem_data_misaligned = 1'b0;
            endcase
        end
    end

    assign o_dmem_ren = ex_mem_valid && ex_mem_mem_ren && !mem_data_misaligned;
    assign o_dmem_wen = ex_mem_valid && ex_mem_mem_wen && !mem_data_misaligned;

    // Byte Enable Mask Generation
    reg [3:0] mem_mask;
    always @(*) begin
        case (ex_mem_funct3[1:0])
            2'b00: mem_mask = 4'b0001 << mem_addr_raw[1:0];      // Byte
            2'b01: mem_mask = 4'b0011 << {mem_addr_raw[1], 1'b0}; // Half-word
            2'b10: mem_mask = 4'b1111;                            // Word
            default: mem_mask = 4'b0000;
        endcase
    end

    assign o_dmem_mask = (o_dmem_ren || o_dmem_wen) ? mem_mask : 4'b0000;

    // Store Data Alignment Logic
    reg [31:0] mem_wdata_aligned;
    always @(*) begin
        case (ex_mem_funct3[1:0])
            2'b00: mem_wdata_aligned = ex_mem_rs2_forwarded << (mem_addr_raw[1:0] * 8);
            2'b01: mem_wdata_aligned = ex_mem_rs2_forwarded << (mem_addr_raw[1] * 16);
            default: mem_wdata_aligned = ex_mem_rs2_forwarded;
        endcase
    end

    assign o_dmem_wdata = mem_wdata_aligned;

    // Load Data Extraction and Extension Logic
    reg [31:0] mem_rdata_processed;
    wire [31:0] shifted_rdata = i_dmem_rdata >> (mem_addr_raw[1:0] * 8);

    always @(*) begin
        case (ex_mem_funct3)
            3'b000: mem_rdata_processed = {{24{shifted_rdata[7]}}, shifted_rdata[7:0]};   // LB
            3'b001: mem_rdata_processed = {{16{shifted_rdata[15]}}, shifted_rdata[15:0]}; // LH
            3'b010: mem_rdata_processed = i_dmem_rdata;                                   // LW
            3'b100: mem_rdata_processed = {24'b0, shifted_rdata[7:0]};                   // LBU
            3'b101: mem_rdata_processed = {16'b0, shifted_rdata[15:0]};                  // LHU
            default: mem_rdata_processed = 32'b0;
        endcase
    end

    // =========================================================================
    // MEM / WB Pipeline Register
    // =========================================================================
    reg [31:0] mem_wb_pc;
    reg [31:0] mem_wb_inst;
    reg        mem_wb_valid;
    reg [4:0]  mem_wb_rs1_raddr;
    reg [4:0]  mem_wb_rs2_raddr;
    reg [31:0] mem_wb_rs1_rdata;
    reg [31:0] mem_wb_rs2_rdata;
    reg [31:0] mem_wb_alu_res;
    reg [31:0] mem_wb_rdata;
    reg        mem_wb_mem_ren;
    reg        mem_wb_mem_wen;
    reg [31:0] mem_wb_dmem_addr;
    reg [3:0]  mem_wb_dmem_mask;
    reg [31:0] mem_wb_dmem_wdata;
    reg        mem_wb_illegal_inst;
    reg        mem_wb_inst_misaligned;
    reg        mem_wb_data_misaligned;
    reg        mem_wb_ebreak;
    reg [31:0] mem_wb_next_pc;

    always @(posedge i_clk) begin
        if (i_rst) begin
            mem_wb_pc              <= 32'h0;
            mem_wb_inst            <= 32'h00000013;
            mem_wb_valid           <= 1'b0;
            mem_wb_rs1_raddr       <= 5'd0;
            mem_wb_rs2_raddr       <= 5'd0;
            mem_wb_rs1_rdata       <= 32'd0;
            mem_wb_rs2_rdata       <= 32'd0;
            mem_wb_rd_waddr        <= 5'd0;
            mem_wb_reg_write       <= 1'b0;
            mem_wb_alu_res         <= 32'd0;
            mem_wb_rdata           <= 32'd0;
            mem_wb_mem_ren         <= 1'b0;
            mem_wb_mem_wen         <= 1'b0;
            mem_wb_dmem_addr       <= 32'd0;
            mem_wb_dmem_mask       <= 4'd0;
            mem_wb_dmem_wdata      <= 32'd0;
            mem_wb_illegal_inst    <= 1'b0;
            mem_wb_inst_misaligned <= 1'b0;
            mem_wb_data_misaligned <= 1'b0;
            mem_wb_ebreak          <= 1'b0;
            mem_wb_next_pc         <= 32'd0;
        end else begin
            mem_wb_pc              <= ex_mem_pc;
            mem_wb_inst            <= ex_mem_inst;
            mem_wb_valid           <= ex_mem_valid;
            mem_wb_rs1_raddr       <= ex_mem_rs1_raddr;
            mem_wb_rs2_raddr       <= ex_mem_rs2_raddr;
            mem_wb_rs1_rdata       <= ex_mem_rs1_rdata;
            mem_wb_rs2_rdata       <= ex_mem_rs2_rdata;
            mem_wb_rd_waddr        <= ex_mem_rd_waddr;
            mem_wb_reg_write       <= ex_mem_reg_write;
            mem_wb_alu_res         <= ex_mem_alu_res;
            mem_wb_rdata           <= mem_rdata_processed;
            mem_wb_mem_ren         <= o_dmem_ren;
            mem_wb_mem_wen         <= o_dmem_wen;
            mem_wb_dmem_addr       <= o_dmem_addr;
            mem_wb_dmem_mask       <= o_dmem_mask;
            mem_wb_dmem_wdata      <= o_dmem_wdata;
            mem_wb_illegal_inst    <= ex_mem_illegal_inst;
            mem_wb_inst_misaligned <= ex_mem_inst_misaligned;
            mem_wb_data_misaligned <= mem_data_misaligned;
            mem_wb_ebreak          <= ex_mem_ebreak;
            mem_wb_next_pc         <= ex_mem_next_pc;
        end
    end

    // =========================================================================
    // Stage 5: Writeback (WB)
    // =========================================================================
    always @(*) begin
        if (mem_wb_mem_ren) begin
            id_wb_rf_wdata = mem_wb_rdata;
        end else begin
            id_wb_rf_wdata = mem_wb_alu_res;
        end
    end

    always @(posedge i_clk) begin
        if (!i_rst && mem_wb_valid && mem_wb_reg_write && (mem_wb_rd_waddr != 5'd0)) begin
            rf[mem_wb_rd_waddr] <= id_wb_rf_wdata;
        end
    end

    // =========================================================================
    // Core Retirement Interface Assignments
    // =========================================================================
    assign o_retire_valid      = mem_wb_valid;
    assign o_retire_inst       = mem_wb_inst;
    assign o_retire_trap       = mem_wb_valid && (mem_wb_illegal_inst || mem_wb_inst_misaligned || mem_wb_data_misaligned);
    assign o_retire_halt       = mem_wb_valid && mem_wb_ebreak;
    assign o_retire_rs1_raddr  = mem_wb_rs1_raddr;
    assign o_retire_rs2_raddr  = mem_wb_rs2_raddr;
    assign o_retire_rs1_rdata  = mem_wb_rs1_rdata;
    assign o_retire_rs2_rdata  = mem_wb_rs2_rdata;
    assign o_retire_rd_waddr   = mem_wb_rd_waddr;
    assign o_retire_rd_wdata   = (mem_wb_rd_waddr != 5'd0) ? id_wb_rf_wdata : 32'd0;
    assign o_retire_dmem_addr  = mem_wb_dmem_addr;
    assign o_retire_dmem_mask  = mem_wb_dmem_mask;
    assign o_retire_dmem_ren   = mem_wb_mem_ren;
    assign o_retire_dmem_wen   = mem_wb_mem_wen;
    assign o_retire_dmem_rdata = mem_wb_rdata;
    assign o_retire_dmem_wdata = mem_wb_dmem_wdata;
    assign o_retire_pc         = mem_wb_pc;
    assign o_retire_next_pc    = mem_wb_next_pc;

endmodule