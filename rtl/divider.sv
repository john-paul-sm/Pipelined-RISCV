// Iterative divider for DIV, DIVU, REM, REMU: restoring division, 1 quotient bit per cycle.
// The instruction stays in EX for 36 cycles:
//   IDLE (latch operands) -> ABSOLUTE (make signed operands positive) -> CALCULATE x32 ->
//   FIX (give the quotient and remainder their signs) -> DONE (result valid)
// Divide by zero: quotient = all ones, remainder = dividend. Signed overflow
// (-2^31 / -1): quotient = -2^31, remainder = 0. Both come out of the normal algorithm.

module divider import riscv_ref::*; (
    input logic clk,
    input logic reset,
    input logic start, // EX holds a divide (id_ex_register.MulDiv_out && funct3_out[2])
    input logic [2:0] funct3, // id_ex_register.funct3_out, constant while EX stalls
    input logic [31:0] operand_a, // FA forwarding mux output (rs1 value), latched in IDLE
    input logic [31:0] operand_b, // FB forwarding mux output (rs2 value), latched in IDLE
    output logic busy, // -> stall: hold PC, IF/ID, ID/EX; bubble into EX/MEM
    output logic [31:0] result // -> EX result mux (valid in DONE)
);

typedef enum logic [2:0] {
    S_IDLE,
    S_ABSOLUTE,
    S_CALCULATE,
    S_FIX,
    S_DONE
} state_enum;

state_enum state;
logic [4:0] count;

logic [31:0] remainder;
logic [31:0] quotient; // holds the dividend at the start; quotient bits shift in at bit 0
logic [31:0] divisor;

logic operand_a_signed; // rs1 is a signed operand
logic operand_b_signed; // rs2 is a signed operand
logic operand_a_negative;
logic operand_b_negative;

logic negate_divisor; // ABSOLUTE: negate divisor
logic negate_dividend; // ABSOLUTE: negate quotient (still the dividend)
logic negate_quotient; // FIX: the quotient is negative
logic negate_remainder; // FIX: the remainder is negative (sign of the dividend)

logic [32:0] difference; // {remainder, next dividend bit} - divisor ; bit 32 = 1: negative

assign operand_a_signed = (funct3 == F3_DIV) || (funct3 == F3_REM);
assign operand_b_signed = (funct3 == F3_DIV) || (funct3 == F3_REM);
assign operand_a_negative = operand_a_signed && operand_a[31];
assign operand_b_negative = operand_b_signed && operand_b[31];

assign difference = {remainder, quotient[31]} + ~{1'b0, divisor} + 33'd1;

always_ff @(posedge clk) begin
    if (reset) begin
        state <= S_IDLE;
        count <= 5'd0;
        remainder <= 32'd0;
        quotient <= 32'd0;
        divisor <= 32'd0;
        negate_divisor <= 1'b0;
        negate_dividend <= 1'b0;
        negate_quotient <= 1'b0;
        negate_remainder <= 1'b0;
    end
    else begin
        case (state)
            S_IDLE: begin
                if (start) begin
                    remainder <= 32'd0;
                    quotient <= operand_a;
                    divisor <= operand_b;
                    negate_divisor <= operand_b_negative;
                    negate_dividend <= operand_a_negative;
                    negate_quotient <= operand_a_negative ^ operand_b_negative; // cleared in ABSOLUTE when the divisor is 0
                    negate_remainder <= operand_a_negative;
                    state <= S_ABSOLUTE;
                end
            end

            S_ABSOLUTE: begin
                if (negate_divisor) divisor <= ~divisor + 32'd1;
                if (negate_dividend) quotient <= ~quotient + 32'd1;
                if (divisor == 32'd0) negate_quotient <= 1'b0; // x / 0: quotient stays all ones
                count <= 5'd0;
                state <= S_CALCULATE;
            end

            S_CALCULATE: begin
                remainder <= difference[32] ? {remainder[30:0], quotient[31]} : difference[31:0];
                quotient <= {quotient[30:0], ~difference[32]};
                count <= count + 5'd1;
                if (count == 5'd31) state <= S_FIX;
            end

            S_FIX: begin
                if (negate_quotient) quotient <= ~quotient + 32'd1;
                if (negate_remainder) remainder <= ~remainder + 32'd1;
                state <= S_DONE;
            end

            S_DONE: begin
                state <= S_IDLE;
            end

            default: state <= S_IDLE;
        endcase
    end
end

assign busy = start && (state != S_DONE);

// DIV, DIVU -> quotient ; REM, REMU -> remainder
assign result = ((funct3 == F3_DIV) || (funct3 == F3_DIVU)) ? quotient : remainder;

endmodule
