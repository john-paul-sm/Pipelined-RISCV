module tb_control_unit;

import riscv_ref::*;

localparam VARIANTS = 100;

logic [31:0] instruction;
logic RegWrite, MemRead, MemWrite;
logic [1:0] MemToReg, ALUSrcA;
logic ALUSrcB, Branch, Jump, Jalr, MulDiv;
logic [3:0] alu_op;

int errors = 0;

control_unit dut (
    .instruction(instruction),
    .RegWrite(RegWrite),
    .MemRead(MemRead),
    .MemWrite(MemWrite),
    .MemToReg(MemToReg),
    .ALUSrcA(ALUSrcA),
    .ALUSrcB(ALUSrcB),
    .Branch(Branch),
    .Jump(Jump),
    .Jalr(Jalr),
    .MulDiv(MulDiv),
    .alu_op(alu_op)
);

initial begin
    $dumpfile("tb_control_unit.vcd");
    $dumpvars(0, tb_control_unit);
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

function automatic logic [15:0] control_word(
    input logic reg_write,
    input logic mem_read,
    input logic mem_write,
    input logic [1:0] mem_to_reg,
    input logic [1:0] alu_src_a,
    input logic alu_src_b,
    input logic branch,
    input logic jump,
    input logic jalr,
    input logic mul_div,
    input logic [3:0] alu_operation
);
    return {reg_write, mem_read, mem_write, mem_to_reg, alu_src_a, alu_src_b, branch, jump, jalr, mul_div, alu_operation};
endfunction

