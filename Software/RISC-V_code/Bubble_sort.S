# Bubble Sort Implementation for RISC-V
addi x1, x0, 0       # x1 = base address
addi x2, x0, 32      # x2 = number of elements (32)
addi x3, x0, 0       # x3 = outer loop counter (i)

outer_loop:
    addi x4, x2, -1       # x4 = n - 1
    slt  x5, x3, x4       # x5 = (i < n-1)
    beq  x5, x0, done     # if i >= n-1, exit

    addi x6, x0, 0        # x6 = inner loop counter (j)
    sub  x7, x2, x3       # x7 = n - i
    addi x7, x7, -1       # x7 = n - i - 1

inner_loop:
    slt  x8, x6, x7       # x8 = (j < n-i-1)
    beq  x8, x0, outer_increment

    slli x9, x6, 2        # x9 = j * 4
    add  x10, x1, x9      # x10 = address of arr[j]
    lw   x11, 0(x10)      # x11 = arr[j]
    lw   x12, 4(x10)      # x12 = arr[j+1]
    addi x0, x0, 0        # NOP - wait for x11, x12

    slt  x13, x12, x11    # x13 = (arr[j+1] < arr[j])
    addi x0, x0, 0        # NOP - wait for x13
    beq  x13, x0, no_swap

    sw   x12, 0(x10)      # arr[j] = arr[j+1]
    sw   x11, 4(x10)      # arr[j+1] = arr[j]

no_swap:
    addi x6, x6, 1        # j++
    jal  x0, inner_loop

outer_increment:
    addi x3, x3, 1        # i++
    jal  x0, outer_loop

done:
    lui  x14, 0xCAFEB          # x14 = 0xCAFEB000
    addi x14, x14, 0x55F       # x14 = 0xCAFEB55F
    addi x14, x14, 0x55F       # x14 = 0xCAFEBABE
    addi x15, x0, 0x7FF        # x15 = 0x000007FF
    slli x15, x15, 2           # x15 = 0x00001FFC
    sw   x14, 0(x15)           # mem[0x1FFC] = 0xCAFEBABE