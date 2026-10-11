module control_unit import riscv_ref::*; (
    input logic [31:0] instruction,     // instruction[31:0]
    output logic RegWrite,   // 1 = write rd in WB
    output logic MemRead,    // 1 = load (also tells hazard_detection_unit "EX holds a load")
    output logic MemWrite,   // 1 = store
    output logic [1:0] MemToReg,  // value written to rd: 00 ALU result, 01 load data, 10 PC+4
    output logic [1:0] ALUSrcA,    // ALU operand A:      00 rs1, 01 PC, 10 zero
    output logic ALUSrcB,    // ALU operand B:      0 rs2, 1 immediate
    output logic Branch,     // 1 = conditional branch (B-type)
    output logic Jump,       // 1 = JAL or JALR (always taken)
    output logic Jalr,       // 1 = jump target is rs1+immediate (from ALU), not PC+immediate
    output logic MulDiv,     // 1 = M extension instruction: mul_div_unit result, not ALU result
    output logic rs1_used,   // 1 = instruction[19:15] is rs1 (hazard_detection_unit compares it)
    output logic rs2_used,   // 1 = instruction[24:20] is rs2 (hazard_detection_unit compares it)
    output logic [3:0] alu_op
);

logic [6:0] opcode;
logic [2:0] funct3;
logic funct7_bit5; // bit 5 of funct7
logic [6:0] funct7;

assign opcode = instruction[6:0];
assign funct3 = instruction[14:12];
assign funct7_bit5 = instruction[30];
assign funct7 = instruction[31:25];

localparam logic [1:0] RESULT_ALU = 2'b00;
localparam logic [1:0] RESULT_MEMORY = 2'b01;
localparam logic [1:0] RESULT_PC_PLUS4 = 2'b10;
 
localparam logic [1:0] SRCA_RS1 = 2'b00;
localparam logic [1:0] SRCA_PC = 2'b01;
localparam logic [1:0] SRCA_ZERO = 2'b10;
 
always_comb begin
    RegWrite = 1'b0;
    MemRead = 1'b0;
    MemWrite = 1'b0;
    MemToReg = RESULT_ALU;
    ALUSrcA = SRCA_RS1;
    ALUSrcB = 1'b0;
    Branch = 1'b0;
    Jump = 1'b0;
    Jalr = 1'b0;
    MulDiv = 1'b0;
    rs1_used = 1'b0;
    rs2_used = 1'b0;
    alu_op = ALU_ADD;
 
    case (opcode)
        OP_R_TYPE: begin            // add, sub, sll, slt, ... : rd = rs1 op rs2
            RegWrite = 1'b1;
            rs1_used = 1'b1;
            rs2_used = 1'b1;
            MulDiv = (funct7 == F7_MULDIV); // mul, div, rem, ... : alu_op below is unused

            case (funct3)
                F3_ADD_SUB: alu_op = funct7_bit5 ? ALU_SUB : ALU_ADD;
                F3_SLL: alu_op = ALU_SLL;
                F3_SLT: alu_op = ALU_SLT;
                F3_SLTU: alu_op = ALU_SLTU;
                F3_XOR: alu_op = ALU_XOR;
                F3_SRL_SRA: alu_op = funct7_bit5 ? ALU_SRA : ALU_SRL;
                F3_OR: alu_op = ALU_OR;
                F3_AND: alu_op = ALU_AND;
                default: alu_op = ALU_ADD;
            endcase
        end
 
        OP_I_TYPE: begin            // addi, slti, srai, ... : rd = rs1 op immediate
            RegWrite = 1'b1;
            rs1_used = 1'b1;
            ALUSrcB = 1'b1;

            case (funct3)
                F3_ADD_SUB: alu_op = ALU_ADD;
                F3_SLL: alu_op = ALU_SLL;
                F3_SLT: alu_op = ALU_SLT;
                F3_SLTU: alu_op = ALU_SLTU;
                F3_XOR: alu_op = ALU_XOR;
                F3_SRL_SRA: alu_op = funct7_bit5 ? ALU_SRA : ALU_SRL;
                F3_OR: alu_op = ALU_OR;
                F3_AND: alu_op = ALU_AND;
                default: alu_op = ALU_ADD;
            endcase
        end
 
        OP_LOAD: begin              // lw, lh, lb, ... : rd = mem[rs1 + immediate]
            RegWrite = 1'b1;
            MemRead = 1'b1;
            rs1_used = 1'b1;
            MemToReg = RESULT_MEMORY;
            ALUSrcB = 1'b1;       // ALU computes the address rs1 + immediate
        end
 
        OP_STORE: begin             // sw, sh, sb : mem[rs1 + immediate] = rs2
            MemWrite = 1'b1;
            rs1_used = 1'b1;
            rs2_used = 1'b1;
            ALUSrcB = 1'b1;        // ALU computes the address rs1 + immediate
        end
 
         OP_BRANCH: begin            // beq, bne, ... : comparison done in branch_flush_unit
            Branch = 1'b1;
            rs1_used = 1'b1;
            rs2_used = 1'b1;
        end
 
        OP_JAL: begin               // rd = PC+4 ; PC = PC + immediate (branch-target adder)
            RegWrite = 1'b1;
            MemToReg = RESULT_PC_PLUS4;
            Jump = 1'b1;
         end
 
        OP_JALR: begin              // rd = PC+4 ; PC = (rs1 + immediate) & ~1 (ALU computes rs1 + immediate)
            RegWrite = 1'b1;
            MemToReg = RESULT_PC_PLUS4;
            ALUSrcB = 1'b1;
            Jump = 1'b1;
            Jalr = 1'b1;
            rs1_used = 1'b1;
        end
 
        OP_AUIPC: begin             // rd = PC + immediate
            RegWrite = 1'b1;
            ALUSrcA = SRCA_PC;
            ALUSrcB = 1'b1;
        end
 
        OP_LUI: begin               // rd = 0 + immediate
            RegWrite = 1'b1;
            ALUSrcA = SRCA_ZERO;
            ALUSrcB = 1'b1;
        end
 
        default: ;                  // defaults above: no-op
    endcase
end
 
endmodule