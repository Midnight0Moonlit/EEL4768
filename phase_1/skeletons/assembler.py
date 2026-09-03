# This RISC-V assembler was made through the dialogue between the goals of its
# human developer (Orlando) and the abilities of the AI counterpart (Claude
# Haiku 4.5)

# Because this manifests both in the overall vision and details of
# implementation, (human-made) comments will attempt to explain
# this whole process and balance as much as possible


import os
import re
import sys


# Dictionaries are an obvious way to map single words to (more) complex fields
# Defining dictionaries is a fairly simple but rote process
# On its face, perfect for AI to do on its face, but still requires some human
# organization (see I_TYPE)


# Necessary starting addresses for instructions and data
TEXT_BASE = 0x00400000
DATA_BASE = 0x10010000

# Assigns ABI names to all 32 registers (so both formats are acceptable)
REGISTERS = {
    "zero": 0, "ra": 1, "sp": 2, "gp": 3,
    "tp": 4, "t0": 5, "t1": 6, "t2": 7,
    "s0": 8, "fp": 8, "s1": 9, "a0": 10, "a1": 11,
    "a2": 12, "a3": 13, "a4": 14, "a5": 15,
    "a6": 16, "a7": 17, "s2": 18, "s3": 19,
    "s4": 20, "s5": 21, "s6": 22, "s7": 23,
    "s8": 24, "s9": 25, "s10": 26, "s11": 27,
    "t3": 28, "t4": 29, "t5": 30, "t6": 31,
}

# Assigns values equal to each register's number
for i in range(32):
    REGISTERS[f"x{i}"] = i


# Contains all instructions from reference card
# Format: opcode, funct3, funct7 (None where N/A)

# AI mistakenly gen'd some insufficient tuples, corrected by human oversight
# Otherwise, 3-tuples not always "simplest," but the consistency is preferable


# Register arithmetic
R_TYPE = {
    "add":  (0x00, 0x0, 0x33),
    "sub":  (0x20, 0x0, 0x33),
    "sll":  (0x00, 0x1, 0x33),
    "slt":  (0x00, 0x2, 0x33),
    "sltu": (0x00, 0x3, 0x33),
    "xor":  (0x00, 0x4, 0x33),
    "srl":  (0x00, 0x5, 0x33),
    "sra":  (0x20, 0x5, 0x33),
    "or":   (0x00, 0x6, 0x33),
    "and":  (0x00, 0x7, 0x33),
}

# Immediate arithmetic
I_TYPE = {
    "addi":  (None, 0x0, 0x13),
    "slli":  (0x00, 0x1, 0x13),
    "slti":  (None, 0x2, 0x13),
    "sltiu": (None, 0x3, 0x13),
    "xori":  (None, 0x4, 0x13),
    "srli":  (0x00, 0x5, 0x13),
    "srai":  (0x20, 0x5, 0x13),
    "ori":   (None, 0x6, 0x13),
    "andi":  (None, 0x7, 0x13),

    # Load family and jalr were first generated as separate dictionaries, but
    # were consolidated here to keep with assignment conventions

    # Load (informal)
    "lb":    (None, 0x0, 0x03),
    "lh":    (None, 0x1, 0x03),
    "lw":    (None, 0x2, 0x03),
    "lbu":   (None, 0x4, 0x03),
    "lhu":   (None, 0x5, 0x03),

    # Register jump (informal)
    "jalr":  (None, 0x0, 0x67),
}

# Upper immediate arithmetic
U_TYPE = {
    "lui":   (None, None, 0x37),
    "auipc": (None, None, 0x17),
}

# Store
S_TYPE = {
    "sb": (None, 0x0, 0x23),
    "sh": (None, 0x1, 0x23),
    "sw": (None, 0x2, 0x23),
}

# Conditional branch
B_TYPE = {
    "beq":  (None, 0x0, 0x63),
    "bne":  (None, 0x1, 0x63),
    "blt":  (None, 0x4, 0x63),
    "bge":  (None, 0x5, 0x63),
    "bltu": (None, 0x6, 0x63),
    "bgeu": (None, 0x7, 0x63),
}

# Jump
J_TYPE = {
    "jal": (None, None, 0x6F),
}

# Special handling due to unique syntax
SHIFT_OPS = {"slli", "srli", "srai"}
LOAD_OPS = {"lb", "lh", "lw", "lbu", "lhu"}


# Very useful for troubleshooting and detecting specific invalid behavior
# Almost all instances from AI
def error(message):
    raise ValueError(message)


