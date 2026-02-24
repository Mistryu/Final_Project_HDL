`timescale 1ns / 1ps
// End-to-end testbench for the *new* rv_pl interface with explicit BRAM ports.
// This is a close copy of the old tb_e2e_python_flow.v, but instead of
// poking into hierarchical memory arrays we instantiate a simple behavioral
// BRAM model that drives the imem/dmem ports on the DUT.  The model allows us
// to load instructions and data just like the Python flow and keeps the TB
// independent of the implementation details inside rv_pl.

module tb_e2e_python_flow_bram;
  parameter HEX_FILE = "programs/bubble_sort_clean.hex";
  
  reg clk;
  reg reset;
  integer i, errors;
  integer cycles;
  integer imem_words;
  integer hex_fd;
  integer hex_word;
  integer scan_ok;
  reg [1023:0] hex_line;

  localparam MAX_CYCLES = 10_000;
  localparam ARRAY_SIZE = 32;
  localparam MAGIC_SUCCESS = 32'hCAFEBABE;
  localparam STATUS_DMEM_INDEX = 2047;  // 0x1FFC / 4 = word address 2047 (INTENDED)

  // ------------------------------------------------------------------
  // wires for BRAM interfaces
  // ------------------------------------------------------------------
  wire        imem_clk;
  wire        imem_enb;
  wire        imem_rst;
  wire [3:0]  imem_web;
  wire [31:0] imem_addr;
  wire [31:0] imem_wd;
  wire [31:0] imem_rd;

  wire        dmem_clk;
  wire        dmem_rst;
  wire        dmem_enb;
  wire [3:0]  dmem_web;
  wire [31:0] dmem_addr;
  wire [31:0] dmem_wd;
  wire [31:0] dmem_rd;

  // DUT instantiation using new port list
  rv_pl dut (
    .clk(clk),
    .resetn(reset),

    .imem_clk(imem_clk),
    .imem_enb(imem_enb),
    .imem_rst(imem_rst),
    .imem_web(imem_web),
    .imem_addr(imem_addr),
    .imem_wd(imem_wd),
    .imem_rd(imem_rd),

    .dmem_clk(dmem_clk),
    .dmem_rst(dmem_rst),
    .dmem_enb(dmem_enb),
    .dmem_web(dmem_web),
    .dmem_addr(dmem_addr),
    .dmem_wd(dmem_wd),
    .dmem_rd(dmem_rd)
  );

  // ------------------------------------------------------------------
  // simple BRAM models for IMEM and DMEM
  // ------------------------------------------------------------------
  simple_bram #(.DEPTH(1024), .name("IMEM")) IMEM_MODEL (
    .clk(imem_clk),
    .rst_n(!imem_rst),
    .enb(imem_enb),
    .web(imem_web),
    .addr(imem_addr),
    .wd(imem_wd),
    .rd(imem_rd)
  );

  simple_bram #(.DEPTH(4096), .name("DMEM")) DMEM_MODEL (
    .clk(dmem_clk),
    .rst_n(!dmem_rst),
    .enb(dmem_enb),
    .web(dmem_web),
    .addr(dmem_addr),
    .wd(dmem_wd),
    .rd(dmem_rd)
  );

  // ------------------------------------------------------------------
  // clock generator
  // ------------------------------------------------------------------
  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    cycles = 0;
    errors = 0;

    // Initialize BRAM contents to 0 to avoid X propagation on unused locations.
    for (i = 0; i < 1024; i = i + 1)
      IMEM_MODEL.mem[i] = 32'b0;
    for (i = 0; i < 4096; i = i + 1)
      DMEM_MODEL.mem[i] = 32'b0;

    // ---- PHASE 1: Same as Python - load instructions at 0x0000, inject data at 0x1000 ----
    $display("E2E (bram): Loading instructions from %s -> IMEM_MODEL.mem", HEX_FILE);
    hex_fd = $fopen(HEX_FILE, "r");
    if (hex_fd == 0) begin
      $fatal(1, "E2E (bram): ERROR - Unable to open hex file: %s", HEX_FILE);
    end
    imem_words = 0;
    while ($fgets(hex_line, hex_fd)) begin
      scan_ok = $sscanf(hex_line, "%h", hex_word);
      if (scan_ok == 1)
        imem_words = imem_words + 1;
    end
    $fclose(hex_fd);

    if (imem_words <= 0) begin
      $fatal(1, "E2E (bram): ERROR - No words found in hex file: %s", HEX_FILE);
    end

    $display("E2E (bram): Detected %0d IMEM words in hex", imem_words);
    $readmemh(HEX_FILE, IMEM_MODEL.mem, 0, imem_words - 1);

    // // Verify instructions were loaded
    // $display("E2E (bram): Verifying instruction memory contents:");
    // for (i = 0; i < 30; i = i + 1) begin
    //   $display("  IMEM[%0d] = 0x%h", i, IMEM_MODEL.mem[i]);
    // end

    $display("E2E (bram): Injecting 32 integers (script 0x0) -> DMEM_MODEL.mem[0..31]");
    for (i = 0; i < ARRAY_SIZE; i = i + 1)
      DMEM_MODEL.mem[0 + i] = (ARRAY_SIZE - 1 - i) + 1;  // 32,31,...,1 -> golden 1,2,...,32

    $display("E2E (bram): Resetting status flag (script 0x1FFC) -> DMEM_MODEL.mem[2047]");
    DMEM_MODEL.mem[STATUS_DMEM_INDEX] = 32'b0;

    $display("E2E (bram): Releasing reset, running until DONE or timeout");
    reset = 0;
    #20;
    reset = 1;

    // ---- PHASE 2: Run until 0xCAFEBABE at 0x1FFC (poll 0x1FFC) ----
    begin : run_loop
      repeat (MAX_CYCLES) begin
        @(posedge clk);
        cycles = cycles + 1;
        if (reset && (dut.pc > (imem_words * 4))) begin
          $fatal(1, "E2E (bram): FAIL - PC beyond program: PC=0x%h (max 0x%h)",
                 dut.pc, (imem_words * 4));
        end
        if (DMEM_MODEL.mem[STATUS_DMEM_INDEX] == MAGIC_SUCCESS) begin
          $display("E2E (bram): SUCCESS flag (0xCAFEBABE) detected at 0x1FFC [word 2047] after %0d cycles", cycles);
          disable run_loop;
        end
      end
    end

    if (DMEM_MODEL.mem[STATUS_DMEM_INDEX] != MAGIC_SUCCESS) begin
      $display("E2E (bram): FAIL - Timeout: 0xCAFEBABE not seen at 0x1FFC after %0d cycles (read %h)", cycles, DMEM_MODEL.mem[STATUS_DMEM_INDEX]);
      errors = 1;
    end else begin
      // ---- PHASE 3: Read back sorted array (script reads from 0x0), verify ----
      $display("E2E (bram): Reading array from DMEM_MODEL.mem[0..31] (script 0x0)");
      for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
        if (DMEM_MODEL.mem[0 + i] !== (i + 1)) begin
          $display("E2E (bram): Mismatch at [%0d]: got %0d, expected %0d", i, DMEM_MODEL.mem[0 + i], i + 1);
          errors = errors + 1;
        end
      end
    end

    if (errors == 0)
      $display("E2E (bram): SUCCESS - Full flow OK: DONE detected, array sorted.");
    else
      $display("E2E (bram): FAILURE - %0d error(s).", errors);

    $finish;
  end

endmodule


// ------------------------------------------------------------------
// simple behavioral BRAM model used by the above testbench.  The
// memory depth can be changed via parameter.  The model responds on the
// rising edge of the clock and respects write-enable bytes (web).
//
// Note: the DUT expects a 1-cycle read latency, so the testbench does
// not add any extra delay here; the CPU handles that internally.
// ------------------------------------------------------------------
module simple_bram #(
  parameter name = "BRAM",
  parameter DEPTH = 256
)(
  input           clk,
  input           rst_n,
  input           enb,
  input  [3:0]    web,
  input  [31:0]   addr,
  input  [31:0]   wd,
  output reg [31:0] rd
);

  reg [31:0] mem [0:DEPTH-1];
  reg [31:0] rd_d1;  // Delayed read output to model 1-cycle BRAM latency
  integer idx;

  always @(posedge clk) begin
    if (!rst_n) begin
      // optionally clear memory
      rd_d1 <= 32'b0;
    end else if (enb) begin
      idx = addr[31:2];          // word address
      if (idx < 0 || idx >= DEPTH) begin
        // Out-of-range: fatal on writes, warning on reads
        if (|web) begin
          $display("[%s] FATAL WRITE out of range: idx=%0d addr=0x%h", name, idx, addr);
          $fatal(1, "[%s] Write address out of range: idx=%0d (depth=%0d) addr=0x%h", name, idx, DEPTH, addr);
        end
        // Read out-of-range: return 0 (matches real BRAM wrap/garbage)
        rd_d1 <= 32'b0;
      end else begin
        if (|web) begin
          if (web[0]) mem[idx][7:0]   = wd[7:0];
          if (web[1]) mem[idx][15:8]  = wd[15:8];
          if (web[2]) mem[idx][23:16] = wd[23:16];
          if (web[3]) mem[idx][31:24] = wd[31:24];
          $display("[%s] Write mem[%0d] = 0x%08h (addr=0x%h)", name, idx, wd, addr);
        end
        rd_d1 <= mem[idx];
      end
    end
  end

  // Output is delayed by 1 cycle to match hardware BRAM latency
  assign rd = rd_d1;

endmodule
