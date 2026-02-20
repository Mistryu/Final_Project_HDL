`timescale 1ns/1ps

module decoder (
  input  wire [31:0] instr,
  output reg         we_rf,
  output reg         we_dm,
  output reg  [1:0]  sel_result,
  output reg  [3:0]  alu_ctrl,
  output reg         sel_alu_src_a,
  output reg         sel_alu_src_b,
  output reg  [2:0]  sel_ext,
  output reg         branch,
  output reg         jump,
  output reg         uses_rs2
);
  localparam OPC_R    = 7'b0110011;
  localparam OPC_I    = 7'b0010011;
  localparam OPC_LW   = 7'b0000011;
  localparam OPC_SW   = 7'b0100011;
  localparam OPC_BEQ  = 7'b1100011;
  localparam OPC_JAL  = 7'b1101111;
  localparam OPC_LUI  = 7'b0110111;

  localparam EXT_I = 3'd0;
  localparam EXT_S = 3'd1;
  localparam EXT_B = 3'd2;
  localparam EXT_U = 3'd3;
  localparam EXT_J = 3'd4;

  localparam ALU_ADD  = 4'b0000;
  localparam ALU_SUB  = 4'b0001;
  localparam ALU_AND  = 4'b0010;
  localparam ALU_OR   = 4'b0011;
  localparam ALU_XOR  = 4'b0100;
  localparam ALU_SLL  = 4'b0101;
  localparam ALU_SRL  = 4'b0110;
  localparam ALU_SRA  = 4'b0111;
  localparam ALU_SLT  = 4'b1000;
  localparam ALU_SLTU = 4'b1001;

  wire [6:0] opcode = instr[6:0];
  wire [2:0] funct3 = instr[14:12];
  wire [6:0] funct7 = instr[31:25];

  always @(*) begin
    we_rf        = 1'b0;
    we_dm        = 1'b0;
    sel_result   = 2'b00; // 00=ALU, 01=DMEM, 10=PC+4, 11=IMM (LUI)
    alu_ctrl     = ALU_ADD;
    sel_alu_src_a = 1'b0; // 0=rs1, 1=PC
    sel_alu_src_b = 1'b0; // 0=rs2, 1=imm
    sel_ext      = EXT_I;
    branch       = 1'b0;
    jump         = 1'b0;
    uses_rs2     = 1'b0;

    case (opcode)
      OPC_R: begin
        we_rf      = 1'b1;
        uses_rs2   = 1'b1;
        sel_alu_src_b = 1'b0;
        case (funct3)
          3'b000: alu_ctrl = (funct7 == 7'h20) ? ALU_SUB : ALU_ADD;
          3'b001: alu_ctrl = ALU_SLL;
          3'b010: alu_ctrl = ALU_SLT;
          3'b011: alu_ctrl = ALU_SLTU;
          3'b100: alu_ctrl = ALU_XOR;
          3'b101: alu_ctrl = (funct7 == 7'h20) ? ALU_SRA : ALU_SRL;
          3'b110: alu_ctrl = ALU_OR;
          3'b111: alu_ctrl = ALU_AND;
          default: alu_ctrl = ALU_ADD;
        endcase
      end
      OPC_I: begin
        we_rf      = 1'b1;
        sel_alu_src_b = 1'b1;
        sel_ext    = EXT_I;
        case (funct3)
          3'b000: alu_ctrl = ALU_ADD; // addi
          3'b010: alu_ctrl = ALU_SLT; // slti
          3'b011: alu_ctrl = ALU_SLTU; // sltiu
          3'b100: alu_ctrl = ALU_XOR; // xori
          3'b110: alu_ctrl = ALU_OR;  // ori
          3'b111: alu_ctrl = ALU_AND; // andi
          3'b001: alu_ctrl = ALU_SLL; // slli
          3'b101: alu_ctrl = (funct7 == 7'h20) ? ALU_SRA : ALU_SRL; // srli/srai
          default: alu_ctrl = ALU_ADD;
        endcase
      end
      OPC_LW: begin
        we_rf      = 1'b1;
        sel_result = 2'b01;
        sel_alu_src_b = 1'b1;
        sel_ext    = EXT_I;
        alu_ctrl   = ALU_ADD;
      end
      OPC_SW: begin
        we_dm      = 1'b1;
        uses_rs2   = 1'b1;
        sel_alu_src_b = 1'b1;
        sel_ext    = EXT_S;
        alu_ctrl   = ALU_ADD;
      end
      OPC_BEQ: begin
        branch     = 1'b1;
        uses_rs2   = 1'b1;
        sel_ext    = EXT_B;
        alu_ctrl   = ALU_SUB;
      end
      OPC_JAL: begin
        jump       = 1'b1;
        we_rf      = 1'b1;
        sel_result = 2'b10;
        sel_alu_src_a = 1'b1; // PC
        sel_alu_src_b = 1'b1; // imm
        sel_ext    = EXT_J;
        alu_ctrl   = ALU_ADD;
      end
      OPC_LUI: begin
        we_rf      = 1'b1;
        sel_result = 2'b11;
        sel_ext    = EXT_U;
      end
      default: begin
        // NOP
      end
    endcase
  end

endmodule
