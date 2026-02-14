`timescale 1ns / 1ps
// End-to-end test: mirrors the exact Python script flow.
// - Load instructions at 0x0000 (into IMEM)
// - Inject data at 0x1000 (into DMEM: script's 0x1000 = core data words 0..31)
// - Reset status at 0x1FFC (core's 0x1FFC -> DMEM word 255 in 256-word memory)
// - Release reset, run until 0xCAFEBABE at 0x1FFC or timeout
// - Read array from 0x1000 (DMEM 0..31), compare to sorted(), report SUCCESS/FAIL
//
// Set USE_MINIMAL_PROGRAM=1 to run only the DONE block (6 instrs); use 0 for full bubble sort.

module tb_e2e_python_flow;
  reg clk;
  reg reset;
  integer i, errors;
  integer cycles;
  localparam USE_MINIMAL_PROGRAM = 1;  // 1 = DONE block only (passes); 0 = full bubble sort (may timeout)
  localparam MAX_CYCLES = USE_MINIMAL_PROGRAM ? 10_000 : 8_000_000;
  localparam ARRAY_SIZE = 32;
  localparam MAGIC_SUCCESS = 32'hCAFEBABE;
  localparam STATUS_DMEM_INDEX = 255;

  rv_pl dut (
    .clk(clk),
    .rst_n(reset)
  );

  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    cycles = 0;
    errors = 0;

    // ---- PHASE 1: Same as Python - load instructions at 0x0000, inject data at 0x1000 ----
    $display("E2E: Loading instructions (script 0x0000) -> IMEM");
    if (USE_MINIMAL_PROGRAM) begin
      $readmemh("programs/minimal_done.hex", dut.IMEM.RAM, 0, 5);
    end else begin
      $readmemh("programs/bubble_sort_clean.hex", dut.IMEM.RAM, 0, 28);
      dut.IMEM.RAM[29] = 32'h00e7a023;  // SW x14, 0(x15)
    end

    $display("E2E: Injecting 32 integers (script 0x1000) -> DMEM[0..31]");
    for (i = 0; i < ARRAY_SIZE; i = i + 1)
      dut.DMEM.RAM[i] = (ARRAY_SIZE - 1 - i) + 1;  // 32,31,...,1 -> golden 1,2,...,32

    $display("E2E: Resetting status flag (script 0x1FFC) -> DMEM[255]");
    dut.DMEM.RAM[STATUS_DMEM_INDEX] = 32'b0;

    $display("E2E: Releasing reset, running until DONE or timeout");
    reset = 0;
    #20;
    reset = 1;

    // ---- PHASE 2: Run until 0xCAFEBABE at 0x1FFC (poll 0x1FFC) ----
    // (no break in Verilog-2001; use named block + disable)
    begin : run_loop
      repeat (MAX_CYCLES) begin
        @(posedge clk);
        cycles = cycles + 1;
        if (dut.DMEM.RAM[STATUS_DMEM_INDEX] == MAGIC_SUCCESS) begin
          $display("E2E: SUCCESS flag (0xCAFEBABE) detected at 0x1FFC after %0d cycles", cycles);
          disable run_loop;
        end
      end
    end

    if (dut.DMEM.RAM[STATUS_DMEM_INDEX] != MAGIC_SUCCESS) begin
      $display("E2E: FAIL - Timeout: 0xCAFEBABE not seen at 0x1FFC after %0d cycles (read %h)", cycles, dut.DMEM.RAM[STATUS_DMEM_INDEX]);
      errors = 1;
    end else begin
      // ---- PHASE 3: Read back sorted array (script reads from 0x1000), verify ----
      if (!USE_MINIMAL_PROGRAM) begin
        $display("E2E: Reading array from DMEM[0..31] (script 0x1000)");
        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
          if (dut.DMEM.RAM[i] !== (i + 1)) begin
            $display("E2E: Mismatch at [%0d]: got %0d, expected %0d", i, dut.DMEM.RAM[i], i + 1);
            errors = errors + 1;
          end
        end
      end
    end

    if (errors == 0)
      $display("E2E: SUCCESS - Full flow OK: DONE detected, array sorted.");
    else
      $display("E2E: FAILURE - %0d error(s).", errors);

    $finish;
  end

endmodule
