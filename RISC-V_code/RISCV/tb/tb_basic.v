`timescale 1ns / 1ps

module tb_basic;
  reg clk;
  reg reset;
  integer errors = 0;

  rv_pl dut (
    .clk(clk),
    .rst_n(reset)
  );

  wire [31:0] x1_spy = dut.RF.regs[1];
  wire [31:0] x2_spy = dut.RF.regs[2];
  wire [31:0] x3_spy = dut.RF.regs[3];
  wire [31:0] x4_spy = dut.RF.regs[4];

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    $readmemh("programs/test_basic.hex", dut.IMEM.RAM);

    reset = 0;
    #20;
    reset = 1;

    #200;

    if (x1_spy !== 1) begin
      $display("FAIL: x1=%0d (Expected 1)", x1_spy);
      errors = errors + 1;
    end
    if (x2_spy !== 2) begin
      $display("FAIL: x2=%0d (Expected 2)", x2_spy);
      errors = errors + 1;
    end
    if (x3_spy !== 3) begin
      $display("FAIL: x3=%0d (Expected 3)", x3_spy);
      errors = errors + 1;
    end
    if (x4_spy !== 4) begin
      $display("FAIL: x4=%0d (Expected 4)", x4_spy);
      errors = errors + 1;
    end

    if (errors == 0)
      $display("SUCCESS: Basic pipeline test passed.");
    else
      $display("FAILURE: %0d errors.", errors);

    $finish;
  end

endmodule