# Functions to distinguish input types and determine the exact "specimen"
# Just normalize raw text into token
# Basic enough to implement manually, but AI suggested dividing my original
# one-size-fits-all function with three to allow specific error codes


def parse_register(token):
    token = token.strip().lower()

    if token not in REGISTERS:
        error(f"Invalid register: {token}")

    return REGISTERS[token]


def parse_number(token, symbols=None):
    token = token.strip()

    if symbols is not None and token in symbols: # If there's a symbol table + it's in it
        return symbols[token]

    try:
        return int(token, 0)
    except ValueError:
        error(f"Invalid immediate or symbol: {token}")


def parse_memory_operand(token, symbols):
    # Determines offset and register
    match = re.fullmatch(r"(.+)\(([^()]+)\)", token.strip())

    # Unexpected format
    if not match:
        error(f"Invalid memory operand: {token}")

    # Parses offset and converts register to internal representation
    immediate = parse_number(match.group(1), symbols)
    base_register = parse_register(match.group(2))

    return immediate, base_register

# Following functions, though only called once each (redundant), clearly
# delineate the assembly pipeline at the suggestion of AI

# Breaks down exact instruction and converts to to machine code
# Relatively formulaic enough to write decent pseudo-code for, but AI helped
# with per-basis differences and especially bitwise operations

