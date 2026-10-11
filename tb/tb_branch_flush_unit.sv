module tb_branch_flush_unit;

localparam RANDOM_TESTS = 100000;

logic Branch, Jump;
logic [2:0] funct3;
logic [31:0] operand_a, operand_b;
logic redirect;

int errors = 0;
int passed = 0;
int mismatches = 0;

branch_flush_unit dut (
    .Branch(Branch),
    .Jump(Jump),
    .funct3(funct3),
    .operand_a(operand_a),
    .operand_b(operand_b),
    .redirect(redirect)
);

initial begin
    $dumpfile("tb_branch_flush_unit.vcd");
    $dumpvars(0, tb_branch_flush_unit);
end

task check(
    input logic [31:0] observed,
    input logic [31:0] expected,
    input string label
);

if (observed !== expected) begin
    $error("%s: expected %h, got %h", label, expected, observed);
    errors++;
end
else begin
    passed++;
    $display("Passed: %s", label);
end
endtask

function automatic logic reference(
    input logic branch_in,
    input logic jump_in,
    input logic [2:0] funct3_in,
    input logic [31:0] a,
    input logic [31:0] b
);
    logic taken;
    case (funct3_in)
        3'b000: taken = (a == b);
        3'b001: taken = (a != b);
        3'b100: taken = ($signed(a) < $signed(b));
        3'b101: taken = ($signed(a) >= $signed(b));
        3'b110: taken = (a < b);
        3'b111: taken = (a >= b);
        default: taken = 1'b0;
    endcase
    return jump_in || (branch_in && taken);
endfunction

task run(
    input logic branch_in,
    input logic jump_in,
    input logic [2:0] funct3_in,
    input logic [31:0] a,
    input logic [31:0] b,
    input logic expected,
    input string label
);
    Branch = branch_in;
    Jump = jump_in;
    funct3 = funct3_in;
    operand_a = a;
    operand_b = b;
    #1;
    check({31'b0, redirect}, {31'b0, expected}, label);
endtask

initial begin

    // Test 1: beq and bne
    run(1'b1, 1'b0, 3'b000, 32'd7, 32'd7, 1'b1, "beq equal: taken");
    run(1'b1, 1'b0, 3'b000, 32'd7, 32'd8, 1'b0, "beq not equal: not taken");
    run(1'b1, 1'b0, 3'b001, 32'd7, 32'd8, 1'b1, "bne not equal: taken");
    run(1'b1, 1'b0, 3'b001, 32'd7, 32'd7, 1'b0, "bne equal: not taken");

    // Test 2: blt and bge: signed compare, including the most negative and most positive values
    run(1'b1, 1'b0, 3'b100, 32'hFFFF_FFFF, 32'd1, 1'b1, "blt -1 < 1: taken");
    run(1'b1, 1'b0, 3'b100, 32'd1, 32'hFFFF_FFFF, 1'b0, "blt 1 < -1: not taken");
    run(1'b1, 1'b0, 3'b100, 32'h8000_0000, 32'h7FFF_FFFF, 1'b1, "blt min < max: taken");
    run(1'b1, 1'b0, 3'b100, 32'd5, 32'd5, 1'b0, "blt equal: not taken");
    run(1'b1, 1'b0, 3'b101, 32'd5, 32'd5, 1'b1, "bge equal: taken");
    run(1'b1, 1'b0, 3'b101, 32'd1, 32'hFFFF_FFFF, 1'b1, "bge 1 >= -1: taken");
    run(1'b1, 1'b0, 3'b101, 32'hFFFF_FFFF, 32'd1, 1'b0, "bge -1 >= 1: not taken");

    // Test 3: bltu and bgeu: unsigned compare
    run(1'b1, 1'b0, 3'b110, 32'd1, 32'hFFFF_FFFF, 1'b1, "bltu 1 < 0xFFFFFFFF: taken");
    run(1'b1, 1'b0, 3'b110, 32'hFFFF_FFFF, 32'd1, 1'b0, "bltu 0xFFFFFFFF < 1: not taken");
    run(1'b1, 1'b0, 3'b110, 32'h7FFF_FFFF, 32'h8000_0000, 1'b1, "bltu 0x7FFFFFFF < 0x80000000: taken");
    run(1'b1, 1'b0, 3'b111, 32'hFFFF_FFFF, 32'd1, 1'b1, "bgeu 0xFFFFFFFF >= 1: taken");
    run(1'b1, 1'b0, 3'b111, 32'd0, 32'd0, 1'b1, "bgeu equal: taken");
    run(1'b1, 1'b0, 3'b111, 32'd0, 32'd1, 1'b0, "bgeu 0 >= 1: not taken");

    // Test 4: funct3 010 and 011 are not branch types
    run(1'b1, 1'b0, 3'b010, 32'd7, 32'd7, 1'b0, "funct3 010 is not a branch: not taken");
    run(1'b1, 1'b0, 3'b011, 32'd7, 32'd7, 1'b0, "funct3 011 is not a branch: not taken");

    // Test 5: Branch and Jump
    run(1'b0, 1'b0, 3'b000, 32'd7, 32'd7, 1'b0, "Branch = 0: no redirect");
    run(1'b0, 1'b1, 3'b000, 32'd7, 32'd8, 1'b1, "Jump = 1: redirect");
    run(1'b0, 1'b1, 3'b101, 32'hFFFF_FFFF, 32'd1, 1'b1, "Jump ignores the compare");

    // Test 6: random inputs vs. a reference model (operands equal in 1 of 4 cases)
    for (int i = 0; i < RANDOM_TESTS; i++) begin
        Branch = 1'($urandom);
        Jump = 1'($urandom_range(0, 7) == 0);
        funct3 = 3'($urandom);
        operand_a = $urandom;
        operand_b = ($urandom_range(0, 3) == 0) ? operand_a : $urandom;
        #1;
        if (redirect !== reference(Branch, Jump, funct3, operand_a, operand_b)) begin
            mismatches++;
            if (mismatches <= 5) $display("Mismatch: Branch=%b Jump=%b funct3=%b a=%h b=%h redirect=%b", Branch, Jump, funct3, operand_a, operand_b, redirect);
        end
    end
    check(mismatches, 32'd0, "redirect matches the reference for 100000 random inputs");

    $display("=== %0d passed, %0d errors ===", passed, errors);
    $finish;
end

endmodule
