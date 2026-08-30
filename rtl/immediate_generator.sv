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
        OP_STORE: immediate
        default: immediate = '0;
    endcase
end

endmodule