def encode_instruction(opcode_text, operands, pc, symbols):
    opcode = opcode_text.lower()

    # Environment-call instruction
    if opcode == "ecall":
        # Needs fixed encoding
        if operands:
            error("ecall does not take operands")
        return 0x00000073

    # funct7 | rs2 | rs1 | funct3 | rd | op
    if opcode in R_TYPE:
        if len(operands) != 3:
            error(f"{opcode} requires rd, rs1, rs2")

        # Converts registers to respective numbers
        rd = parse_register(operands[0])
        rs1 = parse_register(operands[1])
        rs2 = parse_register(operands[2])
        funct7, funct3, op = R_TYPE[opcode] # Looks up instruction's encoding

        # Shift amount = field's lowest index
        return (
            (funct7 << 25)
            | (rs2 << 20)
            | (rs1 << 15)
            | (funct3 << 12)
            | (rd << 7)
            | op
        )

    # I-type: imm | rs1 | funct3 | rd | op

    if opcode in SHIFT_OPS:
        if len(operands) != 3:
            error(f"{opcode} requires rd, rs1, shamt")

        rd = parse_register(operands[0])
        rs1 = parse_register(operands[1])
        shamt = parse_number(operands[2], symbols) # Offset is a constant

        if shamt < 0 or shamt >= (1 << 5):
            error(f"Shift amount {shamt} does not fit in 5 bits")

        funct7, funct3, op = I_TYPE[opcode] # For locating in instruction dictionary

        return (
            (funct7 << 25)
            | (shamt << 20)
            | (rs1 << 15)
            | (funct3 << 12)
            | (rd << 7)
            | op
        )

    if opcode in LOAD_OPS:
        if len(operands) != 2:
            error(f"{opcode} requires rd, offset(rs1)")

        rd = parse_register(operands[0])
        imm, rs1 = parse_memory_operand(operands[1], symbols) # Split into offset and register
        _, funct3, op = I_TYPE[opcode] # funct7 unused

        if imm < (-(1 << 11)) or imm > ((1 << 11) - 1):
            error(f"Immediate {imm} does not fit in 12 bits")

        return (
            ((imm & 0xFFF) << 20)
            | (rs1 << 15)
            | (funct3 << 12)
            | (rd << 7)
            | op
        )

    if opcode in I_TYPE:
        if len(operands) != 3:
            error(f"{opcode} requires rd, rs1, immediate")

        rd = parse_register(operands[0])
        rs1 = parse_register(operands[1])
        imm = parse_number(operands[2], symbols)
        _, funct3, op = I_TYPE[opcode]

        if imm < (-(1 << 11)) or imm > ((1 << 11) - 1):
            error(f"Immediate {imm} does not fit in 12 bits")

        return (
            ((imm & 0xFFF) << 20)
            | (rs1 << 15)
            | (funct3 << 12)
            | (rd << 7)
            | op
        )

    # jalr is I-type, not J
    if opcode == "jalr":
        if len(operands) != 2:
            error("jalr requires rd, offset(rs1)")

        rd = parse_register(operands[0])
        imm, rs1 = parse_memory_operand(operands[1], symbols)
        _, funct3, op = I_TYPE[opcode]

        if imm < (-(1 << 11)) or imm > ((1 << 11) - 1):
            error(f"Immediate {imm} does not fit in 12 bits")

        return (
            ((imm & 0xFFF) << 20)
            | (rs1 << 15)
            | (funct3 << 12)
            | (rd << 7)
            | op
        )

    # imm | rs2 | rs1 | funct3 | imm | op
    if opcode in S_TYPE:
        if len(operands) != 2:
            error(f"{opcode} requires rs2, offset(rs1)")

        rs2 = parse_register(operands[0])
        imm, rs1 = parse_memory_operand(operands[1], symbols)
        _, funct3, op = S_TYPE[opcode]

        if imm < (-(1 << 11)) or imm > ((1 << 11) - 1):
            error(f"Immediate {imm} does not fit in 12 bits")

        imm_low = imm & 0x1F
        imm_high = (imm >> 5) & 0x7F

        return (
            (imm_high << 25)
            | (rs2 << 20)
            | (rs1 << 15)
            | (funct3 << 12)
            | (imm_low << 7)
            | op
        )

    # imm | rs2 | rs1 | funct3 | imm | op
    if opcode in B_TYPE:
        if len(operands) != 3:
            error(f"{opcode} requires rs1, rs2, label")

        rs1 = parse_register(operands[0])
        rs2 = parse_register(operands[1])

        target = parse_number(operands[2], symbols)
        offset = target - pc

        if offset % 2 != 0:
            error("Branch target must be 2-byte aligned")

        if offset < (-(1 << 12)) or offset > ((1 << 12) - 1):
            error(f"Branch offset {offset} does not fit in 13 bits")

        _, funct3, op = B_TYPE[opcode]
        immediate = offset & 0x1FFF # Only keep 13 bits

        # Extract immediate portions
        bit12 = (immediate >> 12) & 0x1
        bit11 = (immediate >> 11) & 0x1
        bits10_5 = (immediate >> 5) & 0x3F
        bits4_1 = (immediate >> 1) & 0xF

        return (
            (bit12 << 31)
            | (bits10_5 << 25)
            | (rs2 << 20)
            | (rs1 << 15)
            | (funct3 << 12)
            | (bits4_1 << 8)
            | (bit11 << 7)
            | op
        )

    # imm | rd | op
    if opcode in U_TYPE:
        if len(operands) != 2:
            error(f"{opcode} requires rd, immediate")

        rd = parse_register(operands[0])
        imm = parse_number(operands[1], symbols)
        _, _, op = U_TYPE[opcode]

        if imm < 0 or imm >= (1 << 20):
            error(f"Immediate {imm} does not fit in 20 bits")

        return (imm << 12) | (rd << 7) | op

    # imm | rd | op
    if opcode in J_TYPE:
        # Only destination
        if len(operands) == 1:
            rd = 1
            target_token = operands[0]

        # Both destination and target
        elif len(operands) == 2:
            rd = parse_register(operands[0])
            target_token = operands[1]
        else:
            error("jal requires label or rd, label")

        target = parse_number(target_token, symbols)
        offset = target - pc

        if offset % 2 != 0:
            error("Jump target must be 2-byte aligned")

        if offset < (-(1 << 20)) or offset > ((1 << 20) - 1):
            error(f"Jump offset {offset} does not fit in 21 bits")

        # Only 21 bits
        immediate = offset & 0x1FFFFF

        bit20 = (immediate >> 20) & 0x1
        bits10_1 = (immediate >> 1) & 0x3FF
        bit11 = (immediate >> 11) & 0x1
        bits19_12 = (immediate >> 12) & 0xFF

        _, _, op = J_TYPE[opcode]

        return (
            (bit20 << 31)
            | (bits10_1 << 21)
            | (bit11 << 20)
            | (bits19_12 << 12)
            | (rd << 7)
            | op
        )

    error(f"Unsupported instruction: {opcode}")


# Tracks and sorts symbols, data, and text
# Perhaps most assisted with AI overall - syntax is so important that seeking
# guidance for each tempting possibility was a lesson in itself

