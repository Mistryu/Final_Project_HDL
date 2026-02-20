`timescale 1ns / 1ps

module tb_riscv_hazards;
    reg clk;
    reg reset;
    integer errors = 0;

    rv_pl dut (
        .clk(clk),
        .rst_n(reset)
    );

    // Spy Signals (Using your specific hierarchy)
    wire [31:0] x1_spy = dut.RF.regs[1];
    wire [31:0] x2_spy = dut.RF.regs[2];
    wire [31:0] x3_spy = dut.RF.regs[3];
    wire [31:0] x4_spy = dut.RF.regs[4];
    wire [31:0] x5_spy = dut.RF.regs[5];
    wire [31:0] x6_spy = dut.RF.regs[6];

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("local/hazards.vcd");
        $dumpvars(0, tb_riscv_hazards);
        $dumpvars(0, tb_riscv_hazards.dut.RF.regs[1]);
        $dumpvars(0, tb_riscv_hazards.dut.RF.regs[2]);
        $dumpvars(0, tb_riscv_hazards.dut.RF.regs[3]);
        $dumpvars(0, tb_riscv_hazards.dut.RF.regs[4]);
        $dumpvars(0, tb_riscv_hazards.dut.RF.regs[5]);
        $dumpvars(0, tb_riscv_hazards.dut.RF.regs[6]);
    end

    initial begin
        // Initialize Memory
        $readmemh("programs/test_hazards.hex", dut.IMEM.RAM);
        dut.DMEM.RAM[0] = 32'h000000AA;

        reset = 0;
        #20;
        reset = 1;

        #300;

        // -------------------------------------------------------------
        // Check 1: Data Hazard (Forwarding)
        // -------------------------------------------------------------
        if (x1_spy !== 10) begin
            $display("FAIL: x1 = %d (Expected 10)", x1_spy);
            errors = errors + 1;
        end

        if (x2_spy !== 30) begin
            $display("FAIL: Data Hazard x2 = %d (Expected 30)", x2_spy);
            errors = errors + 1;
        end else begin
            $display("PASS: Data Hazard Resolved (x2=30)");
        end

        // -------------------------------------------------------------
        // Check 2: Load-Use Hazard (Stall)
        // -------------------------------------------------------------
        if (x3_spy !== 32'hAA) begin
            $display("FAIL: Load x3 = %h", x3_spy);
            errors = errors + 1;
        end

        if (x4_spy !== 32'hAA) begin
            $display("FAIL: Load-Use Stall x4 = %h", x4_spy);
            errors = errors + 1;
        end else begin
            $display("PASS: Load-Use Stall Verified (x4=AA)");
        end

        // -------------------------------------------------------------
        // Check 3: Control Hazard (Flush)
        // -------------------------------------------------------------
        if (x5_spy !== 0) begin
            $display("FAIL: Control Hazard x5 = %d (Should be 0)", x5_spy);
            errors = errors + 1;
        end else begin
            $display("PASS: Branch Flush Verified (x5=0)");
        end

        if (x6_spy !== 5) begin
            $display("FAIL: Branch Target x6 = %d", x6_spy);
            errors = errors + 1;
        end else begin
            $display("PASS: Branch Target Executed (x6=5)");
        end

        // -------------------------------------------------------------
        // Final Summary
        // -------------------------------------------------------------
        if (errors == 0)
            $display("SUCCESS: ALL HAZARD TESTS PASSED");
        else
            $display("FAILURE: %0d ERRORS OUT OF 4", errors);

        $finish;
    end

endmodule
