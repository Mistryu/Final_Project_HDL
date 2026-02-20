`timescale 1ns/1ps

module plr2 (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        clr,
  input  wire [31:0] instr_in,
  input  wire [31:0] pc_in,
  input  wire [31:0] pc_p4_in,
  input  wire [31:0] ext_in,
  input  wire [31:0] rd1_in,
  input  wire [31:0] rd2_in,
  input  wire [4:0]  rs1_in,
  input  wire [4:0]  rs2_in,
  input  wire [4:0]  rd_in,
  input  wire        we_rf_in,
  input  wire        we_dm_in,
  input  wire [1:0]  sel_result_in,
  input  wire [3:0]  alu_ctrl_in,
  input  wire        sel_alu_src_a_in,
  input  wire        sel_alu_src_b_in,
  input  wire        branch_in,
  input  wire        jump_in,
  output reg  [31:0] instr_out,
  output reg  [31:0] pc_out,
  output reg  [31:0] pc_p4_out,
  output reg  [31:0] ext_out,
  output reg  [31:0] rd1_out,
  output reg  [31:0] rd2_out,
  output reg  [4:0]  rs1_out,
  output reg  [4:0]  rs2_out,
  output reg  [4:0]  rd_out,
  output reg         we_rf_out,
  output reg         we_dm_out,
  output reg  [1:0]  sel_result_out,
  output reg  [3:0]  alu_ctrl_out,
  output reg         sel_alu_src_a_out,
  output reg         sel_alu_src_b_out,
  output reg         branch_out,
  output reg         jump_out
);
  always @(posedge clk) begin
    if (!rst_n) begin
      instr_out        <= 32'b0;
      pc_out           <= 32'b0;
      pc_p4_out        <= 32'b0;
      ext_out          <= 32'b0;
      rd1_out          <= 32'b0;
      rd2_out          <= 32'b0;
      rs1_out          <= 5'b0;
      rs2_out          <= 5'b0;
      rd_out           <= 5'b0;
      we_rf_out        <= 1'b0;
      we_dm_out        <= 1'b0;
      sel_result_out   <= 2'b0;
      alu_ctrl_out     <= 4'b0;
      sel_alu_src_a_out <= 1'b0;
      sel_alu_src_b_out <= 1'b0;
      branch_out       <= 1'b0;
      jump_out         <= 1'b0;
    end else if (clr) begin
      instr_out        <= 32'b0;
      pc_out           <= 32'b0;
      pc_p4_out        <= 32'b0;
      ext_out          <= 32'b0;
      rd1_out          <= 32'b0;
      rd2_out          <= 32'b0;
      rs1_out          <= 5'b0;
      rs2_out          <= 5'b0;
      rd_out           <= 5'b0;
      we_rf_out        <= 1'b0;
      we_dm_out        <= 1'b0;
      sel_result_out   <= 2'b0;
      alu_ctrl_out     <= 4'b0;
      sel_alu_src_a_out <= 1'b0;
      sel_alu_src_b_out <= 1'b0;
      branch_out       <= 1'b0;
      jump_out         <= 1'b0;
    end else begin
      instr_out        <= instr_in;
      pc_out           <= pc_in;
      pc_p4_out        <= pc_p4_in;
      ext_out          <= ext_in;
      rd1_out          <= rd1_in;
      rd2_out          <= rd2_in;
      rs1_out          <= rs1_in;
      rs2_out          <= rs2_in;
      rd_out           <= rd_in;
      we_rf_out        <= we_rf_in;
      we_dm_out        <= we_dm_in;
      sel_result_out   <= sel_result_in;
      alu_ctrl_out     <= alu_ctrl_in;
      sel_alu_src_a_out <= sel_alu_src_a_in;
      sel_alu_src_b_out <= sel_alu_src_b_in;
      branch_out       <= branch_in;
      jump_out         <= jump_in;
    end
  end

endmodule
