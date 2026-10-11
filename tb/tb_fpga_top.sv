// Simulation model of the Vivado Clocking Wizard (clk_wiz_0).
// Passes the input clock through and raises locked after 20 input cycles.
// Simulation only: do not add this file to the Vivado project.
module clk_wiz_0 (
    input logic clk_in1,
    input logic reset,
    output logic clk_out1,
    output logic locked
);

int count = 0;

assign clk_out1 = clk_in1;

always @(posedge clk_in1) begin
    if (reset) count <= 0;
    else if (count < 20) count <= count + 1;
end

assign locked = (count >= 20);

endmodule

module tb_fpga_top;

localparam CLOCK_PERIOD = 8; // 125 MHz board clock
localparam MAX_CYCLES = 500000;

logic sysclk;
logic btn0;
logic [3:0] led;

string program_file;
int expected_cycles;
int errors = 0;
int passed = 0;
int first_cycles;

fpga_top #(
    .IMEM_FILE("sim/hex/isa_m.hex")
) dut (
    .sysclk(sysclk),
    .btn0(btn0),
    .led(led)
);

initial begin
    sysclk = 0;
    forever #(CLOCK_PERIOD/2) sysclk = ~sysclk;
end

initial begin
    if (!$value$plusargs("prog=%s", program_file)) program_file = "sim/hex/isa_m.hex";
    if (!$value$plusargs("cycles=%d", expected_cycles)) expected_cycles = 0;
    #1;
    $readmemh(program_file, dut.u_instruction_memory.memory);
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

task wait_done();
    int n;
    n = 0;
    while (!led[0] && n < MAX_CYCLES) begin
        @(posedge sysclk);
        n++;
    end
    #1;
endtask

initial begin
    $dumpfile("tb_fpga_top.vcd");
    $dumpvars(0, tb_fpga_top);

    // Test 1: power-up. The core stays in reset until locked, then runs the program.
    btn0 = 0;
    repeat (5) @(posedge sysclk);
    #1;
    check({29'b0, led[2:0]}, 32'd0, "LEDs off before the program finishes");
    wait_done();
    $display("Program: %s", program_file);
    check({31'b0, led[0]}, 32'd1, "LD0 done");
    check({31'b0, led[1]}, 32'd1, "LD1 pass");
    check({31'b0, led[2]}, 32'd0, "LD2 fail off");
    first_cycles = dut.cycles;
    $display("cycles = %0d", first_cycles);
    if (expected_cycles != 0) check(first_cycles, expected_cycles, "cycles = tb_bench cycles");

    // Test 2: the counter stops at done
    repeat (100) @(posedge sysclk);
    #1;
    check(dut.cycles, first_cycles, "counter holds after done");

    // Test 3: press the button: LEDs clear while it is held
    btn0 = 1;
    repeat (5) @(posedge sysclk);
    #1;
    check({29'b0, led[2:0]}, 32'd0, "button held: LEDs clear");

    // Test 4: release: the program runs again with the same cycle count
    btn0 = 0;
    wait_done();
    check({31'b0, led[1]}, 32'd1, "rerun: LD1 pass");
    check(dut.cycles, first_cycles, "rerun: same cycle count");

    $display("=== %0d passed, %0d errors ===", passed, errors);
    $finish;
end

endmodule
