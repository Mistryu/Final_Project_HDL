# Bubble sort simulation test (mirrors Python injection)

Run from `RISC-V_code/RISCV/`:

```bash
iverilog -g2012 -s tb_bubble_sort -o local/simv_bubble \
  tb/tb_bubble_sort.v src/rv_pl.v src/reg_file.v src/imem.v src/dmem.v \
  src/alu.v src/decoder.v src/sign_ext.v src/plr1.v src/plr2.v \
  src/plr3.v src/plr4.v src/hazard_unit.v
  
vvp local/simv_bubble
```

- Uses `programs/bubble_sort_clean.hex` (instructions, no comments) and injects 32 words into `DMEM.RAM[0..31]` (descending 32,31,...,1).
- Expects sorted result 1,2,...,32. Success/failure is printed at the end.
