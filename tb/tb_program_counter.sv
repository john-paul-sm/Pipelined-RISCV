`timescale 1ns/1ps

module tb_program_counter;

localparam CLOCK_PERIOD = 10;

logic clk, reset, stall;
logic [31:0] pc_in, pc_out;
logic [31:0] expected_pc;

localparam RANDOM_CYCLES = 10000;

int errors = 0;
int passed = 0;
int mismatches = 0;

program_counter dut (
    .clk(clk),
    .reset(reset),
    .stall(stall),
    .pc_in(pc_in),
    .pc_out(pc_out)
);

initial begin
    $dumpfile("tb_program_counter.vcd");
    $dumpvars(0, tb_program_counter);
end

initial begin
    clk = 0;
    forever #(CLOCK_PERIOD/2) clk = ~clk;
end

task check(
    input logic [31:0] observed,
    input logic [31:0] expected,
    input string label
);

if (observed !== expected) begin
    $error("%s: expected %h, got %h", label, expected, observed);
    errors++;
end
else begin
    passed++;
    $display("Passed: %s", label);
end
endtask

initial begin
    reset = 0;
    stall = 0;
    pc_in = 0;

    // Test 1: Check reset functionality

    reset = 1;
    pc_in = 32'hFFFF_FFFF;
    @(posedge clk);
    @(posedge clk);
    @(negedge clk);
    check(pc_out, 32'h0000_0000, "Reset functionality to 0");
    reset = 0;
    #1;

    // Test 2: Check program counter update

    @(negedge clk);
    pc_in = 32'h0000_0004;
    @(posedge clk);
    #1;
    check(pc_out, 32'h0000_0004, "Update program counter to 0x4");

    // Test 3: Arbitrary target (pc takes any value)

    @(negedge clk);
    pc_in = 32'h1234_5678;
    @(posedge clk);
    #1;
    check(pc_out, 32'h1234_5678, "pc takes an arbitrary branch target");

    // Test 4: stall holds the current pc

    @(negedge clk);
    stall = 1;
    pc_in = 32'hDEAD_BEE0;
    @(posedge clk);
    #1;
    check(pc_out, 32'h1234_5678, "stall holds pc");

    // Test 5: random reset, stall and pc_in vs. a reference model
    // reset has priority, then stall holds, else pc loads pc_in

    expected_pc = pc_out;
    for (int i = 0; i < RANDOM_CYCLES; i++) begin
        @(negedge clk);
        reset = ($urandom_range(0, 99) == 0);
        stall = 1'($urandom);
        pc_in = $urandom;
        @(posedge clk);
        #1;
        if (reset) expected_pc = 32'h0000_0000;
        else if (!stall) expected_pc = pc_in;
        if (pc_out !== expected_pc) begin
            mismatches++;
            if (mismatches <= 5) $display("Mismatch: cycle %0d reset=%b stall=%b pc_in=%h pc_out=%h expected %h", i, reset, stall, pc_in, pc_out, expected_pc);
        end
    end
    reset = 0;
    stall = 0;
    check(mismatches, 32'd0, "10000 random cycles match the reference model");

    $display ("=== %0d passed, %0d errors ===", passed, errors);
    $finish;
end

endmodule