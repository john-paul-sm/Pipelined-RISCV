module tb_alu;

import riscv_ref::*;

localparam RANDOM_TESTS = 100000;

logic [31:0] operand_a, operand_b, result;
logic [3:0] alu_op;

int errors = 0;
int passed = 0;
int mismatches = 0;

alu dut (
    .operand_a(operand_a),
    .operand_b(operand_b),
    .alu_op(alu_op),
    .result(result)
);

initial begin
    $dumpfile("tb_alu.vcd");
    $dumpvars(0, tb_alu);
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

function automatic logic [31:0] reference(
    input logic [3:0] alu_op_value,
    input logic [31:0] x,
    input logic [31:0] y
);
    case (alu_op_value)
        4'd0: return x + y;
        4'd1: return x - y;
        4'd2: return x << y[4:0];
        4'd3: return {31'b0, $signed(x) < $signed(y)};
        4'd4: return {31'b0, x < y};
        4'd5: return x ^ y;
        4'd6: return x >> y[4:0];
        4'd7: return 32'($signed(x) >>> y[4:0]);
        4'd8: return x | y;
        4'd9: return x & y;
        default: return 32'd0;
    endcase
endfunction

task run(
    input logic [3:0] alu_op_value,
    input logic [31:0] x,
    input logic [31:0] y,
    input logic [31:0] expected,
    input string label
);
    alu_op = alu_op_value;
    operand_a = x;
    operand_b = y;
    #1;
    check(result, expected, label);
endtask

initial begin

    // Test 1: add and sub, including overflow
    run(ALU_ADD, 32'd7, 32'd3, 32'd10, "add");
    run(ALU_ADD, 32'h7FFF_FFFF, 32'd1, 32'h8000_0000, "add overflow wraps");
    run(ALU_ADD, 32'hFFFF_FFFF, 32'd1, 32'd0, "add carry out is dropped");
    run(ALU_SUB, 32'd3, 32'd7, 32'hFFFF_FFFC, "sub negative result");
    run(ALU_SUB, 32'h8000_0000, 32'd1, 32'h7FFF_FFFF, "sub underflow wraps");

    // Test 2: shifts: only b[4:0] is the shift amount; sra fills with the sign bit
    run(ALU_SLL, 32'd1, 32'd31, 32'h8000_0000, "sll by 31");
    run(ALU_SLL, 32'd1, 32'd32, 32'd1, "sll uses b[4:0] only: shift 32 = shift 0");
    run(ALU_SRL, 32'h8000_0000, 32'd31, 32'd1, "srl fills with 0");
    run(ALU_SRA, 32'h8000_0000, 32'd31, 32'hFFFF_FFFF, "sra fills with the sign bit");
    run(ALU_SRA, 32'h4000_0000, 32'd30, 32'd1, "sra positive");
    run(ALU_SRA, 32'h8000_0000, 32'd0, 32'h8000_0000, "sra by 0");

    // Test 3: slt and sltu: signed vs. unsigned compare
    run(ALU_SLT, 32'hFFFF_FFFF, 32'd1, 32'd1, "slt -1 < 1");
    run(ALU_SLT, 32'd1, 32'hFFFF_FFFF, 32'd0, "slt 1 < -1 is false");
    run(ALU_SLT, 32'd5, 32'd5, 32'd0, "slt equal is false");
    run(ALU_SLTU, 32'd1, 32'hFFFF_FFFF, 32'd1, "sltu 1 < 0xFFFFFFFF");
    run(ALU_SLTU, 32'hFFFF_FFFF, 32'd1, 32'd0, "sltu 0xFFFFFFFF < 1 is false");

    // Test 4: logic operations
    run(ALU_XOR, 32'hF0F0_F0F0, 32'hFF00_FF00, 32'h0FF0_0FF0, "xor");
    run(ALU_OR, 32'hF0F0_F0F0, 32'h0F00_0F00, 32'hFFF0_FFF0, "or");
    run(ALU_AND, 32'hF0F0_F0F0, 32'hFF00_FF00, 32'hF000_F000, "and");

    // Test 5: unused op codes give 0
    run(4'd10, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'd0, "unused op 10 gives 0");
    run(4'd15, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'd0, "unused op 15 gives 0");

    // Test 6: random inputs vs. a reference model
    for (int i = 0; i < RANDOM_TESTS; i++) begin
        alu_op = 4'($urandom_range(0, 15));
        operand_a = $urandom;
        operand_b = $urandom;
        #1;
        if (result !== reference(alu_op, operand_a, operand_b)) begin
            mismatches++;
            if (mismatches <= 5) $display("Mismatch: op=%0d a=%h b=%h result=%h expected=%h", alu_op, operand_a, operand_b, result, reference(alu_op, operand_a, operand_b));
        end
    end
    check(mismatches, 32'd0, "result matches the reference for 100000 random inputs");

    $display("=== %0d passed, %0d errors ===", passed, errors);
    $finish;
end

endmodule
