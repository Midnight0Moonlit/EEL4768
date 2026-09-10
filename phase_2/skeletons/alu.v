`default_nettype none

// The arithmetic logic unit (ALU) is responsible for performing the core
// calculations of the processor. It takes two 32-bit operands and outputs
// a 32 bit result based on the selection operation - addition, comparison,
// shift, or logical operation. This ALU is a purely combinational block, so
// you should not attempt to add any registers or pipeline it.
module alu (
    // Major operation selection.
    // 3'b000: addition/subtraction if `i_sub` asserted
    // 3'b001: shift left logical
    // 3'b010: set less than
    // 3'b011: set less than unsigned
    // 3'b100: exclusive or
    // 3'b101: shift right logical/arithmetic if `i_arith` asserted
    // 3'b110: or
    // 3'b111: and
    input  wire [ 2:0] i_opsel,
    // When asserted, addition operations should subtract instead.
    // This is only used for `i_opsel == 3'b000` (addition/subtraction).
    input  wire        i_sub,
    // When asserted, comparison operations should be treated as unsigned.
    // This is only used for branch comparisons, as the set less than unsigned
    // mode is already specified by `i_opsel`. For branch operations, the ALU
    // result is not used, only the comparison results.
    input  wire        i_unsigned,
    // When asserted, right shifts should be treated as arithmetic instead of
    // logical. This is only used for `i_opsel == 3'b101` (shift right).
    input  wire        i_arith,
    // First 32-bit input operand.
    input  wire [31:0] i_op1,
    // Second 32-bit input operand.
    input  wire [31:0] i_op2,
    // 32-bit output result. Any carry out (from addition) should be ignored.
    output wire [31:0] o_result,
    // Equality result. This is used downstream to determine if a
    // branch should be taken.
    output wire        o_eq,
    // Set less than result. This is used downstream to determine if a
    // branch should be taken.
    output wire        o_slt
);
    // Your implementation goes under here
    // ------------------------------------
    // A - B = A + (~B) + 1
    wire [31:0] add_b;
    wire [31:0] add_p;
    wire [31:0] add_g;
    wire [31:0] add_result;

    assign add_b = i_op2 ^ {32{i_sub}}; // use i_sub to see if i_op2 gets inverted
    assign add_p = i_op1 ^ add_b;
    assign add_g = i_op1 & add_b;

    wire [7:0] group_p; // propagate signal for lookahead carry adder
    wire [7:0] group_g; // generate signal for lookahead carry adder

    // lookahead carry adder: 
    // G(i) = A(i)*B(i)
    // P(i) = A(i) XOR B(i)
    // C(i+1) = G(i) + [P(i)*C(i)]
    genvar g;

    generate
        for(g=0;g<8;g=g+1) begin : GEN_GROUP_PG;
        localparam integer B = 4 * g;

        // P group = P(3)*P(2)*P(1)*P(0)
        // if all 1, carry entering P group can go through whole group
        //assign group_p[g] = add_p[B] & add_p[B=1] & add_p[B+2] & add_p[B+3];
        assign group_p[g] = add_p[B] & add_p[B+1] & add_p[B+2] & add_p[B+3]; // correction, source ChatGPT, B+1 instead of B=1

        // G group decides if group produces a carry
        // carry leaves group if bit 3 generates, bit 2 generates and bit 3 propagates, bit 1 generates and bits 2/3 propagate, or bit 0 generates and bits 1/2/3 propagate
        assign group_g[g] = add_g[B+3] | (add_p[B+3] & add_g[B+2]) | (add_p[B+3] & add_p[B+2] & add_g[B+1]) | (add_p[B+3] & add_p[B+2] & add_p[B+1] & add_g[B]);
        end
    endgenerate

    wire [7:0] group_c; // carry into groups
    // C(1) = G(0) + P(0)*C(0)
    // C(2) = G(1) + P(1)*G(0) + P(1)*P(0)*C(0)
    // pattern continues
    assign group_c[0] = i_sub;
    assign group_c[1] = group_g[0] | (group_p[0] & group_c[0]);
    assign group_c[2] = group_g[1] | (group_p[1] & group_g[0]) | (group_p[1] & group_p[0] & group_c[0]);
    assign group_c[3] = group_g[2] | (group_p[2] & group_g[1]) | (group_p[2] & group_p[1] & group_p[0] & group_c[0]) | (group_p[2] & group_p[1] & group_g[0]);
    assign group_c[4] = group_g[3] | (group_p[3] & group_g[2]) | (group_p[3] & group_p[2] & group_g[1]) | (group_p[3] & group_p[2] & group_p[1] & group_g[0]) | (group_p[3] & group_p[2] & group_p[1] & group_p[0] & group_c[0]);
    assign group_c[5] = group_g[4] | (group_p[4] & group_g[3]) | (group_p[4] & group_p[3] & group_g[2]) | (group_p[4] & group_p[3] & group_p[2] & group_g[1]) | (group_p[4] & group_p[3] & group_p[2] &  group_p[1] & group_g[0]) | (group_p[4] & group_p[3] & group_p[2] & group_p[1] & group_p[0] & group_c[0]);
    assign group_c[6] = group_g[5] | (group_p[5] & group_g[4]) | (group_p[5] & group_p[4] & group_g[3]) | (group_p[5] & group_p[4] & group_p[3] & group_g[2]) | (group_p[5] & group_p[4] & group_p[3] & group_p[2] & group_g[1]) | (group_p[5] & group_p[4] & group_p[3] & group_p[2] & group_p[1] & group_g[0]) | (group_p[5] & group_p[4] & group_p[3] & group_p[2] & group_p[1] & group_p[0] & group_c[0]);
    assign group_c[7] = group_g[6] | (group_p[6] & group_g[5]) | (group_p[6] & group_p[5] & group_g[4]) | (group_p[6] & group_p[5] & group_p[4] & group_g[3]) | (group_p[6] & group_p[5] & group_p[4] & group_p[3] & group_g[2]) | (group_p[6] & group_p[5] & group_p[4] & group_p[3] & group_p[2] & group_g[1]) | (group_p[6] & group_p[5] & group_p[4] & group_p[3] & group_p[2] & group_p[1] & group_g[0]) | (group_p[6] & group_p[5] & group_p[4] & group_p[3] & group_p[2] & group_p[1] & group_p[0] & group_c[0]);

