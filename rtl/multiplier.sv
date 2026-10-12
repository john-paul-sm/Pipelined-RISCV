// 2-cycle multiplier for MUL, MULH, MULHSU, MULHU. The instruction stays in EX for 2 cycles.
// Each operand is extended to 33 bits (sign bit for a signed operand, 0 for an unsigned one),
// so one signed 33 x 33 multiply gives the correct 64-bit product for all four instructions.
// operand_b is split into 4 pieces: b[7:0], b[15:8], b[23:16] (unsigned) and b[32:24] (signed):
//   a * b = a * b_0 + (a * b_1) * 2^8 + (a * b_2) * 2^16 + (a * b_3) * 2^24
// Cycle 1: the four 33 x 9 multiplies, registered (stage cut). The operands are used only here.
// Cycle 2: one 4-input add recombines the pieces into the product.

module multiplier import riscv_ref::*; (
    input logic clk,
    input logic reset,
    input logic start, // EX holds a multiply (id_ex_register.MulDiv_out && !funct3_out[2])
    input logic [2:0] funct3, // id_ex_register.funct3_out, constant while EX stalls
    input logic [31:0] operand_a, // FA forwarding mux output (rs1 value), used in cycle 1 only
    input logic [31:0] operand_b, // FB forwarding mux output (rs2 value), used in cycle 1 only
    output logic busy, // -> stall: hold PC, IF/ID, ID/EX; bubble into EX/MEM (cycle 1 only)
    output logic [31:0] result // -> EX result mux (valid in cycle 2)
);

logic operand_a_signed; // rs1 is a signed operand
logic operand_b_signed; // rs2 is a signed operand

logic signed [32:0] a; // operand_a extended to 33 bits
logic signed [32:0] b; // operand_b extended to 33 bits
logic signed [8:0] b_0; // b[7:0] with a 0 sign bit: never negative
logic signed [8:0] b_1; // b[15:8] with a 0 sign bit: never negative
logic signed [8:0] b_2; // b[23:16] with a 0 sign bit: never negative
logic signed [8:0] b_3; // b[32:24], signed

logic signed [41:0] partial_0; // registered a * b_0
logic signed [41:0] partial_1; // registered a * b_1
logic signed [41:0] partial_2; // registered a * b_2
logic signed [41:0] partial_3; // registered a * b_3
logic signed [63:0] product; // the product always fits in 64 bits

logic stage_1_done; // 1 = cycle 2 of the multiply in EX: partial_0 .. partial_3 are valid

assign operand_a_signed = (funct3 == F3_MULH) || (funct3 == F3_MULHSU);
assign operand_b_signed = (funct3 == F3_MULH);

assign a = {operand_a_signed && operand_a[31], operand_a};
assign b = {operand_b_signed && operand_b[31], operand_b};
assign b_0 = {1'b0, b[7:0]};
assign b_1 = {1'b0, b[15:8]};
assign b_2 = {1'b0, b[23:16]};
assign b_3 = b[32:24];

// Stage 1 register. stage_1_done is set in cycle 1 and cleared in cycle 2, when the multiply
// leaves EX, so a multiply right behind it starts again in cycle 1.
always_ff @(posedge clk) begin
    if (reset) begin
        stage_1_done <= 1'b0;
        partial_0 <= '0;
        partial_1 <= '0;
        partial_2 <= '0;
        partial_3 <= '0;
    end
    else if (start && !stage_1_done) begin
        partial_0 <= a * b_0;
        partial_1 <= a * b_1;
        partial_2 <= a * b_2;
        partial_3 <= a * b_3;
        stage_1_done <= 1'b1;
    end
    else begin
        stage_1_done <= 1'b0;
    end
end

// Stage 2: recombine the pieces
assign product = 64'(partial_0) + (64'(partial_1) <<< 8) + (64'(partial_2) <<< 16) + (64'(partial_3) <<< 24);

assign busy = start && !stage_1_done;

// MUL -> low half of the product ; MULH, MULHSU, MULHU -> high half
assign result = (funct3 == F3_MUL) ? product[31:0] : product[63:32];

endmodule
