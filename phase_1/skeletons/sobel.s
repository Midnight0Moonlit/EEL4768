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
        addi t3, zero, 0 # initialize/ set gx to zero
        addi t4, zero, 0 # initialize/ set gy to zero

kxloop:
        bge t2, s4, yloop_done # Basically the i < 3 rule
        addi t5, zero, 0 # ky iteration

kyloop:
        bge t5, s4, kxloop_done # Basically the i < 3 rule

        # We start arithmetic down low

        add t6, t0, t2 # x + kx/ Row for A
        add s5, t1, t5 # y + ky/ Column for A

        # Multiplying for offset A
        slli a0, t6, 2 # Shifts by 2 bits to the left to multiply by 4
        add a0, a0, t6 # Adds (x + kx) so a0 can be equal to (x + kx) * 5[]
        add a0, a0, s5 # Adds column to the mix in order to get the exact Index
        slli a0, a0, 2 # Shifts the bit by 2 in order to multiply by 4; for byte offset
        add a0, s0, a0 # Adds the byte offset in the matrix A, which should start as 0
        lw a1, 0(a0) # loads the index based on the byte offset into the a1 variable

        # Multiplying for offsets GX and GY
        slli a2, t2, 1 # Shifts by 1 bit to the left to multiply kx by 2
        add a2, a2, t2 # Adds  kx so a2 can be equal to kx * 3
        add a2, a2, t5 # Adds column (ky) to the mix in order to get the exact index
        slli a2, a2, 2 # Shifts the bit by 2 in order to multiply by 4; for byte offset

        # Loading GX
        add a0, s1, a2 # Adds the byte offset in the matrix GX, which should start as 0; loads into a0 for easier computation
        lw a3, 0(a0) # loads the index based on the byte offset into the a3 variable

        # Loading GY
        add a0, s2, a2 # Adds the byte offset in the matrix GY, which should start as 0; loads into a0 for easier computation
        lw a4, 0(a0) # loads the index based on the byte offset into the a3 variable

        # gx_sum += A[x + kx][y + ky] * Gx[kx][ky]
        # gy_sum += A[x + kx][y + ky] * Gy[kx][ky]

        add a2, zero, a1 # Reuse a2 for gy loop

        #Code from teammate that did multi.s
        addi t6, zero, 0 # reuse t6 as gx_inc iterator
        addi s5, zero, 32 # reuse t7 as set max 32 bits
        addi s6, zero, 0 # gy_inc iterator

# Use bit shift and loop through 32 bits
inc_gx_loop:
        # Check if condition that no greater than 32 bits, move to next increment section if complete
        bge t6, s5, inc_gy_loop

        # current Bi (Gx)
        andi a5, a3, 1

        beq a5, zero, gx_skip # skip if Bi is 0, optimization encouraged by Claude

        add t3, t3, a1 # gx_sum += (A << i)

gx_skip:
        slli a1, a1, 1 # shift a left for next iteration
        srli a3, a3, 1 # shift b right so bit 0 is always next Bi, from Claude
        addi t6, t6, 1 # increment iterator
        jal zero, inc_gx_loop # jump back to loop

inc_gy_loop:
        # Check if condition that no greater than 32 bits, move to next increment section if complete
        bge s6, s5, kyloop_done

        # current Bi (Gx)
        andi a6, a4, 1

        beq a6, zero, gy_skip # skip if Bi is 0, optimization encouraged by Claude

        add t4, t4, a2 # gx_sum += (A << i)

gy_skip:
        slli a2, a2, 1 # shift a left for next iteration
        srli a4, a4, 1 # shift b right so bit 0 is always next Bi, from Claude
        addi s6, s6, 1 # increment iterator
        jal zero, inc_gy_loop # jump back to loop


kyloop_done:
        addi t5, t5, 1 # ky++
        beq zero, zero, kyloop # starts kyloop all over again

kxloop_done:
        addi t2, t2, 1 # kx++
        beq zero, zero, kxloop # starts kxloop all over again

yloop_done:
        # C[x][y] = gx_sum + gy_sum
        # reuses both a0 and a1 from the previous loops
        # Using the index formula
        slli a0, t0, 1
        add a0, a0, t0 
        add a0, a0, t1

        # Turning entire index to offset
        slli a0, a0, 2 # multiplies by 4

        # Add C's address to turn offset into address
        add a0, s3, a0 # turns a0 into address of C[t0][t1]

        # Finally do the addition
        add a1, t3, t4

        # Store it in the indexes
        sw a1, 0(a0)

        addi t1, t1, 1 # y++
        beq zero, zero, yloop

xloop_done:
        addi t0, t0, 1
        beq zero, zero, xloop

exit:
        ecall