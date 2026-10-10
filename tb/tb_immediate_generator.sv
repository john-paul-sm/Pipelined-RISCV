`timescale 1ns/1ps

module tb_immediate_generator;

logic [31:0] instruction, immediate;
logic [31:0] expected_immediate;
logic [6:0] opcodes [0:9];

localparam RANDOM_TESTS = 100000;

int errors = 0;
int mismatches = 0;

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

function automatic logic [31:0] reference(input logic [31:0] i);
    case (i[6:0])
        7'b0010011, 7'b0000011, 7'b1100111: return {{20{i[31]}}, i[31:20]};
        7'b0100011: return {{20{i[31]}}, i[31:25], i[11:7]};
        7'b1100011: return {{19{i[31]}}, i[31], i[7], i[30:25], i[11:8], 1'b0};
        7'b0110111, 7'b0010111: return {i[31:12], 12'b0};
        7'b1101111: return {{11{i[31]}}, i[31], i[19:12], i[20], i[30:21], 1'b0};
        default: return 32'h0000_0000;
    endcase
endfunction

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
    // sw x7, 20(x6)      immediate[11:5]=0000000  immediate[4:0]=10100
    instruction = 32'b0000000_00111_00110_010_10100_0100011;
    #1;
    check(immediate, 32'h0000_0014, "S-type positive offset");

    // Test 5: S-type, negative offset
    // sw x7, -4(x6)      immediate[11:5]=1111111  immediate[4:0]=11100
    instruction = 32'b1111111_00111_00110_010_11100_0100011;
    #1;
    check(immediate, 32'hFFFF_FFFC, "S-type negative offset");

    // Test 6: B-type, positive offset
    // beq x5, x6, 16
    // immediate[12]=0 immediate[10:5]=000000 immediate[4:1]=1000 immediate[11]=0
    instruction = 32'b0_000000_00110_00101_000_1000_0_1100011;
    #1;
    check(immediate, 32'h0000_0010, "B-type positive offset");

    // Test 7: B-type, negative offset
    // beq x5, x6, -8
    // immediate[12]=1 immediate[10:5]=111111 immediate[4:1]=1100 immediate[11]=1
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
    // immediate[20]=1 immediate[10:1]=1111111000 immediate[11]=1 immediate[19:12]=11111111
    instruction = 32'b1_1111111000_1_11111111_00001_1101111;
    #1;
    check(immediate, 32'hFFFF_FFF0, "J-type negative offset");

    // Test 11: J-type, positive offset with only bit 11 set
    // jal x1, 2048
    // immediate[20]=0 immediate[10:1]=0000000000 immediate[11]=1 immediate[19:12]=00000000
    instruction = 32'b0_0000000000_1_00000000_00001_1101111;
    #1;
    check(immediate, 32'h0000_0800, "J-type bit 11 comes from instruction[20]");

    // Test 12: unrecognized opcode
    // ecall (opcode 1110011, not decoded by this module)
    instruction = 32'h0000_0073;
    #1;
    check(immediate, 32'h0000_0000, "unknown opcode yields zero");

    // Test 13: random instructions vs. a reference model
    // 9 of 10 use an opcode with an immediate (all other bits random), 1 of 10 is fully random
    opcodes = '{7'b0010011, 7'b0000011, 7'b1100111, 7'b0100011, 7'b1100011, 7'b0110111, 7'b0010111, 7'b1101111, 7'b0110011, 7'b1110011};
    for (int test = 0; test < RANDOM_TESTS; test++) begin
        instruction = $urandom;
        if ($urandom_range(0, 9) != 0) instruction[6:0] = opcodes[$urandom_range(0, 9)];
        #1;
        expected_immediate = reference(instruction);
        if (immediate !== expected_immediate) begin
            mismatches++;
            if (mismatches <= 5) $display("Mismatch: instruction=%h immediate=%h expected %h", instruction, immediate, expected_immediate);
        end
    end
    check(mismatches, 32'd0, "100000 random instructions match the reference model");

    $display("=== %0d errors ===", errors);
    $finish;
end

endmodule