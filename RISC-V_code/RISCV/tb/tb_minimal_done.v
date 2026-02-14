`timescale 1ns / 1ps
// Minimal test: 6 instructions that write 0xCAFEBABE to 0x1FFC.
// LUI 0xCAFEC000 + ADDI 0xEBE (sign-ext) = 0xCAFEBABE.

module tb_minimal_done;
  reg clk, reset;
  integer cycles;
  rv_pl dut (.clk(clk), .rst_n(reset));
  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    dut.IMEM.RAM[0] = 32'hcafec737;       // LUI x14 -> 0xCAFEC000
    dut.IMEM.RAM[1] = 32'hABE70713;       // ADDI x14, x14, 0xabe -> 0xCAFEC000+0xFFFFFABE = 0xCAFEBABE
    dut.IMEM.RAM[2] = 32'h000207b7;       // LUI x15, 0x2 -> 0x2000
    dut.IMEM.RAM[3] = 32'hffc78793;       // ADDI x15, x15, -4 -> 0x1FFC
    dut.IMEM.RAM[4] = 32'h00000013;       // NOP
    dut.IMEM.RAM[5] = 32'h00e7a023;       // SW x14, 0(x15)
    dut.DMEM.RAM[255] = 32'b0;
    reset = 0; #20; reset = 1;
    for (cycles = 0; cycles < 500; cycles = cycles + 1) @(posedge clk);
    if (dut.DMEM.RAM[255] == 32'hCAFEBABE)
      $display("MINIMAL_DONE: PASS - 0xCAFEBABE written to DMEM[255]");
    else begin
      $display("MINIMAL_DONE: FAIL - DMEM[255] = %h (expected CAFEBABE)", dut.DMEM.RAM[255]);
      if (dut.DMEM.RAM[0] == 32'hCAFEBABE)
        $display("  (store went to DMEM[0] instead - address may be 0)");
    end
    $finish;
  end
endmodule
