`timescale 1ns/1ps

module tb_program_counter;

localparam CLOCK_PERIOD = 10;

logic clk, reset;
logic [31:0] pc_in, pc_out;

int errors = 0;

program_counter dut (
    .clk(clk),
    .reset(reset),
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
    $display("Passed: %s", label);
end
endtask

initial begin
    reset = 0;
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
    
    $display ("=== %d errors ===", errors);
    $finish;
end

endmodule