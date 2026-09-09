import riscv_ref::*;

module immediate_generator (
    input logic[31:0] instruction,
    output logic[31:0] immediate
);

// The opcode which is determined in instruction[6:0] will 

logic[6:0] opcode;
assign opcode = instruction[6:0];

always_comb begin : imm_gen
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
