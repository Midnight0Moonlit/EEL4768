.data
a: .word 22
b: .word 59
c: .word 0

.text
.globl main

main:
# Assign variables to registers
lui t0, 0x10010 # memory layout
lw t1, 0(t0) # t1 is a
lw t2, 4(t0) # t2 is b
addi t3, zero, 0 # t3 is c
addi t4, zero, 0 # t4 is iterator
addi t5, zero, 32 # set max 32 bits

# Use bit shift and loop through 32 bits
loop:
# Check if condition that no greater than 32 bits, move to end section if complete
    bge t4, t5, done

    # current Bi
    andi t6, t2, 1

    beq t6, zero, skip # skip if Bi is 0, optimization encouraged by Claude

    add t3, t3, t1 # C += (A << i)

skip:
    slli t1, t1, 1 # shift a left for next iteration
    srli t2, t2, 1 # shift b right so bit 0 is always next Bi, from Claude
    addi t4, t4, 1 # increment iterator
    jal zero, loop # jump back to loop

done:
    sw t3, 8(t0) # store c result at offset 8, suggested by Claude
    ecall # end program