def first_pass(lines):
    symbols = {}

    # Includes offsets
    text_items = []
    data_items = []

    # .text, .data, or None
    section = None
    
    text_offset = 0
    data_offset = 0

    for line in lines:
        labels = []

        # Continue removing labels (AI warned there may be multiple)
        while True:
            match = re.match(r"^\s*([A-Za-z_.$][\w.$]*):", line)

            # No more labels
            if not match:
                break

            labels.append(match.group(1)) # Saves to list
            line = line[match.end():].strip() # Removes from input

        for label in labels:
            if label in symbols:
                error(f"Duplicate label: {label}")

            if section == ".text":
                symbols[label] = TEXT_BASE + text_offset
            elif section == ".data":
                symbols[label] = DATA_BASE + data_offset
            
            # Labels cannot appear before section
            else:
                error(f"Label outside .text or .data: {label}")

        if not line:
            continue

        # Remove comments and tokenizes
        line = line.split("#", 1)[0].strip()

        # Special case: empty line
        if not line:
            tokens = []

        # Separates using commas and whitespace
        tokens = [x for x in re.split(r"[,\s]+", line) if x]

        if not tokens:
            continue

        directive = tokens[0].lower() # First token -> directive

        if directive == ".text":
            section = ".text"
            continue

        if directive == ".data":
            section = ".data"
            continue

        # Ignore global-symbol directives
        if directive in (".globl", ".global"):
            continue

        if section == ".data":
            if directive == ".word":
                values = tokens[1:] # Grabs all values after directive

                if not values:
                    error(".word requires at least one value")

                data_items.append((data_offset, values)) # Values w/ offsets saved
                data_offset += 4 * len(values) # Four bytes each
            else:
                error(f"Unsupported data directive: {directive}")

        elif section == ".text":
            text_items.append((text_offset, tokens))
            text_offset += 4

        else:
            error(f"Instruction or directive outside a section: {line}")

    return symbols, text_items, data_items, text_offset, data_offset

# Analyzes all given code and encodes them
# Pseudo-code largely trivial (thanks to pre-defining first_pass), but AI
# again fantastic for helping with handling bits/bytes

def assemble(lines):
    # First pass: store symbol addresses, instructions, data (and sizes)
    symbols, text_items, data_items, text_size, data_size = first_pass(lines)

    # Holds machine code translations
    text_bytes = bytearray()
    data_bytes = bytearray()

    # Second pass: encode instructions to text
    for text_offset, tokens in text_items:
        pc = TEXT_BASE + text_offset

        # 32 bits
        # tokens[0] = name, [1:] = operands
        instruction = encode_instruction(tokens[0], tokens[1:], pc, symbols)

        # 32 bits -> 4 bytes, then appends to text
        text_bytes.extend(instruction.to_bytes(4, byteorder="little"))

    # Second pass: encode values to data
    for data_offset, values in data_items:
        for value_token in values:
            value = parse_number(value_token, symbols) # String -> integer
            value &= 0xFFFFFFFF # Truncates to lower 32 bits
            data_bytes.extend(value.to_bytes(4, byteorder="little"))

    return text_bytes, data_bytes

# Writes assembly product to (different format) files and informs user
# Mostly manually written

def write_outputs(input_file, text_bytes, data_bytes):
    # Outputs will copy the original filename and append them w/ formats
    # Recommended optimization by AI

    base, _ = os.path.splitext(input_file)

    text_hex_file = base + ".hex.txt"
    text_bin_file = base + ".bin.txt"
    data_hex_file = base + "_data.hex.txt"
    data_bin_file = base + "_data.bin.txt"

    # Matching lines between outputs are equivalent, but expressed differently

    # Text section, two hexadecimal digits
    with open(text_hex_file, "w") as file:
        for byte in text_bytes:
            file.write(f"0x{byte:02x}\n")

        print(f"Wrote {text_hex_file}")

    # Text, eight binary digits
    with open(text_bin_file, "w") as file:
        for byte in text_bytes:
            file.write(f"{byte:08b}\n")

        print(f"Wrote {text_bin_file}")

    # Data, two hexadecimal
    with open(data_hex_file, "w") as file:
        for byte in data_bytes:
            file.write(f"0x{byte:02x}\n")

        print(f"Wrote {data_hex_file}")

    # Data, eight binary
    with open(data_bin_file, "w") as file:
        for byte in data_bytes:
            file.write(f"{byte:08b}\n")

        print(f"Wrote {data_bin_file}")


# Checks file and runs everything (through function calls)
# Mostly written manually, AI added ValueError

def main():
    # Only one argument allowed
    if len(sys.argv) != 2:
        print("Usage: python assembler.py <assembly_file>")
        sys.exit(1)

    assembly_file = sys.argv[1]

    try:
        with open(assembly_file, "r") as file:
            lines = file.readlines()

        # Assembly -> machine code, then outputs four files
        text_bytes, data_bytes = assemble(lines)
        write_outputs(assembly_file, text_bytes, data_bytes)

    # Couldn't find provided filename
    except FileNotFoundError:
        print(f"Error: file not found: {assembly_file}")
        sys.exit(1)

    # Invalid syntax/values 
    except ValueError as exc:
        print(f"Assembly error: {exc}")
        sys.exit(1)


if __name__ == "__main__":
    main()