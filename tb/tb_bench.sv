module tb_bench;

localparam CLOCK_PERIOD = 10;
localparam MAX_CYCLES = 500000;
localparam logic [31:0] TOHOST = 32'h0000_07FC;

logic clk, reset;

string prog;
longint cycles, retired, stalls, redirects;
logic done;
logic [31:0] tohost_value;

int errors = 0;

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
    if (!$value$plusargs("prog=%s", prog)) prog = "sim/isa_rv32i.hex";
    #1;
    $readmemh(prog, dut.u_imem.memory);
end

always @(posedge clk) begin
    if (reset) begin
        cycles <= 0;
        retired <= 0;
        stalls <= 0;
        redirects <= 0;
        done <= 0;
        tohost_value <= 0;
    end
    else if (!done) begin
        cycles <= cycles + 1;
        if (dut.u_core.wb_valid) retired <= retired + 1;
        if (dut.u_core.hz_stall) stalls <= stalls + 1;
        if (dut.u_core.ex_redirect) redirects <= redirects + 1;
        if (dut.u_core.dmem_MemWrite && dut.u_core.dmem_addr == TOHOST) begin
            done <= 1;
            tohost_value <= dut.u_core.dmem_wdata;
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

    $display("Program: %s", prog);
    check({31'b0, done}, 32'd1, "program reached tohost");
    check(tohost_value, 32'd1, "tohost = 1 (all self-checks passed)");
    $display("cycles    = %0d", cycles);
    $display("retired   = %0d", retired);
    $display("IPC       = %0.3f", real'(retired) / real'(cycles));
    $display("stalls    = %0d", stalls);
    $display("redirects = %0d", redirects);

    $display("=== %0d errors ===", errors);
    $finish;
end

endmodule
