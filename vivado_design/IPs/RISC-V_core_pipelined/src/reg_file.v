`timescale 1ns/1ps

module reg_file (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        we,
  input  wire [4:0]  ra1,
  input  wire [4:0]  ra2,
  input  wire [4:0]  wa,
  input  wire [31:0] wd,
  output wire [31:0] rd1,
  output wire [31:0] rd2
);
  reg [31:0] regs [0:31];
  integer i;

  always @(posedge clk) begin
    if (!rst_n) begin
      for (i = 0; i < 32; i = i + 1)
        regs[i] <= 32'b0;
    end else begin
      if (we && (wa != 5'd0))
        regs[wa] <= wd;
    end
  end

  // Bypass: if reading same reg as WB write (same cycle), use write data
  assign rd1 = (ra1 == 5'd0) ? 32'b0 : ((we && (wa != 5'd0) && (ra1 == wa)) ? wd : regs[ra1]);
  assign rd2 = (ra2 == 5'd0) ? 32'b0 : ((we && (wa != 5'd0) && (ra2 == wa)) ? wd : regs[ra2]);

endmodule
