`timescale 1ns/1ps

module plr1 (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        en,
  input  wire        clr,
  input  wire [31:0] instr_in,
  input  wire [31:0] pc_in,
  input  wire [31:0] pc_p4_in,
  output reg  [31:0] instr_out,
  output reg  [31:0] pc_out,
  output reg  [31:0] pc_p4_out
);
  always @(posedge clk) begin
    if (!rst_n) begin
      instr_out <= 32'b0;
      pc_out    <= 32'b0;
      pc_p4_out <= 32'b0;
    end else if (clr) begin
      instr_out <= 32'b0;
      pc_out    <= 32'b0;
      pc_p4_out <= 32'b0;
    end else if (en) begin
      instr_out <= instr_in;
      pc_out    <= pc_in;
      pc_p4_out <= pc_p4_in;
    end
  end

endmodule
