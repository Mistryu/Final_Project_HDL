# ============================================================================
# bubble_sort.S – Bubble sort for 32 integers (RV32I)
# ============================================================================
# Sorts an array of 32 words stored at address 0x0000 in ascending order,
# then writes the magic value 0xCAFEBABE to address 0x1FFC to signal
# completion to the testbench / verification script.
#
# Assemble with:  ./assemble.sh            (produces bubble_sort_fixed.hex)
# Toolchain:      riscv64-linux-gnu-*      (or riscv64-unknown-elf-*)
# ISA:            RV32I only (no compressed, no multiply)
# ============================================================================

    .section .text
    .globl _start

_start:
    addi x1, x0, 0             # x1  = base address of array (0)
    addi x2, x0, 32            # x2  = number of elements (n = 32)
    addi x3, x0, 0             # x3  = outer loop counter (i = 0)

outer_loop:
    addi x4, x2, -1            # x4  = n - 1
    slt  x5, x3, x4            # x5  = (i < n-1)
    beq  x5, x0, done          # if i >= n-1, sorting is complete

    addi x6, x0, 0             # x6  = inner loop counter (j = 0)
    sub  x7, x2, x3            # x7  = n - i
    addi x7, x7, -1            # x7  = n - i - 1

inner_loop:
    slt  x8, x6, x7            # x8  = (j < n-i-1)
    beq  x8, x0, outer_inc     # if j >= n-i-1, go to next outer pass

    slli x9, x6, 2             # x9  = j * 4  (byte offset)
    add  x10, x1, x9           # x10 = &arr[j]
    lw   x11, 0(x10)           # x11 = arr[j]
    lw   x12, 4(x10)           # x12 = arr[j+1]

    slt  x13, x12, x11         # x13 = (arr[j+1] < arr[j])
    beq  x13, x0, no_swap      # if arr[j] <= arr[j+1], skip swap

    sw   x12, 0(x10)           # arr[j]   = arr[j+1]
    sw   x11, 4(x10)           # arr[j+1] = arr[j]

no_swap:
    addi x6, x6, 1             # j++
    jal  x0, inner_loop        # repeat inner loop

outer_inc:
    addi x3, x3, 1             # i++
    jal  x0, outer_loop        # repeat outer loop

# ---------------------------------------------------------------------------
# Signal completion: write 0xCAFEBABE to memory address 0x1FFC
# ---------------------------------------------------------------------------
done:
    li   x14, 0xCAFEBABE       # magic success flag  (lui + addi)
    li   x15, 0x1FFC           # status flag address  (lui + addi)
    sw   x14, 0(x15)           # mem[0x1FFC] = 0xCAFEBABE

halt:
    j    halt                   # infinite self-loop (HALT)

# ---------------------------------------------------------------------------
# Padding: the pipeline speculatively fetches PC+4 for 2-3 cycles before a
# JAL redirects at the EX stage.  These extra words prevent the testbench
# PC-bounds check from triggering on squashed speculative fetches.
# ---------------------------------------------------------------------------
    j    .                      # safety: self-loop (padding)
    nop                         # padding
    nop                         # padding
