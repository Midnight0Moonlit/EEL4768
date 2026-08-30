.data
a:  .word 1, 2, 5, 7
    .word 3, 9, 2, 5
    .word 1, 9, 8, 2
    .word 4, 1, 6, 6
b:  .word 3, 4, 9, 2
    .word 1, 8, 7, 3
    .word 8, 9, 1, 2
    .word 6, 3, 7, 5
c:  .word 0, 0, 0, 0
    .word 0, 0, 0, 0
    .word 0, 0, 0, 0
    .word 0, 0, 0, 0

.text
.globl main

main:
    #Register Allocation:
    #s0 = base address of a
    #s1 = base address of b
    #s2 = base address of c
    #t0 = m (outer loop index; 0 to 3)
    #t1 = n (middle loop index; 0 to 3)
    #t2 = k (inner loop index; 0 to 3)
    #s3 = C[m][n] accumulator value

    la    s0, a
    la    s1, b
    la    s2, c

    #m = 0
    li    t0, 0

loop_m:
    li    t3, 4
    #if m >= 4, exit loop_m
    bge    t0, t3, end_m
    #n = 0
    li    t1, 0

loop_n:
    li    t3, 4
    #if n >= 4, exit loop_n
    bge    t1, t3, end_n
    #C[m][n] = 0
    li    s3, 0
    #k = 0
    li    t2, 0

loop_k:
    li    t3, 4
    #if k >= 4, exit loop_k
    bge    t2, t3, end_k

    #Compute address & load A[m][k]
    #Offset_A = (m * 4 + k) * 4 = (m << 4) + (k << 2)
    #t4 = m * 16
    slli    t4, t0, 4
    #t5 = k * 4
    slli    t5, t2, 2
    #t4 = offset A in bytes
    add    t4, t4, t5
    #t4 = address of A[m][k]
    add    t4, s1, t4
    #a0 = multiplicand
    lw    a0, 0(t4)

    #Compute address & load B[k][n]
    #Offset_B = (k * 4 + n) * 4 = (k << 4) + (n << 2)
    #t4 = k * 16
    slli    t4, t2, 4
    #t5 = n * 4
    slli    t5, t1, 2
    #t4 = offset B in bytes
    add    t4, t4, t5
    #t4 = address of B[k][n]
    add    t4, s1, t4
    #a1 = multiplier
    lw    a1, 0(t4)

    #Software multiplication: t6 = a0 * a1
    #t6 = product
    li    t6, 0
    #bit counter i = 0
    li    a2, 0

mult_loop:
    li    t3, 32
    #if i >= 32, multiplication is done
    bge    a2, t3, mult_done

    #Check if bit i of a1 is set
    #a3 = B >> i
    srl    a3, a1, a2
    #a3 = (B >> i) & 1
    andi    a3, a3, 1
    #if bit is 0, skip adding
    beqz    a3, skip_add

    #Accumulate into product t6
    #a4 = A << i
    sll    a4, a0, a2
    #product += (A << i)
    add    t6, t6, a4

skip_add:
    #i++
    addi    a2, a2, 1
    j    mult_loop

mult_done:
    #Accumulate product into C[m][n]
    #C[m][n] += product
    add    s3, s3, t6
    #k++
    addi    t2, t2, 1
    j    loop_k

end_k:
    #Store C[m][n] into memory
    #Offset_C = (m * 4 + n) * 4 = (m << 4) + (n << 2)
    #t4 = m * 16
    slli    t4, t0, 4
    #t5 = n * 4
    slli    t5, t1, 2
    #t4 = offset C in bytes
    add    t4, t4, t5
    #t4 = address of C[m][n]
    add    t4, s2, t4
    #store accumulated result
    sw    s3, 0(t4)

    #n++
    addi    t1, t1, 1
    j    loop_n

end_n:
    #m++
    addi    t0, t0, 1
    j    loop_m

end_m:
    #Terminate execution