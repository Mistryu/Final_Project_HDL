`timescale 1ns/1ps

module hazard_unit (
  input  wire [4:0] d_rs1,
  input  wire [4:0] d_rs2,
  input  wire       d_uses_rs2,
  input  wire [4:0] e_rs1,
  input  wire [4:0] e_rs2,
  input  wire [4:0] e_rd,
  input  wire       e_is_load,
  input  wire [4:0] m_rd,
  input  wire       m_we_rf,
  input  wire       m_is_load,
  input  wire [4:0] w_rd,
  input  wire       w_we_rf,
  input  wire       branch_taken,
  input  wire       jump,
  input  wire       fetch_valid,
  output reg  [1:0] forward_a,
  output reg  [1:0] forward_b,
  output reg        stall,
  output reg        flush_plr1,
  output reg        flush_plr2
);
  always @(*) begin
    forward_a = 2'b00;
    forward_b = 2'b00;
    stall     = !fetch_valid;
    flush_plr1 = 1'b0;
    flush_plr2 = 1'b0;

    // Forward from M (including load result dm_rd) so load-use completes after one stall
    if (m_we_rf && (m_rd != 5'd0) && (m_rd == e_rs1))
      forward_a = 2'b10;
    if (m_we_rf && (m_rd != 5'd0) && (m_rd == e_rs2))
      forward_b = 2'b10;

    if (w_we_rf && (w_rd != 5'd0) && (w_rd == e_rs1) && (forward_a == 2'b00))
      forward_a = 2'b01;
    if (w_we_rf && (w_rd != 5'd0) && (w_rd == e_rs2) && (forward_b == 2'b00))
      forward_b = 2'b01;

    // Load-use: stall one cycle AND flush PLR2 to insert bubble in EX.
    // This prevents the dependent instruction from entering EX before the
    // load result is available for forwarding from MEM stage.
    if (e_is_load && (e_rd != 5'd0) &&
        ((e_rd == d_rs1) || (d_uses_rs2 && (e_rd == d_rs2)))) begin
      stall     = 1'b1;
      flush_plr2 = 1'b1;   // Insert bubble (prevents duplicate EX entry)
    end

    if (branch_taken || jump) begin
      flush_plr1 = 1'b1;
      flush_plr2 = 1'b1;
    end
  end

endmodule
