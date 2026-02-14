#!/bin/bash
# Run minimal test: only the 5 instructions that write 0xCAFEBABE to 0x1FFC.
# Use to check if the store path works; if PASS, the full E2E timeout is due to bubble sort not reaching done.
set -e
cd "$(dirname "$0")"
mkdir -p local
iverilog -g2012 -s tb_minimal_done -o local/simv_minimal \
  tb/tb_minimal_done.v src/rv_pl.v src/reg_file.v src/imem.v src/dmem.v \
  src/alu.v src/decoder.v src/sign_ext.v src/plr1.v src/plr2.v src/plr3.v src/plr4.v src/hazard_unit.v
vvp local/simv_minimal
