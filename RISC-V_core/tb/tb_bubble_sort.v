`timescale 1ns / 1ps
// Testbench that mimics Python script: load instructions, inject 32-word array
// into data memory, release reset, run, then verify array is sorted.
// No DONE flag or structural hazard in this sim (separate IMEM/DMEM).

module tb_bubble_sort;
  reg clk;
  reg reset;
  integer i, errors;
  integer cycles;
  localparam MAX_CYCLES = 5_000_000;
  localparam ARRAY_SIZE = 32;

  rv_pl dut (
    .clk(clk),
    .rst_n(reset)
  );

  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    cycles = 0;
    errors = 0;
    $readmemh("programs/bubble_sort_clean.hex", dut.IMEM.RAM);

    // Inject 32 signed integers into DMEM (same concept as Python write_data_array).
    // Core expects array at word 0..31 (Bubble_sort uses base x1=0).
    // Use descending order 32,31,...,1 so sorted = 1,2,...,32.
    for (i = 0; i < ARRAY_SIZE; i = i + 1)
      dut.DMEM.RAM[i] = (ARRAY_SIZE - 1 - i) + 1;  // 32, 31, ..., 1

    reset = 0;
    #20;
    reset = 1;
    $display("Bubble sort test: run up to %0d cycles", MAX_CYCLES);

    repeat (MAX_CYCLES) begin
      @(posedge clk);
      cycles = cycles + 1;
    end

    $display("Stopped after %0d cycles. Checking DMEM[0..31].", cycles);

    for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
      if (dut.DMEM.RAM[i] !== (i + 1)) begin
        $display("FAIL: DMEM[%0d] = %0d (expected %0d)", i, dut.DMEM.RAM[i], i + 1);
        errors = errors + 1;
      end
    end

    if (errors == 0)
      $display("SUCCESS: Array is sorted (1..32). Bubble sort passed.");
    else
      $display("FAILURE: %0d mismatches.", errors);

    $finish;
  end

endmodule
