module mul_div_unit import riscv_ref::*; (
    input logic clk,
    input logic reset,
    input logic start, // EX holds an M instruction (id_ex_register.MulDiv_out)
    input logic [2:0] funct3, // id_ex_register.funct3_out, constant while EX stalls
    input logic [31:0] operand_a, // FA forwarding mux output (rs1 value)
    input logic [31:0] operand_b, // FB forwarding mux output (rs2 value)
    output logic busy, // -> stall: hold PC, IF/ID, ID/EX; bubble into EX/MEM
    output logic [31:0] result // -> EX result mux
);

typedef enum logic [2:0] {
    S_IDLE,
    S_ABSOLUTE,
    S_CALCULATE,
    S_FIX,
    S_FIX_HIGH,
    S_DONE
} state_enum;

state_enum state;
logic [4:0] count;

logic [31:0] high;
logic [31:0] low;
logic [31:0] multiplicand_divisor;

logic is_divide; // 1 = DIV/DIVU/REM/REMU
logic operand_a_signed; // rs1 is a signed operand
logic operand_b_signed; // rs2 is a signed operand
logic operand_a_negative;
logic operand_b_negative;

logic operation_is_divide; // registered is_divide
logic negate_multiplicand_divisor; // ABSOLUTE: negate multiplicand_divisor
logic negate_low; // ABSOLUTE: negate low
logic negate_high_result; // FIX: negate high (remainder) / sign of the 64-bit product
logic negate_low_result; // FIX: negate low (quotient / low half of the product)
logic low_is_zero; // FIX -> FIX_HIGH: low was 0, so the +1 of -{high, low} carries into high

logic [32:0] adder_input_a;
logic [32:0] adder_input_b;
logic adder_carry_in;
logic [32:0] sum;

logic [31:0] low_negated;
logic [31:0] multiplicand_divisor_negated;
logic [31:0] high_negated_32; // -high, for the remainder
logic [31:0] high_negated_64; // upper half of -{high, low}, for the product (uses low_is_zero)

assign is_divide = funct3[2];
assign operand_a_signed = (funct3 == F3_MULH) || (funct3 == F3_MULHSU) || (funct3 == F3_DIV) || (funct3 == F3_REM);
assign operand_b_signed = (funct3 == F3_MULH) || (funct3 == F3_DIV) || (funct3 == F3_REM);
assign operand_a_negative = operand_a_signed && operand_a[31];
assign operand_b_negative = operand_b_signed && operand_b[31];

// Shared adder.
// multiply : {0, high} + (low[0] ? {0, multiplicand_divisor} : 0)
// divide   : {high, low[31]} - {0, multiplicand_divisor}   (sum[32] = 1 means the subtraction went negative)
always_comb begin
    if (operation_is_divide) begin
        adder_input_a = {high, low[31]};
        adder_input_b = ~{1'b0, multiplicand_divisor};
        adder_carry_in = 1'b1;
    end
    else begin
        adder_input_a = {1'b0, high};
        adder_input_b = low[0] ? {1'b0, multiplicand_divisor} : 33'd0;
        adder_carry_in = 1'b0;
    end
end

assign sum = adder_input_a + adder_input_b + {32'd0, adder_carry_in};

assign low_negated = ~low + 32'd1;
assign multiplicand_divisor_negated = ~multiplicand_divisor + 32'd1;
assign high_negated_32 = ~high + 32'd1;
assign high_negated_64 = ~high + {31'd0, low_is_zero};

always_ff @(posedge clk) begin
    if (reset) begin
        state <= S_IDLE;
        count <= 5'd0;
        high <= 32'd0;
        low <= 32'd0;
        multiplicand_divisor <= 32'd0;
        operation_is_divide <= 1'b0;
        negate_multiplicand_divisor <= 1'b0;
        negate_low <= 1'b0;
        negate_high_result <= 1'b0;
        negate_low_result <= 1'b0;
        low_is_zero <= 1'b0;
    end
    else begin
        case (state)
            S_IDLE: begin
                if (start) begin
                    high <= 32'd0;
                    low <= is_divide ? operand_a : operand_b;
                    multiplicand_divisor <= is_divide ? operand_b : operand_a;
                    operation_is_divide <= is_divide;
                    negate_multiplicand_divisor <= is_divide ? operand_b_negative : operand_a_negative;
                    negate_low <= is_divide ? operand_a_negative : operand_b_negative;
                    if (is_divide) begin
                        negate_low_result <= operand_a_negative ^ operand_b_negative; // cleared in ABSOLUTE when the divisor is 0
                        negate_high_result <= operand_a_negative;
                    end
                    else begin
                        negate_low_result <= operand_a_negative ^ operand_b_negative;
                        negate_high_result <= operand_a_negative ^ operand_b_negative;
                    end
                    state <= S_ABSOLUTE;
                end
            end

            S_ABSOLUTE: begin
                if (negate_multiplicand_divisor) multiplicand_divisor <= multiplicand_divisor_negated;
                if (negate_low) low <= low_negated;
                if (operation_is_divide && (multiplicand_divisor == 32'd0)) negate_low_result <= 1'b0; // x / 0: quotient stays all ones
                count <= 5'd0;
                state <= S_CALCULATE;
            end

            S_CALCULATE: begin
                if (operation_is_divide) begin
                    high <= sum[32] ? {high[30:0], low[31]} : sum[31:0];
                    low <= {low[30:0], ~sum[32]};
                end
                else begin
                    high <= sum[32:1];
                    low <= {sum[0], low[31:1]};
                end
                count <= count + 5'd1;
                if (count == 5'd31) state <= S_FIX;
            end

            S_FIX: begin
                if (operation_is_divide) begin
                    if (negate_low_result) low <= low_negated;
                    if (negate_high_result) high <= high_negated_32;
                end
                else if (negate_low_result) begin
                    low <= low_negated;
                end
                low_is_zero <= (low == 32'd0);
                state <= S_FIX_HIGH;
            end

            S_FIX_HIGH: begin
                if (!operation_is_divide && negate_high_result) high <= high_negated_64;
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

// MUL, DIV, DIVU -> low ; MULH, MULHSU, MULHU, REM, REMU -> high
assign result = ((funct3 == F3_MUL) || (funct3 == F3_DIV) || (funct3 == F3_DIVU)) ? low : high;

endmodule
