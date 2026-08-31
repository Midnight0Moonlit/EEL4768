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
        ori s0, t0 0x0000 # needed so it can point to Matrix A

        # Base address for Matrix B
        lui s1, 0x10010 # memory layout
        ori s1, t0 0x0064 # needed so it can point to Matrix B, add 100 bytes based on the 5x5 previous matrix

        # Base address for Matrix C
        lui s0, 0x10010 # memory layout
        ori s0, t0 0x0088 # needed so it can point to Matrix C, add 36 bytes based on the 3x3 previous matrix

#Part 2: doing multiplication and such

#PArt 3: Storing the matrix into c

#Part 4: repeat
done:
        ecall