#!/usr/bin/env python3
"""Generate a Verilog initial block for 32 signed integers (same logic as riscv_sort_test.py).
   Output: one value per line for $readmemh, or a list for a testbench.
   Used to keep sim and Python test data aligned."""
import random
import struct

ARRAY_SIZE = 32
ARRAY_MIN = -1000
ARRAY_MAX = 1000

def gen_array(seed=None):
    if seed is not None:
        random.seed(seed)
    return [random.randint(ARRAY_MIN, ARRAY_MAX) for _ in range(ARRAY_SIZE)]

def to_hex_file(arr, path):
    with open(path, 'w') as f:
        for v in arr:
            u = v & 0xFFFFFFFF
            f.write(f"{u:08X}\n")

if __name__ == "__main__":
    arr = gen_array(42)
    to_hex_file(arr, "programs/bubble_sort_data.hex")
    print("Sorted:", sorted(arr))
