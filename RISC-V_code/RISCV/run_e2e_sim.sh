#!/bin/bash
# Run end-to-end simulation (same flow as Python script).
# Requires: iverilog and vvp (e.g. apt install iverilog, or brew install icarus-verilog).
set -e
cd "$(dirname "$0")"
mkdir -p local
echo "Compiling E2E testbench..."
iverilog -g2012 -s tb_e2e_python_flow -o local/simv_e2e \
  tb/tb_e2e_python_flow.v src/rv_pl.v src/reg_file.v src/imem.v src/dmem.v \
  src/alu.v src/decoder.v src/sign_ext.v src/plr1.v src/plr2.v src/plr3.v src/plr4.v src/hazard_unit.v
echo "Running simulation..."
vvp local/simv_e2e
echo "Exit code: $?"
