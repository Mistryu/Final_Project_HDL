`timescale 1ns/1ps

module dmem #(
  parameter integer MEM_DEPTH = 256
)(
  input  wire        clk,
  input  wire        we,
  input  wire [31:0] addr,
  input  wire [31:0] wd,
  output wire [31:0] rd
);
  // Data memory (word-addressed); index masked to MEM_DEPTH so e.g. 0x1FFC -> 255
  localparam integer ADDR_BITS = (MEM_DEPTH <= 1) ? 1 : $clog2(MEM_DEPTH);
  reg [31:0] RAM [0:MEM_DEPTH-1];
  wire [ADDR_BITS-1:0] word_index = addr[ADDR_BITS+1:2];

  always @(posedge clk) begin
    if (we)
      RAM[word_index] <= wd;
  end

  assign rd = RAM[word_index];

endmodule
