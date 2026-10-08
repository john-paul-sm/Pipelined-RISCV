package riscv_ref;

    // opcodes: always instruction[6:0]

    typedef enum logic[6:0] {
        OP_R_TYPE = 7'b0110011, // R-Type instructions: add, sub, or, and, etc..
        OP_I_TYPE = 7'b0010011, // I-Type instructions: addi, subi, andi, ori, etc..
        OP_LOAD = 7'b0000011, // Load instructions: lw, lh, lb, lhu, lbu
        OP_STORE = 7'b0100011, // S-Type instructions: sw, sh, sb
        OP_BRANCH = 7'b1100011, // B-Type instructions: beq, bne, blt, bge, etc..
        OP_JAL = 7'b1101111, // Jump and Link
        OP_JALR = 7'b1100111, // Jump and Link Register
        OP_AUIPC = 7'b0010111, // Add Upper Immediate Program Counter
        OP_LUI = 7'b0110111 // Load Upper Immediate
    } opcode_enum;

    // funct3: instruction[14:12] for R, I, S, B type instructions

    // for my enums, it increments by 1 for each parameter but I still defined all of them for completeness and clarity

    // R-Type / I-Type

    typedef enum logic[2:0] {
        F3_ADD_SUB = 3'b000,
        F3_SLL = 3'b001,
        F3_SLT = 3'b010,
        F3_SLTU = 3'b011,
        F3_XOR = 3'b100,
        F3_SRL_SRA = 3'b101,
        F3_OR = 3'b110,
        F3_AND = 3'b111
    } funct3_R_I;

    // B-Type

    typedef enum logic[2:0] {
        F3_BEQ = 3'b000,
        F3_BNE = 3'b001,
        F3_BLT = 3'b100,
        F3_BGE = 3'b101,
        F3_BLTU = 3'b110,
        F3_BGEU = 3'b111
    } funct3_B;

    // L-Type

    typedef enum logic[2:0] {
        F3_LB = 3'b000,
        F3_LH = 3'b001,
        F3_LW = 3'b010,
        F3_LBU = 3'b100,
        F3_LHU = 3'b101
    } funct3_L;
    
    // S-Type

    typedef enum logic[2:0] {
        F3_SB = 3'b000,
        F3_SH = 3'b001,
        F3_SW = 3'b010
    } funct3_S;

    // funct7: instruction[31:25], chooses ADD/SRL or SUB/SRA
    // the differentiator is really only instruction[30]

    localparam logic[6:0] F7_ADD_SRL = 7'b0000000;
    localparam logic[6:0] F7_SUB_SRA = 7'b0100000;

    typedef enum logic[3:0] {
        ALU_ADD = 4'b0000,
        ALU_SUB = 4'b0001,
        ALU_SLL = 4'b0010,
        ALU_SLT = 4'b0011,
        ALU_SLTU = 4'b0100,
        ALU_XOR = 4'b0101,
        ALU_SRL = 4'b0110,
        ALU_SRA = 4'b0111,
        ALU_OR = 4'b1000,
        ALU_AND = 4'b1001
    } alu_op_enum;

endpackage : riscv_ref
