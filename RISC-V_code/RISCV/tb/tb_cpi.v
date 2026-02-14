`timescale 1ns/1ps

module tb_cpi;
  reg clk;
  reg reset;
  integer cycles = 0;
  integer instrs = 0;

  rv_pl dut (
    .clk(clk),
    .rst_n(reset)
  );

  wire [31:0] w_instr = dut.w_instr;

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    $readmemh("programs/test_cpi.hex", dut.IMEM.RAM);
    dut.DMEM.RAM[0] = 32'h000000AA;
    dut.DMEM.RAM[1] = 32'h00000000;

    reset = 0;
    #20;
    reset = 1;

    while (dut.DMEM.RAM[1] !== 32'h00000007) begin
      @(posedge clk);
      cycles = cycles + 1;
      if (w_instr != 32'b0 && w_instr != 32'h00000013)
        instrs = instrs + 1;
      if (cycles > 500) begin
        $display("FAIL: CPI test timeout");
        $finish;
      end
    end

    $display("CPI test done: cycles=%0d instrs=%0d CPI=%0f",
             cycles, instrs, (instrs != 0) ? (cycles * 1.0 / instrs) : 0.0);
    $finish;
  end

endmodule
