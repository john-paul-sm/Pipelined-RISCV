module tb_multiplier;

localparam CLOCK_PERIOD = 10;
localparam RANDOM_TESTS = 20000;

logic clk, reset;
logic start;
logic [2:0] funct3;
logic [31:0] operand_a, operand_b;
logic busy;
logic [31:0] result;

int errors = 0;
int passed = 0;
int cycles_in_ex;

multiplier dut (
    .clk(clk),
    .reset(reset),
    .start(start),
    .funct3(funct3),
    .operand_a(operand_a),
    .operand_b(operand_b),
    .busy(busy),
    .result(result)
);

initial begin
    clk = 0;
    forever #(CLOCK_PERIOD/2) clk = ~clk;
end

function automatic logic [31:0] reference(
    input logic [2:0] f3,
    input logic [31:0] a,
    input logic [31:0] b
);
    logic signed [63:0] product_signed_signed;
    logic signed [64:0] product_signed_unsigned;
    logic [63:0] product_unsigned_unsigned;
    product_signed_signed = $signed({{32{a[31]}}, a}) * $signed({{32{b[31]}}, b});
    product_signed_unsigned = $signed({{33{a[31]}}, a}) * $signed({33'd0, b});
    product_unsigned_unsigned = {32'd0, a} * {32'd0, b};
    case (f3)
        3'b000: return product_unsigned_unsigned[31:0];
        3'b001: return product_signed_signed[63:32];
        3'b010: return product_signed_unsigned[63:32];
        default: return product_unsigned_unsigned[63:32];
    endcase
endfunction

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
end
endtask

task run(
    input logic [2:0] f3,
    input logic [31:0] a,
    input logic [31:0] b,
    input string label
);
    funct3 = f3;
    operand_a = a;
    operand_b = b;
    start = 1;
    cycles_in_ex = 1;
    @(posedge clk);
    #1;
    cycles_in_ex++;
    operand_a = $urandom; // cycle 2: the operands change (the forwarding source can move)
    operand_b = $urandom;
    #1; // let the new operands reach the combinational logic before the result is checked
    while (busy) begin
        @(posedge clk);
        #1;
        cycles_in_ex++;
    end
    check(result, reference(f3, a, b), $sformatf("%s f3=%0d a=%h b=%h", label, f3, a, b));
    check(cycles_in_ex, 2, $sformatf("%s latency", label));
    @(posedge clk);
    #1;
endtask

initial begin
    reset = 1;
    start = 0;
    funct3 = 0;
    operand_a = 0;
    operand_b = 0;
    repeat (2) @(posedge clk);
    #1;
    reset = 0;

    for (int funct3_value = 0; funct3_value < 4; funct3_value++) begin
        run(funct3_value[2:0], 32'd7, 32'd3, "small");
        run(funct3_value[2:0], 32'hFFFF_FFF9, 32'd3, "neg a");
        run(funct3_value[2:0], 32'd7, 32'hFFFF_FFFD, "neg b");
        run(funct3_value[2:0], 32'hFFFF_FFF9, 32'hFFFF_FFFD, "neg a neg b");
        run(funct3_value[2:0], 32'd12345, 32'd0, "times zero");
        run(funct3_value[2:0], 32'hFFFF_FFF9, 32'd0, "neg times zero");
        run(funct3_value[2:0], 32'h8000_0000, 32'hFFFF_FFFF, "min times all ones");
        run(funct3_value[2:0], 32'h0000_FFFF, 32'h0001_0000, "b pieces 0, 0, 1, 0");
        run(funct3_value[2:0], 32'hFFFF_FFFF, 32'h00FF_FFFF, "b pieces 0..2 all ones");
        run(funct3_value[2:0], 32'h8000_0001, 32'h80FF_FFFF, "b sign bit and pieces 0..2");
        run(funct3_value[2:0], 32'h1234_5678, 32'h0000_0100, "b piece 1 only");
        run(funct3_value[2:0], 32'h8765_4321, 32'h0100_0000, "b piece 3 only");
        run(funct3_value[2:0], 32'hFFFF_FFFF, 32'hFF00_0000, "b piece 3 all ones");
        run(funct3_value[2:0], 32'h8000_0000, 32'h8000_0000, "min by min");
        run(funct3_value[2:0], 32'hFFFF_FFFF, 32'hFFFF_FFFF, "all ones");
        run(funct3_value[2:0], 32'h7FFF_FFFF, 32'h7FFF_FFFF, "max by max");
        run(funct3_value[2:0], 32'h0000_0000, 32'h1234_5678, "zero a");
        run(funct3_value[2:0], 32'h1234_5678, 32'd1, "by one");
        run(funct3_value[2:0], 32'd3, 32'd7, "a less than b");
    end

    for (int i = 0; i < RANDOM_TESTS; i++) begin
        run(3'($urandom_range(0, 3)), $urandom, $urandom, "random");
    end

    start = 0;
    repeat (3) @(posedge clk);
    #1;
    check({31'b0, busy}, 32'd0, "busy = 0 when start = 0");

    $display("=== %0d passed, %0d errors ===", passed, errors);
    $finish;
end

endmodule
