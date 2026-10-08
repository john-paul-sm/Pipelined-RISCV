module immediate_generator import riscv_ref::*; (
    input logic[31:0] instruction,
    output logic[31:0] immediate
);

logic[6:0] opcode;
assign opcode = instruction[6:0];

always_comb begin
    case (opcode) 
        OP_I_TYPE, OP_LOAD, OP_JALR: immediate = {{20{instruction[31]}}, instruction[31:20]};
        OP_STORE: immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
        OP_BRANCH: immediate = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
        OP_AUIPC, OP_LUI: immediate = {instruction[31:12], 12'b0};
        OP_JAL: immediate = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
        default: immediate = '0;
    endcase
end

endmodule

/* 
The opcode which is determined in instruction[6:0] will be used as the select to choose the right formatting for the immediates.
R-Type instructions (add, sub, slr, and, etc.) do not utilize immediates in their bit encoding so it will go to the default case.
I-Type instructions, including load and jump and link register (jalr) follow the same format for their storing their 12 immediate bits.
S-Type instructions (sw, sh, sb) also have 12 immediate bits, but they are disjointed.
B-Type instructions (beq, bne, blt, bge, etc.)
*/
