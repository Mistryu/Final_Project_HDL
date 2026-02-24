#!/bin/bash
# ============================================================================
# assemble.sh – Assemble bubble_sort.S into bubble_sort_fixed.hex
# ============================================================================
# Produces a plain-text hex file (one 32-bit word per line) suitable for
# $readmemh in the Verilog testbench.
#
# Requirements: riscv64-linux-gnu-{as,ld,objcopy} (apt install binutils-riscv64-linux-gnu)
#               or riscv64-unknown-elf-{as,ld,objcopy}
#
# Usage:  chmod +x assemble.sh && ./assemble.sh
# ============================================================================
set -e
cd "$(dirname "$0")"

CROSS=riscv64-linux-gnu
SRC=bubble_sort.S
OUT=bubble_sort_fixed.hex

echo "Assembling $SRC ..."

# 1. Assemble (RV32I only, no compressed instructions)
${CROSS}-as -march=rv32i -mabi=ilp32 -o bubble_sort.o "$SRC"

# 2. Link at address 0 (flat binary, text only)
${CROSS}-ld -m elf32lriscv -Ttext=0x0 --oformat=elf32-littleriscv -o bubble_sort.elf bubble_sort.o

# 3. Extract raw binary
${CROSS}-objcopy -O binary bubble_sort.elf bubble_sort.bin

# 4. Convert binary to one-word-per-line hex ($readmemh format)
python3 -c "
import struct, sys
data = open('bubble_sort.bin', 'rb').read()
# Pad to word boundary
while len(data) % 4:
    data += b'\x00'
words = struct.unpack('<' + 'I' * (len(data)//4), data)
for w in words:
    print(f'{w:08x}')
" > "$OUT"

echo "Generated $OUT ($(wc -l < "$OUT") words):"
cat "$OUT"

# 5. Clean up intermediates
rm -f bubble_sort.o bubble_sort.elf bubble_sort.bin

echo ""
echo "Done. Hex file ready: $OUT"
