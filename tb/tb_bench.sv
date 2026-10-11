module tb_bench;

localparam CLOCK_PERIOD = 10;
localparam MAX_CYCLES = 500000;
localparam logic [31:0] TOHOST = 32'h0000_07FC;

logic clk, reset;

string program_file;
longint cycles, retired, stalls, mul_div_stalls, redirects;
logic done;
logic [31:0] tohost_value;

int errors = 0;
int passed = 0;

riscv_top #(
    .IMEM_FILE("sim/isa_rv32i.hex")
) dut (
    .clk(clk),
    .reset(reset)
);

initial begin
    clk = 0;
    forever #(CLOCK_PERIOD/2) clk = ~clk;
end

initial begin
    if (!$value$plusargs("prog=%s", program_file)) program_file = "sim/isa_rv32i.hex";
    #1;
    $readmemh(program_file, dut.u_instruction_memory.memory);
end

always @(posedge clk) begin
    if (reset) begin
        cycles <= 0;
        retired <= 0;
        stalls <= 0;
        mul_div_stalls <= 0;
        redirects <= 0;
        done <= 0;
        tohost_value <= 0;
    end
    else if (!done) begin
        cycles <= cycles + 1;
        if (dut.u_core.wb_valid) retired <= retired + 1;
        if (dut.u_core.load_use_stall) stalls <= stalls + 1;
        if (dut.u_core.mul_div_busy) mul_div_stalls <= mul_div_stalls + 1;
        if (dut.u_core.ex_redirect) redirects <= redirects + 1;
        if (dut.u_core.dmem_MemWrite && dut.u_core.dmem_address == TOHOST) begin
            done <= 1;
            tohost_value <= dut.u_core.dmem_write_data;
        end
    end
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

initial begin
    reset = 1;
    repeat (2) @(posedge clk);
    @(negedge clk);
    reset = 0;

    while (!done && cycles < MAX_CYCLES) @(posedge clk);
    #1;

    $display("Program: %s", program_file);
    check({31'b0, done}, 32'd1, "program reached tohost");
    check(tohost_value, 32'd1, "tohost = 1 (all self-checks passed)");
    $display("cycles    = %0d", cycles);
    $display("retired   = %0d", retired);
    $display("IPC       = %0.3f", real'(retired) / real'(cycles));
    $display("stalls    = %0d", stalls);
    $display("md_stalls = %0d", mul_div_stalls);
    $display("redirects = %0d", redirects);

    $display("=== %0d passed, %0d errors ===", passed, errors);
    $finish;
end

endmodule
