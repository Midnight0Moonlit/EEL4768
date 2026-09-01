.data
a:      .word 10, 9, 9, 4, 0
        .word 0, 6, 6, 2, 2
        .word 5, 9, 8, 4, 3
        .word 7, 5, 5, 4, 3
        .word 8, 10, 8, 5, 0
gx:     .word -1, 0, 1
        .word -2, 0, 2
        .word -1, 0, 1
gy:     .word 1, 2, 1
        .word 0, 0, 0
        .word -1, -2, -1
c:      .word 0, 0, 0
        .word 0, 0, 0
        .word 0, 0, 0

.text
.globl main

# Extra notes to keep in mind:
# Index = (Row x Total columns) + Col
# Byte offset = Index x 4
# Byte offset will help grab whatever number is in said matrix

#when looping, we can add bytes in order to move on to the next set of area

main:
# Part 1: storing the 3x3 matrix
# When storing matrices, start with lui for the starting memory
# Then follow by ori so that the s values can direct towards the matrices
# Start ori with 0, then add the number of bits needed based on that matrix when moving to the next

        # Base address for Matrix A
        lui s0, 0x10010 # memory layout
        ori s0, s0, 0x0000 # needed so it can point to Matrix A

        # Base address for Matrix gx
        lui s1, 0x10010 # memory layout
        ori s1, s1, 0x0064 # needed so it can point to Matrix gx, add 100 bytes based on the 5x5 previous matrix

        # Base address for Matrix gy
        lui s2, 0x10010 # memory layout
        ori s2, s2, 0x0088 # needed so it can point to Matrix gx, add 36 bytes based on the 3x3 previous matrix

        # Base address for Matrix C
        lui s3, 0x10010 # memory layout
        ori s3, s3, 0x00AC # needed so it can point to Matrix gy, add 36 bytes based on the 3x3 previous matrix

        addi t0, zero, 0 # x iteration

        addi s4, zero, 3 # max since every single iterative maxes at 3

#Part 2: doing multiplication and such
xloop:
        bge t0, s4, exit # Basically the i < 3 rule
        addi t1, zero, 0 # y iteration = 0

yloop:
        bge t1, s4, xloop_done # Basically the i < 3 rule
        addi t2, zero, 0 # kx iteration

kxloop:
        bge t2, s4, yloop_done # Basically the i < 3 rule
        addi t3, zero, 0 # ky iteration

kyloop:
        bge t3, s4, kxloop_done # Basically the i < 3 rule

        # We start arithmetic down low
        # gx += A[i + ki][j + kj] * Gx[ki][kj];
        # gy += A[i + ki][j + kj] * Gy[ki][kj];

        addi t3, t3, 1 # ky++
        beq zero, zero, kyloop # starts kyloop all over again

kxloop_done:
        addi t2, t2, 1 # kx++
        beq zero, zero, kxloop # starts kxloop all over again

yloop_done:
        # C[i][j] = gx_sum + gy_sum
        addi t1, t1, 1 # y++
        beq zero, zero, yloop

xloop_done:
        addi t0, t0, 1
        beq zero, zero, xloop

exit:
        ecall