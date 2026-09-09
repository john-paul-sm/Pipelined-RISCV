module control_unit import riscv_ref::*; (
    input logic[31:0] instruction,
    output logic RegWrite, // Writes to 'rd' or not?
    output logic MemRead,
    output logic MemWrite,
    output logic MemtoReg,
    output logic Jump,
    output logic Branch,
    output logic JumpSrc,
    output logic[1:0] ALUSrcA, // 00 = rs1, 01 = PC, 10 = zero
    output logic[1:0] ALUSrcB, // 00 = rs2, 01 = immediate, 10 = 4
    output logic[1:0] ALUOp // 00 = Force-ADD, 01 = R-Type, 10 = I-Type
);

logic[6:0] opcode;
assign opcode = instruction[6:0];

always_comb begin
    RegWrite = 1'b0;
    MemRead = 1'b0;
    MemWrite = 1'b0;
    MemtoReg = 1'b0; // ALU Result
    Jump = 1'b0;
    Branch = 1'b0;
    JumpSrc = 1'b0; // PC
    ALUSrcA = 2'b00; // rs1
    ALUSrcB = 2'b00; // rs2
    ALUOp = 2'b00; // Force-ADD
    case (opcode)
        OP_R_TYPE: begin
            RegWrite = 1'b1;
            ALUOp = 2'b01;
        end
        OP_I_TYPE: begin
            RegWrite = 1'b1;
            ALUSrcB = 2'b01;
            ALUOp = 2'b10;
        end
        OP_LOAD: begin
            RegWrite = 1'b1;
            ALUSrcB = 2'b01;
            MemRead = 1'b1;
            MemtoReg = 1'b1;
        end
        OP_STORE: begin
            ALUSrcB = 2'b01;
            MemWrite = 1'b1;
        end
        OP_BRANCH: begin
            Branch = 1'b1;
        end
        OP_JAL: begin
            RegWrite = 1'b1;
            Jump = 1'b1;
            ALUSrcA = 2'b01;
            ALUSrcB = 2'b10;
        end
        OP_JALR: begin
            RegWrite = 1'b1;
            Jump = 1'b1;
            JumpSrc = 1'b1; // distinguish JAL and JALR
            ALUSrcA = 2'b01;
            ALUSrcB = 2'b10;
        end
        OP_AUIPC: begin
            RegWrite = 1'b1;
            ALUSrcA = 2'b01;
            ALUSrcB = 2'b01;
        end
        OP_LUI: begin
            RegWrite = 1'b1;
            ALUSrcA = 2'b10;
            ALUSrcB = 2'b01;
        end
        default: begin
            // All signals will be de-asserted to '0. ALUSrcA will select rs1, ALUSrcB will select rs2, and ALUOp will force add by default.
        end
    endcase
end

endmodule
