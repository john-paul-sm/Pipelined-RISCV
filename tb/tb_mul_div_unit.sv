module tb_mul_div_unit;

localparam CLOCK_PERIOD = 10;
localparam RANDOM_TESTS = 2000;

logic clk, reset;
logic start;
logic [2:0] funct3;
logic [31:0] operand_a, operand_b;
logic busy;
logic [31:0] result;

int errors = 0;
int cycles_in_ex;

mul_div_unit dut (
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
    logic signed [63:0] product_ss;
    logic signed [64:0] product_su;
    logic [63:0] product_uu;
    product_ss = $signed({{32{a[31]}}, a}) * $signed({{32{b[31]}}, b});
    product_su = $signed({{33{a[31]}}, a}) * $signed({33'd0, b});
    product_uu = {32'd0, a} * {32'd0, b};
    case (f3)
        3'b000: return product_uu[31:0];
        3'b001: return product_ss[63:32];
        3'b010: return product_su[63:32];
        3'b011: return product_uu[63:32];
        3'b100: begin
            if (b == 0) return 32'hFFFF_FFFF;
            if (a == 32'h8000_0000 && b == 32'hFFFF_FFFF) return 32'h8000_0000;
            return $signed(a) / $signed(b);
        end
        3'b101: return (b == 0) ? 32'hFFFF_FFFF : a / b;
        3'b110: begin
            if (b == 0) return a;
            if (a == 32'h8000_0000 && b == 32'hFFFF_FFFF) return 32'd0;
            return $signed(a) % $signed(b);
        end
        default: return (b == 0) ? a : a % b;
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
    operand_a = $urandom;
    operand_b = $urandom;
    while (busy) begin
        @(posedge clk);
        #1;
        cycles_in_ex++;
    end
    check(result, reference(f3, a, b), $sformatf("%s f3=%0d a=%h b=%h", label, f3, a, b));
    check(cycles_in_ex, 37, $sformatf("%s latency", label));
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

    for (int f = 0; f < 8; f++) begin
        run(f[2:0], 32'd7, 32'd3, "small");
        run(f[2:0], 32'hFFFF_FFF9, 32'd3, "neg a");
        run(f[2:0], 32'd7, 32'hFFFF_FFFD, "neg b");
        run(f[2:0], 32'hFFFF_FFF9, 32'hFFFF_FFFD, "neg a neg b");
        run(f[2:0], 32'd12345, 32'd0, "divide by zero");
        run(f[2:0], 32'hFFFF_FFF9, 32'd0, "neg divide by zero");
        run(f[2:0], 32'd0, 32'd0, "zero by zero");
        run(f[2:0], 32'h8000_0000, 32'hFFFF_FFFF, "overflow");
        run(f[2:0], 32'h8000_0000, 32'h8000_0000, "min by min");
        run(f[2:0], 32'hFFFF_FFFF, 32'hFFFF_FFFF, "all ones");
        run(f[2:0], 32'h7FFF_FFFF, 32'h7FFF_FFFF, "max by max");
        run(f[2:0], 32'h0000_0000, 32'h1234_5678, "zero a");
        run(f[2:0], 32'h1234_5678, 32'd1, "by one");
        run(f[2:0], 32'd3, 32'd7, "a less than b");
    end

    for (int i = 0; i < RANDOM_TESTS; i++) begin
        run(3'($urandom_range(0, 7)), $urandom, $urandom, "random");
    end

    start = 0;
    repeat (3) @(posedge clk);
    #1;
    check({31'b0, busy}, 32'd0, "busy = 0 when start = 0");

    $display("=== %0d errors ===", errors);
    $finish;
end

endmodule
