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
    S_ABS,
    S_CALC,
    S_FIX,
    S_FIX_HI,
    S_DONE
} state_enum;

state_enum state;
logic [4:0] count;

logic [31:0] hi;
logic [31:0] lo;
logic [31:0] opa;

logic is_div; // 1 = DIV/DIVU/REM/REMU
logic a_signed; // rs1 is a signed operand
logic b_signed; // rs2 is a signed operand
logic a_neg;
logic b_neg;

logic op_is_div; // registered is_div
logic neg_opa; // ABS: negate opa
logic neg_lo; // ABS: negate lo
logic neg_hi_res; // FIX: negate hi (remainder) / sign of the 64-bit product
logic neg_lo_res; // FIX: negate lo (quotient / low half of the product)
logic lo_zero; // FIX -> FIX_HI: lo was 0, so the +1 of -{hi, lo} carries into hi

logic [32:0] add_x;
logic [32:0] add_y;
logic add_cin;
logic [32:0] sum;

logic [31:0] lo_negated;
logic [31:0] opa_negated;
logic [31:0] hi_negated_32; // -hi, for the remainder
logic [31:0] hi_negated_64; // upper half of -{hi, lo}, for the product (uses lo_zero)

assign is_div = funct3[2];
assign a_signed = (funct3 == F3_MULH) || (funct3 == F3_MULHSU) || (funct3 == F3_DIV) || (funct3 == F3_REM);
assign b_signed = (funct3 == F3_MULH) || (funct3 == F3_DIV) || (funct3 == F3_REM);
assign a_neg = a_signed && operand_a[31];
assign b_neg = b_signed && operand_b[31];

// Shared adder.
// multiply : {0, hi} + (lo[0] ? {0, opa} : 0)
// divide   : {hi, lo[31]} - {0, opa}   (sum[32] = 1 means the subtraction went negative)
always_comb begin
    if (op_is_div) begin
        add_x = {hi, lo[31]};
        add_y = ~{1'b0, opa};
        add_cin = 1'b1;
    end
    else begin
        add_x = {1'b0, hi};
        add_y = lo[0] ? {1'b0, opa} : 33'd0;
        add_cin = 1'b0;
    end
end

assign sum = add_x + add_y + {32'd0, add_cin};

assign lo_negated = ~lo + 32'd1;
assign opa_negated = ~opa + 32'd1;
assign hi_negated_32 = ~hi + 32'd1;
assign hi_negated_64 = ~hi + {31'd0, lo_zero};

always_ff @(posedge clk) begin
    if (reset) begin
        state <= S_IDLE;
        count <= 5'd0;
        hi <= 32'd0;
        lo <= 32'd0;
        opa <= 32'd0;
        op_is_div <= 1'b0;
        neg_opa <= 1'b0;
        neg_lo <= 1'b0;
        neg_hi_res <= 1'b0;
        neg_lo_res <= 1'b0;
        lo_zero <= 1'b0;
    end
    else begin
        case (state)
            S_IDLE: begin
                if (start) begin
                    hi <= 32'd0;
                    lo <= is_div ? operand_a : operand_b;
                    opa <= is_div ? operand_b : operand_a;
                    op_is_div <= is_div;
                    neg_opa <= is_div ? b_neg : a_neg;
                    neg_lo <= is_div ? a_neg : b_neg;
                    if (is_div) begin
                        neg_lo_res <= a_neg ^ b_neg; // cleared in ABS when the divisor is 0
                        neg_hi_res <= a_neg;
                    end
                    else begin
                        neg_lo_res <= a_neg ^ b_neg;
                        neg_hi_res <= a_neg ^ b_neg;
                    end
                    state <= S_ABS;
                end
            end

            S_ABS: begin
                if (neg_opa) opa <= opa_negated;
                if (neg_lo) lo <= lo_negated;
                if (op_is_div && (opa == 32'd0)) neg_lo_res <= 1'b0; // x / 0: quotient stays all ones
                count <= 5'd0;
                state <= S_CALC;
            end

            S_CALC: begin
                if (op_is_div) begin
                    hi <= sum[32] ? {hi[30:0], lo[31]} : sum[31:0];
                    lo <= {lo[30:0], ~sum[32]};
                end
                else begin
                    hi <= sum[32:1];
                    lo <= {sum[0], lo[31:1]};
                end
                count <= count + 5'd1;
                if (count == 5'd31) state <= S_FIX;
            end

            S_FIX: begin
                if (op_is_div) begin
                    if (neg_lo_res) lo <= lo_negated;
                    if (neg_hi_res) hi <= hi_negated_32;
                end
                else if (neg_lo_res) begin
                    lo <= lo_negated;
                end
                lo_zero <= (lo == 32'd0);
                state <= S_FIX_HI;
            end

            S_FIX_HI: begin
                if (!op_is_div && neg_hi_res) hi <= hi_negated_64;
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

// MUL, DIV, DIVU -> lo ; MULH, MULHSU, MULHU, REM, REMU -> hi
assign result = ((funct3 == F3_MUL) || (funct3 == F3_DIV) || (funct3 == F3_DIVU)) ? lo : hi;

endmodule
