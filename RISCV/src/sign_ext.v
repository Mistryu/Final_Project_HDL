`timescale 1ns/1ps

module sign_ext (
  input  wire [31:0] instr,
  input  wire [2:0]  sel_ext,
  output reg  [31:0] imm
);
  localparam EXT_I = 3'd0;
  localparam EXT_S = 3'd1;
  localparam EXT_B = 3'd2;
  localparam EXT_U = 3'd3;
  localparam EXT_J = 3'd4;

  always @(*) begin
    case (sel_ext)
      EXT_I: imm = {{20{instr[31]}}, instr[31:20]};
      EXT_S: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
      EXT_B: imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
      EXT_U: imm = {instr[31:12], 12'b0};
      EXT_J: imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
      default: imm = 32'b0;
    endcase
  end

endmodule
