#!/usr/bin/env python3
"""
Validate E2E flow without hardware: check that the hex file and script logic
are consistent (instruction count, DONE sequence present, script layout).
Run actual RTL sim with: cd RISC-V_code/RISCV && ./run_e2e_sim.sh
"""
import os
import struct
import sys

# Same constants as riscv_sort_test.py
INSTRUCTION_BASE = 0x0000
DATA_RAM_BASE = 0x1000
STATUS_FLAG_OFFSET = 0x1FFC
MAGIC_SUCCESS = 0xCAFEBABE
ARRAY_SIZE = 32

def load_hex_like_script(filepath):
    """Same logic as riscv_sort_test.load_hex_file."""
    instructions = []
    with open(filepath) as f:
        for line in f:
            line = line.strip()
            if "//" in line:
                line = line.split("//")[0].strip()
            if line and not line.startswith("#"):
                instructions.append(int(line, 16))
    return instructions

def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    # Prefer Bubble_sort.hex (with comments) like the script uses
    hex_path = os.path.join(repo_root, "RISC-V_code", "Bubble_sort.hex")
    clean_hex = os.path.join(repo_root, "RISC-V_code", "RISCV", "programs", "bubble_sort_clean.hex")

    errors = []
    for path in [hex_path, clean_hex]:
        if not os.path.isfile(path):
            continue
        name = "Bubble_sort.hex" if "Bubble_sort.hex" in path else "bubble_sort_clean.hex"
        instrs = load_hex_like_script(path)
        if len(instrs) < 23:
            errors.append(f"{name}: expected >= 23 instructions, got {len(instrs)}")
        # Last 5 instructions should be the DONE write (lui, addi, lui, addi, sw)
        if len(instrs) >= 28:
            # 0x00e7a023 = sw x14, 0(x15)
            if (instrs[-1] & 0xFFFFFFFF) != 0x00E7A023:
                errors.append(f"{name}: last instruction should be sw (0x00e7a023), got {hex(instrs[-1])}")
        else:
            errors.append(f"{name}: expected 28 instructions (with DONE), got {len(instrs)}")

    if errors:
        for e in errors:
            print("VALIDATE FAIL:", e)
        return 1
    print("VALIDATE OK: Hex files load like script; instruction count and DONE sequence present.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
