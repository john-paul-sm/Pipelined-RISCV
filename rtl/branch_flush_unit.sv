module branch_flush_unit import riscv_ref::*; (
    input logic Branch,     // control_unit.Branch (ID) -> id_ex_register.Branch_out
    input logic Jump,       // control_unit.Jump   (ID) -> id_ex_register.Jump_out
    input logic [2:0]  funct3,     // instruction_memory [14:12] -> if_id -> id_ex.funct3_out
    input logic [31:0] operand_a,  // FA forwarding mux output (rs1 value)
    input logic [31:0] operand_b,  // FB forwarding mux output (rs2 value) -- NOT the SB mux
    output logic redirect    // next-PC mux select, if_id flush, id_ex flush
);
 
logic eq;
logic lt;
logic ltu;

assign eq = (operand_a == operand_b);
assign lt = ($signed(operand_a) < $signed(operand_b));  // two's complement
assign ltu = (operand_a < operand_b);
 
logic condition;

always_comb begin
    case (funct3)
        F3_BEQ: condition = eq;
        F3_BNE: condition = !eq;
        F3_BLT: condition = lt;
        F3_BGE: condition = !lt;
        F3_BLTU: condition = ltu;
        F3_BGEU: condition = !ltu;
        default: condition = 1'b0;
    endcase
end
 
assign redirect = Jump || (Branch && condition);
 
endmodule