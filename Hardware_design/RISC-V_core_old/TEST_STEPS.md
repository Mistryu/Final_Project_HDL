# Running the E2E test 

This runs the **same flow** Python script uses: load HEX, inject data, detect DONE (0xCAFEBABE), verify sorted array. No Vivado or PYNQ needed — only the RTL simulation.

## 2. Run the E2E simulation

From your project root:

```bash
cd RISC-V_code/RISCV

chmod +x run_e2e_sim.sh

./run_e2e_sim.sh
```

Or with explicit commands:

```bash
cd RISC-V_code/RISCV

mkdir -p local

iverilog -g2012 -s tb_e2e_python_flow -o local/simv_e2e \
  tb/tb_e2e_python_flow.v src/rv_pl.v src/reg_file.v src/imem.v src/dmem.v \
  src/alu.v src/decoder.v src/sign_ext.v src/plr1.v src/plr2.v src/plr3.v src/plr4.v src/hazard_unit.v
  
vvp local/simv_e2e
```

**Important:** You must be inside `RISC-V_code/RISCV` when you run `vvp`, so that `programs/bubble_sort_clean.hex` is found.

---

## 3. What you should see if everything works

Successful run looks like:

```
Compiling E2E testbench...
Running simulation...
E2E: Loading instructions (script 0x0000) -> IMEM
E2E: Injecting 32 integers (script 0x1000) -> DMEM[0..31]
E2E: Resetting status flag (script 0x1FFC) -> DMEM[255]
E2E: Releasing reset, running until DONE or timeout
E2E: SUCCESS flag (0xCAFEBABE) detected at 0x1FFC after XXXXX cycles
E2E: Reading array from DMEM[0..31] (script 0x1000)
E2E: SUCCESS - Full flow OK: DONE detected, array sorted.
Exit code: 0
```

- **SUCCESS flag (0xCAFEBABE) detected** → core ran the program and wrote the DONE flag.
- **SUCCESS - Full flow OK** → array in DMEM matched the expected sorted order (1..32).
- **Exit code: 0** → script finished successfully.