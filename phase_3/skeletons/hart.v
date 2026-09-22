`default_nettype none

// A hart ("hardware thread") is one complete RISC-V CPU: it fetches an
// instruction, decodes it, executes it, and writes the result back. This one
// is single-cycle, so all four of those happen in the same clock cycle and
// exactly one instruction retires every cycle -- there are no bubbles and no
// pipeline stages.
//
// You do not write the datapath blocks again here. Instantiate the four
// modules from phase 2 (`alu`, `rf`, `decoder`, which itself contains `imm`)
// and wire them together, then add the parts phase 2 did not have: the
// program counter, the branch/jump target logic, and the memory interfaces.
//
// Remember the two small changes phase 3 needs from your phase 2 modules:
// `rf` is instantiated with BYPASS_EN = 0 (a single-cycle design writes back
// on the same edge the next read samples, so there is nothing to bypass),
// and `rf` no longer has a write enable -- gate a write by driving its write
// address to 5'd0 instead. Do not instantiate a second copy of `imm`; your
// `decoder` already contains one.
module hart #(
    // The address the program counter is initialized to on reset. The first
    // instruction to retire after `i_rst` deasserts must be the one fetched
    // from this address.
    parameter RESET_ADDR = 32'h00000000
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,

    // ---- Instruction memory ------------------------------------------
    // The instruction memory is external to your design, read-only, and
    // combinational: the word at `o_imem_raddr` appears on `i_imem_rdata`
    // in the same cycle, with no clock edge and no latency.
    //
    // Address of the instruction to fetch. One instruction per cycle,
    // always 4-byte aligned.
    output wire [31:0] o_imem_raddr,
    // The instruction word stored at `o_imem_raddr`.
    input  wire [31:0] i_imem_rdata,

    // ---- Data memory -------------------------------------------------
    // The data memory is also external and combinational: reads need no
    // clock edge, and writes commit on the next clock edge.
    //
    // Data address. This is **always word-aligned** -- the low two bits of
    // the computed byte address never reach memory. Which bytes inside that
    // word are touched is `o_dmem_mask`'s job, not the address's.
    output wire [31:0] o_dmem_addr,
    // Read enable. Must never be high in the same cycle as `o_dmem_wen`.
    output wire        o_dmem_ren,
    // Write enable.
    output wire        o_dmem_wen,
    // Store data. Only the byte lanes selected by `o_dmem_mask` are used;
    // the rest are ignored, so they may hold anything. For a sub-word store
    // (`sb`, `sh`), the byte(s) must be positioned in the lane(s) they are
    // being written to, not left at the bottom of the word.
    output wire [31:0] o_dmem_wdata,
    // Which of the four byte lanes of the word at `o_dmem_addr` are read or
    // written. A byte access asserts one lane, a half-word two adjacent
    // lanes, and a word all four.
    output wire [ 3:0] o_dmem_mask,
    // The full 32-bit word at `o_dmem_addr`, regardless of the mask.
    // Extracting the requested bytes and sign- or zero-extending them
    // (`lb`/`lh` vs `lbu`/`lhu`) is this module's job.
    input  wire [31:0] i_dmem_rdata,

    // ---- Retire interface --------------------------------------------
    // These outputs are not part of RV32I. They exist so a testbench can see
    // what your design actually did each cycle. Drive every one of them
    // appropriately on every cycle; all of them are checked on every
    // retiring instruction.
    //
    // An instruction retired this cycle. Because the design is
    // single-cycle, this is high every cycle after `i_rst` deasserts,
    // through the cycle `o_retire_halt` fires.
    output wire        o_retire_valid,
    // The raw instruction word that was fetched and retired this cycle.
    output wire [31:0] o_retire_inst,
    // The instruction was an illegal encoding, or a misaligned data access
    // (a half-word access at an odd address, or a word access at an address
    // that is not a multiple of four -- a byte access is never misaligned).
    // A trapping instruction has no side effects: no memory access happens,
    // `o_retire_rd_waddr` is 5'd0, and control flow is not redirected
    // (there is no trap vector in this interface, so `o_retire_next_pc` is
    // still the pc plus four).
    output wire        o_retire_trap,
    // The instruction is `ebreak`, and execution should halt. Like a trap,
    // it reads nothing, writes nothing, and touches no memory.
    output wire        o_retire_halt,
    // First source register address, and the value read from it.
    // Instructions that do not read a first source register (`lui`,
    // `auipc`, `jal`, and illegal encodings) must report 5'd0 here.
    output wire [ 4:0] o_retire_rs1_raddr,
    output wire [31:0] o_retire_rs1_rdata,
    // Second source register address, and the value read from it. Only
    // R-type, store and branch instructions read a second source register;
    // everything else must report 5'd0 here.
    output wire [ 4:0] o_retire_rs2_raddr,
    output wire [31:0] o_retire_rs2_rdata,
    // Destination register address, and the value written to it. When the
    // instruction writes no register, this address must be 5'd0 -- the same
    // convention the decoder used in phase 2, and what discards the write
    // in the register file. The address is checked on every instruction,
    // including trapping ones; the data only matters when the address is
    // nonzero.
    output wire [ 4:0] o_retire_rd_waddr,
    output wire [31:0] o_retire_rd_wdata,
    // The address this instruction was fetched from.
    output wire [31:0] o_retire_pc,
    // The address the next instruction will be fetched from: the pc plus
    // four, or the branch or jump target when a branch is taken or a jump
    // is executed. This is what proves your branch targets, `jal`/`jalr`
    // targets, and `jalr`'s cleared low bit are right.
    output wire [31:0] o_retire_next_pc
);
    // Your implementation goes under here
    // ------------------------------------

//PC Register and fetching
reg [31:0] pc; // program counter
wire [31:0] pc_plus4 = pc + 32'd4;
assign o_imem_raddr = pc; // instruction memory address

always @(posedge i_clk) begin
    if (i_rst) begin
        pc <= RESET_ADDR; // reset pc to reset address
    end else begin
        pc <= pc_next; // update pc to next instruction address
    end

//Decode and Register Read
wire [31:0] inst = i_imem_rdata; // fetched instruction
wire is_break = (inst == 32'h00100073); // check for ebreak instruction

decoder decoder_inst (
    .i_inst(inst),
    .o_format(),
    .o_opcode(),
    .o_funct3(),
    .o_funct7(),
    .o_rs1_raddr(o_retire_rs1_raddr),
    .o_rs2_raddr(o_retire_rs2_raddr),
    .o_rd_waddr(o_retire_rd_waddr)
);

wire[4:0] rd_waddr = (reg_write && !will_trap && !is_ebreak) ? rd_addr_raw : 5'd0;

rf #(.BYPASS_EN(0)) rf_inst (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_rs1_raddr(rs1_raddr),
    .o_rs1_rdata(rs1_rdata),
    .i_rs2_raddr(rs2_raddr),
    .o_rs2_rdata(rs2_rdata),
    .i_rd_wen(reg_write && !will_trap && !is_ebreak),
    .i_rd_waddr(rd_waddr),
    .i_rd_wdata(rd_wdata)
);

//ALU Operand MUX
wire [31:0] alu_operand1 = is_auipc ? pc : is_lui ? 32'b0 : : rs1_rdata;
wire [31:0] alu_operand2 = (alu_src) ? imm : rs2_rdata;\

alu u_alu (
    .i_operand1(alu_operand1),
    .i_operand2(alu_operand2),
    .i_alu_op(alu_op),
    .o_result(alu_result)
);

//Branch/ Jump Targets
wire [31:0] pc_plus_imm = pc + imm; // calculate branch/jump target
wire [31:0] jalr_target = {alu_result[31:1], 1'b0}; // calculate jalr target

wire branch_cond = (funct3 == 3'b000) ? alu_eq
                    : (funct3 == 3'b001) ? ~alu_eq
                    : (funct3 == 3'b100) ? alu_slt
                    : (funct3 == 3'b101) ? ~alu_slt
                    : (funct3 == 3'b110) ? alu_sltu
                    : (funct3 == 3'b111) ? ~alu_sltu
                    : 1'b0;

wire branch_taken = is_branch && branch_cond;

wire [31:0] pc_next = (is_jal || branch_taken) ? pc_plus_imm
                    : (is_jalr) ? jalr_target
                    : pc_plus4;
                    
//Data Memory
wire [31:0] mem_byte_addr = alu_result; // memory address from ALU result
wire [1:0] mem_width = funct3[1:0]; // memory access width from funct3
wire [1:0] addr_lsbs = mem_byte_addr[1:0]; // least significant bits of address for alignment

wire misaligned = (mem_read || mem_write) && ((mem_width == 2'b01 && addr_lsbs[0]) || (mem_width == 2'b10 && addr_lsbs != 0));
assign will_trap = misaligned || illegal_inst;

reg [3:0] width_mask;
always @(*) begin
    case (mem_width)
        2'b00: width_mask = 4'b0001; // byte
        2'b01: width_mask = 4'b0011; // half-word
        2'b10: width_mask = 4'b1111; // word
        default: width_mask = 4'b0000; // invalid
    endcase //mem_width
end //begin

reg [3:0] mask_c;
always @(*) begin
    case (addr_lsbs)
        2'b00: mask_c = width_mask;
        2'b01: mask_c = {width_mask[2:0], 1'b0};
        2'b10: mask_c = {width_mask[1:0], 2'b00};
        2'b11: mask_c = {width_mask[0], 3'b000};
        default: mask_c = 4'b0000;
    endcase //addr_lsbs
end //begin

reg [31:0] wdata_c;
always @(*) begin
    case (addr_lsbs)
        2'b00: wdata_c = rs2_rdata;
        2'b01: wdata_c = rs2_data << 8;
        2'b10: wdata_c = rs2_data << 16;
        2'b11: wdata_c = rs2_data << 24;
        default: wdata_c = 32'b0;
    endcase //addr_lsbs
end //begin

reg [31:0] load_raw;
always @(*) begin
    case (addr_lsbs)
        2'b00: load_raw = i_dmem_rdata;
        2'b01: load_raw = i_dmem_rdata >> 8;
        2'b10: load_raw = i_dmem_rdata >> 16;
        2'b11: load_raw = i_dmem_rdata >> 24;
        default: load_raw = 32'b0;
    endcase //addr_lsbs
end //begin

reg[31:0] load_data;
always @(*) begin
    case (funct3)
        3'b000: load_data = {{24{load_raw[7]}}, load_raw[7:0]}; // lb
        3'b001: load_data = {{16{load_raw[15]}}, load_raw[15:0]}; // lh
        3'b010: load_data = load_raw; // lw
        3'b100: load_data = {24'b0, load_raw[7:0]}; // lbu
        3'b101: load_data = {16'b0, load_raw[15:0]}; // lhu
        default: load_data = 32'b0; // illegal
    endcase //funct3
end //begin

assign o_dmem_addr = {mem_byte_addr[31:2], 2'b00};
assign o_dmem_ren = mem_read  && !will_trap && !is_ebreak;
assign o_dmem_wen = mem_write && !will_trap && !is_ebreak;
assign o_dmem_mask = mask_c;
assign o_dmem_wdata = wdata_c;

//Writeback MUX
wire[1:0] wb_sel = (is_jal || is_jalr) ? 2'b01 : (mem_read) ? 2'b10 : 2'b00;

reg[31:0] rd_wdata_c;
always @(*) begin
    case (wb_sel)
        2'b00: rd_wdata_c = alu_result; // ALU result
        2'b01: rd_wdata_c = pc_plus4; // PC + 4 for JAL/JALR
        2'b10: rd_wdata_c = load_data; // Data from memory
        default: rd_wdata_c = alu_result; // Default case
    endcase //wb_sel
end //begin

//Retire Interface
wire reads_rs1 = !(is_lui || is_auipc || is_jal || illegal);
wire reads_rs2 = !alu_src || mem_write;   // R-type/branch use rs2 as ALU B; stores read rs2 for data

assign o_retire_valid     = !i_rst;
assign o_retire_inst      = inst;
assign o_retire_trap      = will_trap;
assign o_retire_halt      = is_ebreak;
assign o_retire_rs1_raddr = reads_rs1 ? rs1_addr : 5'd0;
assign o_retire_rs1_rdata = rs1_data;
assign o_retire_rs2_raddr = reads_rs2 ? rs2_addr : 5'd0;
assign o_retire_rs2_rdata = rs2_data;
assign o_retire_rd_waddr  = rd_waddr;
assign o_retire_rd_wdata  = rd_wdata_c;
assign o_retire_pc        = pc;
assign o_retire_next_pc   = pc_next;

endmodule

`default_nettype wire
