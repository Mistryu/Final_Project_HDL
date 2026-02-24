#!/bin/bash
# Run end-to-end simulation using the BRAM‑model testbench.
# The testbench instantiates simple behavioral BRAMs and drives the new rv_pl interface.
# Requires iverilog/vvp on $PATH (e.g. apt install iverilog).

set -e
cd "$(dirname "$0")"
REPO_ROOT="$HOME/Desktop/HDL/final project/Final_Project_HDL" # update according to setup
SRC_DIR="$REPO_ROOT/Hardware_design/RISC-V_core_IP/src"
TB_DIR="$REPO_ROOT/Hardware_design/RISC-V_core_IP/tb"
HEX_FILE="$TB_DIR/bubble_sort_fixed.hex"
mkdir -p local

echo "Compiling E2E BRAM testbench..."
echo "Using hex file: $HEX_FILE"

iverilog -g2012 -s tb_e2e_python_flow_bram \
  -P "tb_e2e_python_flow_bram.HEX_FILE=\"$HEX_FILE\"" \
  -o local/simv_e2e_bram \
  -y "$SRC_DIR" \
  "$TB_DIR/tb_e2e_python_flow_bram.v"

cd local
echo "Running simulation..."
vvp simv_e2e_bram

echo "Exit code: $?"