// lookahead
// construct sum
generate
    for(g=0;g<8;g=g+1) begin: GEN_SUM
        localparam integer B = 4 * g;
        wire c1;
        wire c2;
        wire c3;

        // Sum(i) = P(i) XOR C(i)

        // first bit has a carry or propagates carry entering the group
        assign c1 = add_g[B] | (add_p[B] & group_c[g]);
        assign c2 = add_g[B+1] | (add_p[B+1] & add_g[B]) | (add_p[B+1] & add_p[B] & group_c[g]);
        assign c3 = add_g[B+2] | (add_p[B+2] & add_g[B+1]) | (add_p[B+2] & add_p[B+1] & add_g[B]) | (add_p[B+2] & add_p[B+1] & add_p[B] & group_c[g]);
        
        // add_result is final addition/subtraction
        assign add_result[B] = add_p[B] ^ group_c[g];
        assign add_result[B+1] = add_p[B+1] ^ c1;
        assign add_result[B+2] = add_p[B+2] ^ c2;
        assign add_result[B+3] = add_p[B+3] ^ c3;
    end
endgenerate

// left barrel shifter by 1, 2, 4, 8, 16
wire [31:0] sll_1;
wire [31:0] sll_2;
wire [31:0] sll_4;
wire [31:0] sll_8;
wire [31:0] sll_16;

// if bit 0 of shamt is 1, shift 1
assign sll_1 = i_op2[0] ? {i_op1[30:0], 1'b0} : i_op1;
assign sll_2 = i_op2[1] ? {sll_1[29:0], 2'b0} : sll_1;
assign sll_4 = i_op2[2] ? {sll_2[27:0], 4'b0} : sll_2;
assign sll_8 = i_op2[3] ? {sll_4[23:0], 8'b0} : sll_4;
assign sll_16 = i_op2[4] ? {sll_8[15:0], 16'b0} : sll_8;

// right barrel shifter, i_arith = 0 (SRL, fill w/ zero), i_arith = 1 (SRA, fill w/ sign bit)
wire [31:0] sr_1;
wire [31:0] sr_2;
wire [31:0] sr_4;
wire [31:0] sr_8;
wire [31:0] sr_16;

assign sr_1 = i_op2[0] ? {(i_arith ? i_op1[31] : 1'b0), i_op1[31:1]} : i_op1;
assign sr_2 = i_op2[1] ? {{2{(i_arith ? sr_1[31] : 1'b0)}}, sr_1[31:2]} : sr_1;
assign sr_4 = i_op2[2] ? {{4{(i_arith ? sr_2[31] : 1'b0)}}, sr_2[31:4]} : sr_2;
assign sr_8 = i_op2[3] ? {{8{(i_arith ? sr_4[31] : 1'b0)}}, sr_4[31:8]} : sr_4;
assign sr_16 = i_op2[4] ? {{16{(i_arith ? sr_8[31] : 1'b0)}}, sr_8[31:16]} : sr_8;

// comparator, eq_above[n] bits more significant than n equal
// lt_term[n] bit n is first diff bit and op1[n] = 0, op2[n] = 1
wire [31:0] eq_above;
wire [31:0] lt_term;

assign eq_above[31] = 1'b1;

genvar c;

generate
    for(c=0;c<31;c=c+1) begin : GEN_COMPARE
        assign eq_above[c] = eq_above[c+1] & ~(i_op1[c+1] ^ i_op2[c+1]);
    end
endgenerate

assign lt_term = eq_above & ~i_op1 & i_op2;

wire unsigned_lt;
wire signed_lt;

assign unsigned_lt = |lt_term;

// if diff signs, neg operand smaller, else unsigned order same as signed order
assign signed_lt = (i_op1[31] ^ i_op2[31]) ? i_op1[31] : unsigned_lt;

// compare outputs
assign o_eq = ~|(i_op1 ^ i_op2);
assign o_slt = i_unsigned ? unsigned_lt : signed_lt;

// slt/sltu results
wire [31:0] slt_result;
wire [31:0] sltu_result;

assign slt_result = {31'b0, signed_lt};
assign sltu_result = {31'b0, unsigned_lt};

// final ALU results
//assign o_result = (i_opsel == 3'b000) ? add_result : (i_opsel == 3'b001) ? sll_16 : (i_opsel == 3'b010) ? slt_result : (i_opsel == 3'b011) ? sltu_result : (i_opsel == 3'b100) ? (i_op1 ^ i_op2) : (i_opsel == 3'b101) ? sr_16 : (i_opsel == 3'b110) ? (i_op1 | i_op2) : (i_op1 & i_op2);

// final mux correction, source ChatGPT
assign o_result =
    (i_opsel == 3'b000) ? add_result :
    (i_opsel == 3'b001) ? sll_16 :
    (i_opsel == 3'b010) ? slt_result :
    (i_opsel == 3'b011) ? sltu_result :
    (i_opsel == 3'b100) ? (i_op1 ^ i_op2) :
    (i_opsel == 3'b101) ? sr_16 :
    (i_opsel == 3'b110) ? (i_op1 | i_op2) :
                           (i_op1 & i_op2);
endmodule

`default_nettype wire