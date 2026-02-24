/**
 * rv_pl.v – 5-Stage Pipelined RISC-V Core (RV32I)
 *
 * Top-level pipeline integrator with synchronous BRAM interfaces for both
 * instruction and data memory.  Implements full forwarding, hazard
 * detection, and BRAM latency compensation.
 *
 * Pipeline stages:  IF → ID → EX → MA → WB
 * Memory model:     Synchronous BRAM (1-cycle read latency)
 */

`timescale 1ns/1ps

module rv_pl(
  input  wire clk,
  input  wire resetn,

  // signals for instr memory BRAM
  output  wire        imem_clk,
  output  wire        imem_enb,
  output  wire        imem_rst,
  output  wire [3:0]  imem_web,
  output  wire [31:0] imem_addr,
  output  wire [31:0] imem_wd,
  input   wire [31:0] imem_rd,

  // signals for data memory BRAM
  output wire         dmem_clk,
  output wire         dmem_rst,
  output  wire        dmem_enb,
  output  wire [3:0]  dmem_web,
  output  wire [31:0] dmem_addr,
  output  wire [31:0] dmem_wd,
  input   wire [31:0] dmem_rd
);

  wire rst_n;
  assign rst_n = resetn;

  // ========================================================================
  // IMEM BRAM LATENCY COMPENSATION
  // ========================================================================
  // Synchronous BRAM: address captured at posedge N, data available at
  // posedge N+1.  pc_f tracks the PC that was presented to BRAM last
  // cycle, keeping the instruction and its PC aligned in PLR1.
  // fetch_valid gates the pipeline for one cycle after reset while the
  // first BRAM read completes.

  reg         fetch_valid;
  reg  [31:0] pc_f;           // PC presented to BRAM last cycle

  always @(posedge clk) begin
    if (!rst_n) begin
      fetch_valid <= 1'b0;
      pc_f        <= 32'b0;
    end else begin
      fetch_valid <= 1'b1;    // Valid 1 cycle after reset
      pc_f        <= pc;      // Track which PC went to BRAM
    end
  end

  wire [31:0] instr_f = imem_rd;  // BRAM output (1-cycle delayed by hardware)

  // ========================================================================
  // BRAM RECOVERY FLUSH
  // ========================================================================
  // After a stall release or branch/jump redirect the BRAM still outputs
  // the stale instruction for one cycle.  branch_recovery and
  // stall_recovery each detect their respective transition and flush
  // PLR1 for that single recovery cycle.
  // ========================================================================
  reg was_stalled;
  reg stall_recovery;
  reg branch_recovery;

  always @(posedge clk) begin
    if (!rst_n) begin
      was_stalled     <= 1'b1;
      stall_recovery  <= 1'b0;
      branch_recovery <= 1'b0;
    end else begin
      was_stalled     <= stall;
      stall_recovery  <= was_stalled && !stall;
      branch_recovery <= flush_plr1_hz;
    end
  end

  wire bram_recovery = stall_recovery || branch_recovery;

  // ========================================================================

  // IF stage
  reg  [31:0] pc;
  wire [31:0] pc_p4 = pc + 32'd4;

  // Pipeline registers
  wire [31:0] d_instr;
  wire [31:0] d_pc;
  wire [31:0] d_pc_p4;

  wire [31:0] e_instr;
  wire [31:0] e_pc;
  wire [31:0] e_pc_p4;
  wire [31:0] e_ext;
  wire [31:0] e_rd1;
  wire [31:0] e_rd2;
  wire [4:0]  e_rs1;
  wire [4:0]  e_rs2;
  wire [4:0]  e_rd;
  wire        e_we_rf;
  wire        e_we_dm;
  wire [1:0]  e_sel_result;
  wire [3:0]  e_alu_ctrl;
  wire        e_sel_alu_src_a;
  wire        e_sel_alu_src_b;
  wire        e_branch;
  wire        e_jump;

  wire [31:0] m_instr;
  wire [31:0] m_alu_o;
  wire [31:0] m_dm_wd;
  wire [31:0] m_pc_p4;
  wire [31:0] m_ext;
  wire [4:0]  m_rd;
  wire        m_we_rf;
  wire        m_we_dm;
  wire [1:0]  m_sel_result;

  wire [31:0] w_instr;
  wire [31:0] w_alu_o;
  wire [31:0] w_dm_rd;
  wire [31:0] w_pc_p4;
  wire [31:0] w_ext;
  wire [4:0]  w_rd;
  wire        w_we_rf;
  wire [1:0]  w_sel_result;

  // IMEM port assignments (read-only)
  assign imem_enb  = 1'b1;
  assign imem_web  = 4'b0000;
  assign imem_addr = pc;
  assign imem_wd   = 32'b0;
  assign imem_clk  = clk;
  assign imem_rst  = ~rst_n;

  // ========================================================================
  // DMEM BRAM LATENCY COMPENSATION
  // ========================================================================
  // Address driven from EX stage (one cycle before MA) so the BRAM read
  // data is available at MA for PLR4 capture and M-stage forwarding.
  // Stores also commit from EX for the same latency reason.
  // ========================================================================
  wire [31:0] dm_rd;
  assign dmem_enb  = 1'b1;
  assign dmem_web  = e_we_dm ? 4'b1111 : 4'b0000;
  assign dmem_addr = e_alu_o;
  assign dmem_wd   = e_dm_wd;
  assign dm_rd     = dmem_rd;
  assign dmem_clk  = clk;
  assign dmem_rst  = ~rst_n;

  // ========================================================================
  // ID STAGE – DECODE
  // ========================================================================
  wire [4:0] d_rs1 = d_instr[19:15];
  wire [4:0] d_rs2 = d_instr[24:20];
  wire [4:0] d_rd  = d_instr[11:7];

  wire        d_we_rf;
  wire        d_we_dm;
  wire [1:0]  d_sel_result;
  wire [3:0]  d_alu_ctrl;
  wire        d_sel_alu_src_a;
  wire        d_sel_alu_src_b;
  wire [2:0]  d_sel_ext;
  wire        d_branch;
  wire        d_jump;
  wire        d_uses_rs2;

  decoder DEC (
    .instr(d_instr),
    .we_rf(d_we_rf),
    .we_dm(d_we_dm),
    .sel_result(d_sel_result),
    .alu_ctrl(d_alu_ctrl),
    .sel_alu_src_a(d_sel_alu_src_a),
    .sel_alu_src_b(d_sel_alu_src_b),
    .sel_ext(d_sel_ext),
    .branch(d_branch),
    .jump(d_jump),
    .uses_rs2(d_uses_rs2)
  );

  wire [31:0] d_ext;
  sign_ext EXT (
    .instr(d_instr),
    .sel_ext(d_sel_ext),
    .imm(d_ext)
  );

  // ========================================================================
  // REGISTER FILE
  // ========================================================================
  wire [31:0] rf_rd1;
  wire [31:0] rf_rd2;
  reg_file RF (
    .clk(clk),
    .rst_n(rst_n),
    .we(w_we_rf),
    .ra1(d_rs1),
    .ra2(d_rs2),
    .wa(w_rd),
    .wd((w_sel_result == 2'b00) ? w_alu_o :
        (w_sel_result == 2'b01) ? w_dm_rd :
        (w_sel_result == 2'b10) ? w_pc_p4 :
        w_ext),
    .rd1(rf_rd1),
    .rd2(rf_rd2)
  );

  // ========================================================================
  // HAZARD UNIT
  // ========================================================================
  wire        e_is_load = (e_sel_result == 2'b01) && e_we_rf;
  wire        m_is_load = (m_sel_result == 2'b01) && m_we_rf;
  wire        e_branch_taken;
  wire        stall;
  wire        flush_plr1_hz;   // raw flush from hazard unit
  wire        flush_plr2;
  wire [1:0]  forward_a;
  wire [1:0]  forward_b;

  hazard_unit HZD (
    .d_rs1(d_rs1),
    .d_rs2(d_rs2),
    .d_uses_rs2(d_uses_rs2),
    .e_rs1(e_rs1),
    .e_rs2(e_rs2),
    .e_rd(e_rd),
    .e_is_load(e_is_load),
    .m_rd(m_rd),
    .m_we_rf(m_we_rf),
    .m_is_load(m_is_load),
    .w_rd(w_rd),
    .w_we_rf(w_we_rf),
    .branch_taken(e_branch_taken),
    .jump(e_jump),
    .fetch_valid(fetch_valid),
    .forward_a(forward_a),
    .forward_b(forward_b),
    .stall(stall),
    .flush_plr1(flush_plr1_hz),
    .flush_plr2(flush_plr2)
  );

  // PLR1 flush: hazard-unit request OR BRAM recovery bubble
  wire flush_plr1 = flush_plr1_hz || bram_recovery;

  // ========================================================================
  // PIPELINE REGISTERS
  // ========================================================================
  
  // IF/ID Pipeline Register (PLR1)
  plr1 PLR1 (
    .clk(clk),
    .rst_n(rst_n),
    .en(!stall),
    .clr(flush_plr1),
    .instr_in(instr_f),
    .pc_in(pc_f),
    .pc_p4_in(pc_f + 32'd4),
    .instr_out(d_instr),
    .pc_out(d_pc),
    .pc_p4_out(d_pc_p4)
  );

  // ID/EX Pipeline Register (PLR2)
  plr2 PLR2 (
    .clk(clk),
    .rst_n(rst_n),
    .clr(flush_plr2),
    .instr_in(d_instr),
    .pc_in(d_pc),
    .pc_p4_in(d_pc_p4),
    .ext_in(d_ext),
    .rd1_in(rf_rd1),
    .rd2_in(rf_rd2),
    .rs1_in(d_rs1),
    .rs2_in(d_rs2),
    .rd_in(d_rd),
    .we_rf_in(d_we_rf),
    .we_dm_in(d_we_dm),
    .sel_result_in(d_sel_result),
    .alu_ctrl_in(d_alu_ctrl),
    .sel_alu_src_a_in(d_sel_alu_src_a),
    .sel_alu_src_b_in(d_sel_alu_src_b),
    .branch_in(d_branch),
    .jump_in(d_jump),
    .instr_out(e_instr),
    .pc_out(e_pc),
    .pc_p4_out(e_pc_p4),
    .ext_out(e_ext),
    .rd1_out(e_rd1),
    .rd2_out(e_rd2),
    .rs1_out(e_rs1),
    .rs2_out(e_rs2),
    .rd_out(e_rd),
    .we_rf_out(e_we_rf),
    .we_dm_out(e_we_dm),
    .sel_result_out(e_sel_result),
    .alu_ctrl_out(e_alu_ctrl),
    .sel_alu_src_a_out(e_sel_alu_src_a),
    .sel_alu_src_b_out(e_sel_alu_src_b),
    .branch_out(e_branch),
    .jump_out(e_jump)
  );

  // ========================================================================
  // EX STAGE – ALU & FORWARDING
  // ========================================================================

  // M-stage forward mux (includes dm_rd for loads)
  wire [31:0] m_forward = (m_sel_result == 2'b00) ? m_alu_o :
                          (m_sel_result == 2'b10) ? m_pc_p4 :
                          (m_sel_result == 2'b11) ? m_ext :
                          dm_rd;

  wire [31:0] w_result = (w_sel_result == 2'b00) ? w_alu_o :
                         (w_sel_result == 2'b01) ? w_dm_rd :
                         (w_sel_result == 2'b10) ? w_pc_p4 :
                         w_ext;

  wire [31:0] fwd_a_val = (forward_a == 2'b10) ? m_forward :
                          (forward_a == 2'b01) ? w_result :
                          e_rd1;
  wire [31:0] fwd_b_val = (forward_b == 2'b10) ? m_forward :
                          (forward_b == 2'b01) ? w_result :
                          e_rd2;

  wire [31:0] alu_in1 = e_sel_alu_src_a ? e_pc : fwd_a_val;
  wire [31:0] alu_in2 = e_sel_alu_src_b ? e_ext : fwd_b_val;

  wire [31:0] e_alu_o;
  wire        e_zero;
  alu ALU (
    .a(alu_in1),
    .b(alu_in2),
    .alu_ctrl(e_alu_ctrl),
    .result(e_alu_o),
    .zero(e_zero)
  );

  assign e_branch_taken = e_branch && e_zero;
  wire [31:0] e_target_pc = e_pc + e_ext;

  // Store data with W-stage forwarding
  wire [31:0] e_dm_wd = (e_we_dm && w_we_rf && (w_rd != 5'd0) && (w_rd == e_rs2))
                        ? w_result : fwd_b_val;

  // EX/MA Pipeline Register (PLR3)
  plr3 PLR3 (
    .clk(clk),
    .rst_n(rst_n),
    .instr_in(e_instr),
    .alu_o_in(e_alu_o),
    .dm_wd_in(e_dm_wd),
    .pc_p4_in(e_pc_p4),
    .ext_in(e_ext),
    .rd_in(e_rd),
    .we_rf_in(e_we_rf),
    .we_dm_in(e_we_dm),
    .sel_result_in(e_sel_result),
    .instr_out(m_instr),
    .alu_o_out(m_alu_o),
    .dm_wd_out(m_dm_wd),
    .pc_p4_out(m_pc_p4),
    .ext_out(m_ext),
    .rd_out(m_rd),
    .we_rf_out(m_we_rf),
    .we_dm_out(m_we_dm),
    .sel_result_out(m_sel_result)
  );

  // MA/WB Pipeline Register (PLR4)
  plr4 PLR4 (
    .clk(clk),
    .rst_n(rst_n),
    .instr_in(m_instr),
    .alu_o_in(m_alu_o),
    .dm_rd_in(dm_rd),
    .pc_p4_in(m_pc_p4),
    .ext_in(m_ext),
    .rd_in(m_rd),
    .we_rf_in(m_we_rf),
    .sel_result_in(m_sel_result),
    .instr_out(w_instr),
    .alu_o_out(w_alu_o),
    .dm_rd_out(w_dm_rd),
    .pc_p4_out(w_pc_p4),
    .ext_out(w_ext),
    .rd_out(w_rd),
    .we_rf_out(w_we_rf),
    .sel_result_out(w_sel_result)
  );

  // ========================================================================
  // PC UPDATE
  // ========================================================================
  wire [31:0] pc_next = (e_branch_taken || e_jump) ? e_target_pc : pc_p4;

  always @(posedge clk) begin
    if (!rst_n)
      pc <= 32'b0;
    else if (!stall)
      pc <= pc_next;
  end

endmodule
