// The immediate generator is responsible for decoding the 32-bit
// sign-extended immediate from the incoming instruction word. It is a purely
// combinational block that is expected to be embedded in the instruction
// decoder.
module imm (
    // Input instruction word. This is used to extract the relevant immediate
    // bits and assemble them into the final immediate.
    input  wire [31:0] i_inst,
    // Instruction format, determined by the instruction decoder based on the
    // opcode. This is one-hot encoded according to the following format:
    // [0] R-type
    // [1] I-type
    // [2] S-type
    // [3] B-type
    // [4] U-type
    // [5] J-type
    // Because the R-type format does not have an immediate, the output
    // immediate can be treated as a don't-care under this case.
    input  wire [ 5:0] i_format,
    // Output 32-bit immediate, sign-extended from the immediate bitstring.
    output wire [31:0] o_immediate
);
    // Your implementation goes under here
    // ------------------------------------

    reg [31:0] immediate; // placeholder for what type it is

    always @(*) begin
        case (i_format)
            6'b000001: immediate = 32'b0; // R-type (0 bit)
            6'b000010: immediate = {{20{i_inst[31]}}, i_inst[31:20]}; // I-type (1 bit)
            6'b000100: immediate = {{20{i_inst[31]}}, i_inst[31:25], i_inst[11:7]}; // S-type (2 bit)
            6'b001000: immediate = {{19{i_inst[31]}}, i_inst[31], i_inst[7], i_inst[30:25], i_inst[11:8], 1'b0}; // B-type (3 bit)
            6'b010000: immediate = {i_inst[31:12], {12{1'b0}}}; // U-type (4 bit)
            6'b100000: immediate = {{11{i_inst[31]}}, i_inst[31], i_inst[19:12], i_inst[20], i_inst[30:21], {1{1'b0}}}; // J-type (5 bit)
        endcase //i_format
    end // always

    assign o_immediate = immediate; //assigns the immediate to the output
endmodule //imm
