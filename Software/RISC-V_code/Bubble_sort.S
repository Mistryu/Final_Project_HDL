# Bubble Sort Implementation for RISC-V

addi x1, x0, 0       # x1 = base address
addi x2, x0, 32      # x2 = number of elements or count (32)
addi x3, x0, 0       # x3 = outer loop counter (i)

outer_loop: # Loop for how many passes (n) through the data we make

    addi x4, x2, -1      # x4 = n - 1
    slt x5, x3, x4       # x5 = (i < n-1)
    beq x5, x0, done     # if i >= n-1, exit
    
    addi x6, x0, 0       # x6 = inner loop counter (j)
    sub x7, x2, x3       # x7 = n - i
    addi x7, x7, -1      # x7 = n - i - 1
    
inner_loop: # Loop for comparing adjacent elements

    slt x8, x6, x7       # x8 = (j < n-i-1)
    beq x8, x0, outer_increment  # if j >= n-i-1 we go to next outer iteration
    
    slli x9, x6, 2       # x9 = j * 4 (byte offset)
    add x10, x1, x9      # x10 = address of arr[j]
    lw x11, 0(x10)       # x11 = arr[j]
    lw x12, 4(x10)       # x12 = arr[j+1]
    
    slt x13, x12, x11    # x13 = (arr[j+1] < arr[j])
    beq x13, x0, no_swap # if arr[j] <= arr[j+1] we skip swap
    
    sw x12, 0(x10)       # arr[j] = arr[j+1]
    sw x11, 4(x10)       # arr[j+1] = arr[j]
    
no_swap:
    addi x6, x6, 1       # j++
    jal x0, inner_loop
    
outer_increment:
    addi x3, x3, 1       # i++
    jal x0, outer_loop

# This is teh version which still uses lui instructio 
done:
    # Write DONE flag so Python script can detect completion (0xCAFEBABE at 0x1FFC)
    lui  x14, 0xcafeb             # 0xCAFEC000; then addi 0xabe (sign-ext) -> 0xCAFEBABE
    addi x14, x14, 0xabe
    lui  x15, 0x2ffc              # loads 0x1FFC as flag successful 
    addi x0, x0, 0             # NOP so SW reads x14/x15 from reg file
    sw   x14, 0(x15)