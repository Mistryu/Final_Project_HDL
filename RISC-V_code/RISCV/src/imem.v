`timescale 1ns/1ps

module imem #(
  parameter integer MEM_DEPTH = 256
)(
  input  wire [31:0] addr,
  output wire [31:0] rd
);
  // Instruction memory (word-addressed); index masked to MEM_DEPTH like dmem
  localparam integer ADDR_BITS = (MEM_DEPTH <= 1) ? 1 : $clog2(MEM_DEPTH);
  reg [31:0] RAM [0:MEM_DEPTH-1];
  wire [ADDR_BITS-1:0] word_index = addr[ADDR_BITS+1:2];

  assign rd = RAM[word_index];

endmodule
