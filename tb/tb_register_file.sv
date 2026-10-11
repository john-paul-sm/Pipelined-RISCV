`timescale 1ns / 1ps

module tb_register_file;

localparam CLOCK_PERIOD = 10;

logic clk, reset, RegWrite;
logic [4:0] write_address, rs1_address, rs2_address;
logic [31:0] write_data, read_data1, read_data2;
logic [31:0] model [0:31];
logic [31:0] expected1, expected2;

localparam RANDOM_CYCLES = 20000;

int errors = 0;
int passed = 0;
int mismatches = 0;

register_file dut (
    .clk(clk),
    .reset(reset),
    .RegWrite(RegWrite),
    .write_address(write_address),
    .write_data(write_data),
    .rs1_address(rs1_address),
    .rs2_address(rs2_address),
    .read_data1(read_data1),
    .read_data2(read_data2)
);

initial begin
    $dumpfile("tb_register_file.vcd");
    $dumpvars(0, tb_register_file);
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
    RegWrite = 0;
    write_address = 0;
    write_data = 0;
    rs1_address = 0;
    rs2_address = 0;

    // Test 1: Check reset functionality

    reset = 1;
    @(posedge clk);
    @(posedge clk);
    @(negedge clk);
    reset = 0;
    rs1_address = 5'd5;
    rs2_address = 5'd17;
    #1; 
    check(read_data1, 32'h0, "Reset clears x5");
    check(read_data2, 32'h0, "Reset clears x17");

    // Test 2: Check write functionality

    @(negedge clk);
    RegWrite = 1;
    write_address = 5'd5;
    write_data = 32'hAABB_CCDD;
    @(posedge clk);
    @(negedge clk);
    RegWrite = 0;
    rs1_address = 5'd5;
    #1;
    check(read_data1, 32'hAABB_CCDD, "write x5 then read back");

    // Test 3: Check reads functionality

    @(negedge clk);
    RegWrite = 1;
    write_address = 5'd17;
    write_data = 32'hEEFF_0011;
    @(posedge clk);
    @(negedge clk);
    RegWrite = 0;
    rs1_address = 5'd5;
    rs2_address = 5'd17;
    #1;
    check(read_data1, 32'hAABB_CCDD, "read back x5");
    check(read_data2, 32'hEEFF_0011, "read back x17");

    // Test 4: Check x0 guard

    @(negedge clk);
    RegWrite = 1;
    write_address = 5'd0;
    write_data = 32'hDEAD_BEEF;
    @(posedge clk);
    @(negedge clk);
    RegWrite = 0;
    rs1_address = 5'd0;
    #1;
    check(read_data1, 32'h0, "write x0 is discarded");

    @(negedge clk);
    RegWrite = 1;
    write_address = 5'd0;
    write_data = 32'hDEAD_BEEF;
    rs1_address = 5'd0;
    #1;
    check(read_data1, 32'h0, "write x0 is blocked");

    // Test 5: Check write-first functionality

    @(negedge clk);
    RegWrite = 1;
    write_address = 5'd7;
    write_data = 32'h1234_5678;
    rs1_address = 5'd7;
    #1;
    check(read_data1, 32'h1234_5678, "write first is functional");

    // Test 6: Check RegWrite functionality

    @(negedge clk);
    RegWrite = 1;
    write_address = 5'd9;
    write_data = 32'hABBA_ABBA;
    @(posedge clk);
    @(negedge clk);
    RegWrite = 0;
    write_address = 5'd9;
    write_data = 32'hB0B0_B0B0;
    @(posedge clk);
    @(negedge clk);
    rs1_address = 5'd9;
    #1;
    check(read_data1, 32'hABBA_ABBA, "RegWrite gates the write");

    // Test 7: random writes and reads vs. a reference model
    // model[] holds the expected register values; reads use the write-first rule
    @(negedge clk);
    reset = 1;
    RegWrite = 0;
    @(posedge clk);
    @(negedge clk);
    reset = 0;
    for (int register_index = 0; register_index < 32; register_index++) model[register_index] = 32'b0;
    for (int i = 0; i < RANDOM_CYCLES; i++) begin
        RegWrite = 1'($urandom);
        write_address = 5'($urandom);
        write_data = $urandom;
        rs1_address = ($urandom_range(0, 3) == 0) ? write_address : 5'($urandom);
        rs2_address = 5'($urandom);
        #1;
        expected1 = (RegWrite && rs1_address == write_address && write_address != 5'd0) ? write_data : model[rs1_address];
        expected2 = (RegWrite && rs2_address == write_address && write_address != 5'd0) ? write_data : model[rs2_address];
        if ((read_data1 !== expected1) || (read_data2 !== expected2)) begin
            mismatches++;
            if (mismatches <= 5) $display("Mismatch: cycle %0d rs1=%0d rd_data1=%h expected %h, rs2=%0d rd_data2=%h expected %h", i, rs1_address, read_data1, expected1, rs2_address, read_data2, expected2);
        end
        @(posedge clk);
        if (RegWrite && write_address != 5'd0) model[write_address] = write_data;
        @(negedge clk);
    end
    RegWrite = 0;
    check(mismatches, 32'd0, "20000 random cycles match the reference model");

    $display("=== %0d passed, %0d errors ===", passed, errors);
    $finish;
end

endmodule
