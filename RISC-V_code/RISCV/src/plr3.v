`timescale 1ns/1ps

module plr3 (
  input  wire        clk,
  input  wire        rst_n,
  input  wire [31:0] instr_in,
  input  wire [31:0] alu_o_in,
  input  wire [31:0] dm_wd_in,
  input  wire [31:0] pc_p4_in,
  input  wire [31:0] ext_in,
  input  wire [4:0]  rd_in,
  input  wire        we_rf_in,
  input  wire        we_dm_in,
  input  wire [1:0]  sel_result_in,
  output reg  [31:0] instr_out,
  output reg  [31:0] alu_o_out,
  output reg  [31:0] dm_wd_out,
  output reg  [31:0] pc_p4_out,
  output reg  [31:0] ext_out,
  output reg  [4:0]  rd_out,
  output reg         we_rf_out,
  output reg         we_dm_out,
  output reg  [1:0]  sel_result_out
);
  always @(posedge clk) begin
    if (!rst_n) begin
      instr_out      <= 32'b0;
      alu_o_out      <= 32'b0;
      dm_wd_out      <= 32'b0;
      pc_p4_out      <= 32'b0;
      ext_out        <= 32'b0;
      rd_out         <= 5'b0;
      we_rf_out      <= 1'b0;
      we_dm_out      <= 1'b0;
      sel_result_out <= 2'b0;
    end else begin
      instr_out      <= instr_in;
      alu_o_out      <= alu_o_in;
      dm_wd_out      <= dm_wd_in;
      pc_p4_out      <= pc_p4_in;
      ext_out        <= ext_in;
      rd_out         <= rd_in;
      we_rf_out      <= we_rf_in;
      we_dm_out      <= we_dm_in;
      sel_result_out <= sel_result_in;
    end
  end

endmodule