task run(
    input logic [6:0] funct7,
    input logic [2:0] funct3,
    input logic [6:0] opcode,
    input logic keep_funct7,
    input logic check_alu_op,
    input logic [15:0] expected,
    input string label
);
    logic [15:0] observed;
    logic [15:0] mask;
    int mismatches;
    mask = check_alu_op ? 16'hFFFF : 16'hFFF0;
    mismatches = 0;
    for (int i = 0; i < VARIANTS; i++) begin
        instruction = $urandom;
        instruction[6:0] = opcode;
        instruction[14:12] = funct3;
        if (keep_funct7) instruction[31:25] = funct7;
        #1;
        observed = {RegWrite, MemRead, MemWrite, MemToReg, ALUSrcA, ALUSrcB, Branch, Jump, Jalr, MulDiv, alu_op};
        if ((observed & mask) !== (expected & mask)) begin
            mismatches++;
            if (mismatches == 1) $display("Mismatch: %s instruction=%h control=%h expected=%h", label, instruction, observed & mask, expected & mask);
        end
    end
    check(mismatches, 32'd0, label);
endtask

initial begin

    // Test 1: R-type: add, sub, sll, slt, sltu, xor, srl, sra, or, and
    run(7'b0000000, 3'b000, 7'b0110011, 1'b1, 1'b1, control_word(1, 0, 0, 2'b00, 2'b00, 0, 0, 0, 0, 0, ALU_ADD), "add");
    run(7'b0100000, 3'b000, 7'b0110011, 1'b1, 1'b1, control_word(1, 0, 0, 2'b00, 2'b00, 0, 0, 0, 0, 0, ALU_SUB), "sub");
    run(7'b0000000, 3'b001, 7'b0110011, 1'b1, 1'b1, control_word(1, 0, 0, 2'b00, 2'b00, 0, 0, 0, 0, 0, ALU_SLL), "sll");
    run(7'b0000000, 3'b010, 7'b0110011, 1'b1, 1'b1, control_word(1, 0, 0, 2'b00, 2'b00, 0, 0, 0, 0, 0, ALU_SLT), "slt");
    run(7'b0000000, 3'b011, 7'b0110011, 1'b1, 1'b1, control_word(1, 0, 0, 2'b00, 2'b00, 0, 0, 0, 0, 0, ALU_SLTU), "sltu");
    run(7'b0000000, 3'b100, 7'b0110011, 1'b1, 1'b1, control_word(1, 0, 0, 2'b00, 2'b00, 0, 0, 0, 0, 0, ALU_XOR), "xor");
    run(7'b0000000, 3'b101, 7'b0110011, 1'b1, 1'b1, control_word(1, 0, 0, 2'b00, 2'b00, 0, 0, 0, 0, 0, ALU_SRL), "srl");
    run(7'b0100000, 3'b101, 7'b0110011, 1'b1, 1'b1, control_word(1, 0, 0, 2'b00, 2'b00, 0, 0, 0, 0, 0, ALU_SRA), "sra");
    run(7'b0000000, 3'b110, 7'b0110011, 1'b1, 1'b1, control_word(1, 0, 0, 2'b00, 2'b00, 0, 0, 0, 0, 0, ALU_OR), "or");
    run(7'b0000000, 3'b111, 7'b0110011, 1'b1, 1'b1, control_word(1, 0, 0, 2'b00, 2'b00, 0, 0, 0, 0, 0, ALU_AND), "and");

    // Test 2: M extension: MulDiv = 1 for all 8 funct3 values (alu_op is not checked)
    for (int f = 0; f < 8; f++) begin
        run(7'b0000001, f[2:0], 7'b0110011, 1'b1, 1'b0, control_word(1, 0, 0, 2'b00, 2'b00, 0, 0, 0, 0, 1, ALU_ADD), $sformatf("M extension funct3=%0d", f));
    end

    // Test 3: I-type ALU: addi, slti, sltiu, xori, ori, andi, slli, srli, srai
    run(7'b0000000, 3'b000, 7'b0010011, 1'b0, 1'b1, control_word(1, 0, 0, 2'b00, 2'b00, 1, 0, 0, 0, 0, ALU_ADD), "addi");
    run(7'b0000000, 3'b010, 7'b0010011, 1'b0, 1'b1, control_word(1, 0, 0, 2'b00, 2'b00, 1, 0, 0, 0, 0, ALU_SLT), "slti");
    run(7'b0000000, 3'b011, 7'b0010011, 1'b0, 1'b1, control_word(1, 0, 0, 2'b00, 2'b00, 1, 0, 0, 0, 0, ALU_SLTU), "sltiu");
    run(7'b0000000, 3'b100, 7'b0010011, 1'b0, 1'b1, control_word(1, 0, 0, 2'b00, 2'b00, 1, 0, 0, 0, 0, ALU_XOR), "xori");
    run(7'b0000000, 3'b110, 7'b0010011, 1'b0, 1'b1, control_word(1, 0, 0, 2'b00, 2'b00, 1, 0, 0, 0, 0, ALU_OR), "ori");
    run(7'b0000000, 3'b111, 7'b0010011, 1'b0, 1'b1, control_word(1, 0, 0, 2'b00, 2'b00, 1, 0, 0, 0, 0, ALU_AND), "andi");
    run(7'b0000000, 3'b001, 7'b0010011, 1'b1, 1'b1, control_word(1, 0, 0, 2'b00, 2'b00, 1, 0, 0, 0, 0, ALU_SLL), "slli");
    run(7'b0000000, 3'b101, 7'b0010011, 1'b1, 1'b1, control_word(1, 0, 0, 2'b00, 2'b00, 1, 0, 0, 0, 0, ALU_SRL), "srli");
    run(7'b0100000, 3'b101, 7'b0010011, 1'b1, 1'b1, control_word(1, 0, 0, 2'b00, 2'b00, 1, 0, 0, 0, 0, ALU_SRA), "srai");

    // Test 4: loads: lb, lh, lw, lbu, lhu
    run(7'b0000000, 3'b000, 7'b0000011, 1'b0, 1'b1, control_word(1, 1, 0, 2'b01, 2'b00, 1, 0, 0, 0, 0, ALU_ADD), "lb");
    run(7'b0000000, 3'b001, 7'b0000011, 1'b0, 1'b1, control_word(1, 1, 0, 2'b01, 2'b00, 1, 0, 0, 0, 0, ALU_ADD), "lh");
    run(7'b0000000, 3'b010, 7'b0000011, 1'b0, 1'b1, control_word(1, 1, 0, 2'b01, 2'b00, 1, 0, 0, 0, 0, ALU_ADD), "lw");
    run(7'b0000000, 3'b100, 7'b0000011, 1'b0, 1'b1, control_word(1, 1, 0, 2'b01, 2'b00, 1, 0, 0, 0, 0, ALU_ADD), "lbu");
    run(7'b0000000, 3'b101, 7'b0000011, 1'b0, 1'b1, control_word(1, 1, 0, 2'b01, 2'b00, 1, 0, 0, 0, 0, ALU_ADD), "lhu");

    // Test 5: stores: sb, sh, sw
    run(7'b0000000, 3'b000, 7'b0100011, 1'b0, 1'b1, control_word(0, 0, 1, 2'b00, 2'b00, 1, 0, 0, 0, 0, ALU_ADD), "sb");
    run(7'b0000000, 3'b001, 7'b0100011, 1'b0, 1'b1, control_word(0, 0, 1, 2'b00, 2'b00, 1, 0, 0, 0, 0, ALU_ADD), "sh");
    run(7'b0000000, 3'b010, 7'b0100011, 1'b0, 1'b1, control_word(0, 0, 1, 2'b00, 2'b00, 1, 0, 0, 0, 0, ALU_ADD), "sw");

    // Test 6: branches: beq, bne, blt, bge, bltu, bgeu
    run(7'b0000000, 3'b000, 7'b1100011, 1'b0, 1'b0, control_word(0, 0, 0, 2'b00, 2'b00, 0, 1, 0, 0, 0, ALU_ADD), "beq");
    run(7'b0000000, 3'b001, 7'b1100011, 1'b0, 1'b0, control_word(0, 0, 0, 2'b00, 2'b00, 0, 1, 0, 0, 0, ALU_ADD), "bne");
    run(7'b0000000, 3'b100, 7'b1100011, 1'b0, 1'b0, control_word(0, 0, 0, 2'b00, 2'b00, 0, 1, 0, 0, 0, ALU_ADD), "blt");
    run(7'b0000000, 3'b101, 7'b1100011, 1'b0, 1'b0, control_word(0, 0, 0, 2'b00, 2'b00, 0, 1, 0, 0, 0, ALU_ADD), "bge");
    run(7'b0000000, 3'b110, 7'b1100011, 1'b0, 1'b0, control_word(0, 0, 0, 2'b00, 2'b00, 0, 1, 0, 0, 0, ALU_ADD), "bltu");
    run(7'b0000000, 3'b111, 7'b1100011, 1'b0, 1'b0, control_word(0, 0, 0, 2'b00, 2'b00, 0, 1, 0, 0, 0, ALU_ADD), "bgeu");

    // Test 7: jal, jalr, auipc, lui
    run(7'b0000000, 3'b000, 7'b1101111, 1'b0, 1'b0, control_word(1, 0, 0, 2'b10, 2'b00, 0, 0, 1, 0, 0, ALU_ADD), "jal");
    run(7'b0000000, 3'b000, 7'b1100111, 1'b0, 1'b1, control_word(1, 0, 0, 2'b10, 2'b00, 1, 0, 1, 1, 0, ALU_ADD), "jalr");
    run(7'b0000000, 3'b000, 7'b0010111, 1'b0, 1'b1, control_word(1, 0, 0, 2'b00, 2'b01, 1, 0, 0, 0, 0, ALU_ADD), "auipc");
    run(7'b0000000, 3'b000, 7'b0110111, 1'b0, 1'b1, control_word(1, 0, 0, 2'b00, 2'b10, 1, 0, 0, 0, 0, ALU_ADD), "lui");

    // Test 8: fence, ecall/ebreak and illegal opcodes are no-ops
    run(7'b0000000, 3'b000, 7'b0001111, 1'b0, 1'b1, control_word(0, 0, 0, 2'b00, 2'b00, 0, 0, 0, 0, 0, ALU_ADD), "fence: no-op");
    run(7'b0000000, 3'b000, 7'b1110011, 1'b0, 1'b1, control_word(0, 0, 0, 2'b00, 2'b00, 0, 0, 0, 0, 0, ALU_ADD), "ecall/ebreak: no-op");
    run(7'b0000000, 3'b000, 7'b0000000, 1'b0, 1'b1, control_word(0, 0, 0, 2'b00, 2'b00, 0, 0, 0, 0, 0, ALU_ADD), "opcode 0000000: no-op");
    run(7'b0000000, 3'b000, 7'b1111111, 1'b0, 1'b1, control_word(0, 0, 0, 2'b00, 2'b00, 0, 0, 0, 0, 0, ALU_ADD), "opcode 1111111: no-op");

    $display("=== %0d errors ===", errors);
    $finish;
end

endmodule
