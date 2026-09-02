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

    lui s0, 0x10010
    addi s1, s0, 64
    addi s2, s1, 64

    addi t0, x0, 0


loop_m:
    addi t3, x0, 4
    bge t0, t3, end_m

    addi t1, x0, 0


loop_n:
    addi t3, x0, 4
    bge t1, t3, end_n

    addi s3, x0, 0

    addi t2, x0, 0


loop_k:
    addi t3, x0, 4
    bge t2, t3, end_k

    #Load A[m][k]
    #Offset_A = (m * 4 + k) * 4 = (m << 4) + (k << 2)
    #t4=m*16
    slli t4, t0, 4
    #t5=k*4
    slli t5, t2, 2
    #t4=total offset in bytes
    add t4, t4, t5
    #t4=address of A[m][k]
    add t4, s0, t4
    #a0 = A[m][k]
    lw a0, 0(t4)

    #Load B[k][n]
    #Offset_B = (k * 4 + n) * 4 = (k << 4) + (n << 2)
    #t4=k*16
    slli t4, t2, 4
    #t5=n*4
    slli t5, t1, 2
    #t4=total offset in bytes
    add t4, t4, t5
    #t4, address of B[k][n]
    add t4, s1, t4
    #a1=B[k][n]
    lw a1, 0(t4)

    #t6=a0*a1
    addi t6, x0, 0
    addi a2, x0, 0


mult_loop:
    addi t3, x0, 32
    bge a2, t3, mult_done

    #Check if bit i of a1 is set
    srl a3, a1, a2
    andi a3, a3, 1
    beq a3, x0, skip_add

    #Accumulate into product t6
    sll a4, a0, a2
    add t6, t6, a4

skip_add:
    #i++
    addi a2, a2, 1
    jal x0, mult_loop

mult_done:
    #Accumulate product into C[m][n]
    #C[m][n] += product
    add s3, s3, t6
    #k++
    addi t2, t2, 1
    jal x0, loop_k

end_k:
    #Store C[m][n] into memory
    #Offset_C = (m * 4 + n) * 4 = (m << 4) + (n << 2)
    #t4 = m * 16
    slli t4, t0, 4
    #t5 = n * 4
    slli t5, t1, 2
    #t4 = offset C in bytes
    add t4, t4, t5
    #t4 = address of C[m][n]
    add t4, s2, t4
    #store accumulated result
    sw s3, 0(t4)

    #n++
    addi t1, t1, 1
    jal x0, loop_n

end_n:
    #m++
    addi t0, t0, 1
    jal x0, loop_m

end_m:
    ecall