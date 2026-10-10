module alu import riscv_ref::*; (
    input logic[31:0] operand_a,
    input logic[31:0] operand_b,
    input logic[3:0] alu_op,
    output logic[31:0] result
);

always_comb begin : alu
    case (alu_op)
        ALU_ADD: result = operand_a + operand_b;
        ALU_SUB: result = operand_a - operand_b;
        ALU_SLL: result = operand_a << operand_b[4:0];
        ALU_SLT: result = $signed(operand_a) < $signed(operand_b) ? 32'b1 : 32'b0;
        ALU_SLTU: result = operand_a < operand_b ? 32'b1 : 32'b0;
        ALU_XOR: result = operand_a ^ operand_b;
        ALU_SRL: result = operand_a >> operand_b[4:0];
        ALU_SRA: result = $signed(operand_a) >>> operand_b[4:0];
        ALU_OR: result = operand_a | operand_b;
        ALU_AND: result = operand_a & operand_b;
        default: result = 32'b0;
    endcase
end

endmodule
