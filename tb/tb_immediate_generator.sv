`timescale 1ns/1ps

module tb_immediate_generator;

logic [31:0] instruction, immediate;

int errors = 0;

immediate_generator dut (
    .instruction(instruction),
    .immediate(immediate)
);

initial begin
    $dumpfile("tb_immediate_generator.vcd");
    $dumpvars(0, tb_immediate_generator);
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

    // Test 1: I-type, positive immediate
    // addi x5, x6, 100
    instruction = 32'b000001100100_00110_000_00101_0010011;
    #1;
    check(immediate, 32'h0000_0064, "I-type positive immediate");

    // Test 2: I-type, negative immediate
    // addi x5, x6, -1
    instruction = 32'b111111111111_00110_000_00101_0010011;
    #1;
    check(immediate, 32'hFFFF_FFFF, "I-type negative immediate");

    // Test 3: JALR uses the I-type field layout
    // jalr x1, x6, -4
    instruction = 32'b111111111100_00110_000_00001_1100111;
    #1;
    check(immediate, 32'hFFFF_FFFC, "JALR decodes as I-type");

    // Test 4: S-type, positive offset
    // sw x7, 20(x6)      imm[11:5]=0000000  imm[4:0]=10100
    instruction = 32'b0000000_00111_00110_010_10100_0100011;
    #1;
    check(immediate, 32'h0000_0014, "S-type positive offset");

    // Test 5: S-type, negative offset
    // sw x7, -4(x6)      imm[11:5]=1111111  imm[4:0]=11100
    instruction = 32'b1111111_00111_00110_010_11100_0100011;
    #1;
    check(immediate, 32'hFFFF_FFFC, "S-type negative offset");

    // Test 6: B-type, positive offset
    // beq x5, x6, 16
    // imm[12]=0 imm[10:5]=000000 imm[4:1]=1000 imm[11]=0
    instruction = 32'b0_000000_00110_00101_000_1000_0_1100011;
    #1;
    check(immediate, 32'h0000_0010, "B-type positive offset");

    // Test 7: B-type, negative offset
    // beq x5, x6, -8
    // imm[12]=1 imm[10:5]=111111 imm[4:1]=1100 imm[11]=1
    instruction = 32'b1_111111_00110_00101_000_1100_1_1100011;
    #1;
    check(immediate, 32'hFFFF_FFF8, "B-type negative offset");

    // Test 8: U-type, LUI
    // lui x5, 0xABCDE
    instruction = 32'b10101011110011011110_00101_0110111;
    #1;
    check(immediate, 32'hABCD_E000, "LUI places imm in upper 20 bits");

    // Test 9: U-type, AUIPC
    // auipc x5, 0x00001
    instruction = 32'b00000000000000000001_00101_0010111;
    #1;
    check(immediate, 32'h0000_1000, "AUIPC places imm in upper 20 bits");

    // Test 10: J-type, negative offset
    // jal x1, -16
    // imm[20]=1 imm[10:1]=1111111000 imm[11]=1 imm[19:12]=11111111
    instruction = 32'b1_1111111000_1_11111111_00001_1101111;
    #1;
    check(immediate, 32'hFFFF_FFF0, "J-type negative offset");

    // Test 11: J-type, positive offset with only bit 11 set
    // jal x1, 2048
    // imm[20]=0 imm[10:1]=0000000000 imm[11]=1 imm[19:12]=00000000
    instruction = 32'b0_0000000000_1_00000000_00001_1101111;
    #1;
    check(immediate, 32'h0000_0800, "J-type bit 11 comes from instruction[20]");

    // Test 12: unrecognized opcode
    // ecall (opcode 1110011, not decoded by this module)
    instruction = 32'h0000_0073;
    #1;
    check(immediate, 32'h0000_0000, "unknown opcode yields zero");

    $display("=== %0d errors ===", errors);
    $finish;
end

endmodule