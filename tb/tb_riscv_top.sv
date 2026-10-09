module tb_riscv_top;

localparam CLOCK_PERIOD = 10;

logic clk, reset;

logic [31:0] shadow_rf [0:31];
logic [31:0] shadow_mem [0:511];

int errors = 0;

riscv_top #(
    .IMEM_FILE("sim/prog_hazards.hex")
) dut (
    .clk(clk),
    .reset(reset)
);

initial begin
    $dumpfile("tb_riscv_top.vcd");
    $dumpvars(0, tb_riscv_top);
end

initial begin
    clk = 0;
    forever #(CLOCK_PERIOD/2) clk = ~clk;
end

initial begin
    for (int i = 0; i < 32; i++) shadow_rf[i] = 32'b0;
    for (int i = 0; i < 512; i++) shadow_mem[i] = 32'b0;
end

always @(posedge clk) begin
    if (!reset) begin
        if (dut.u_core.wb_RegWrite && dut.u_core.wb_rd_addr != 5'b0) begin
            shadow_rf[dut.u_core.wb_rd_addr] <= dut.u_core.wb_data;
            $display("commit x%0d <= %h", dut.u_core.wb_rd_addr, dut.u_core.wb_data);
        end
        if (dut.u_core.dmem_MemWrite && dut.u_core.dmem_funct3 == 3'b010) begin
            shadow_mem[dut.u_core.dmem_addr[10:2]] <= dut.u_core.dmem_wdata;
            $display("store mem[%h] <= %h", dut.u_core.dmem_addr, dut.u_core.dmem_wdata);
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

    repeat (30) @(posedge clk);
    #1;

    check(shadow_rf[1], 32'd5, "x1 = 5");
    check(shadow_rf[2], 32'h100, "x2 = 0x100");
    check(shadow_rf[3], 32'd5, "x3: load returns the stored value");
    check(shadow_rf[4], 32'd10, "x4: load-use stall + W forward");
    check(shadow_rf[5], 32'd0, "x5: wrong-path 0x18 flushed");
    check(shadow_rf[6], 32'd0, "x6: wrong-path 0x1C flushed");
    check(shadow_rf[7], 32'd10, "x7: branch target executes");
    check(shadow_mem[32'h100 >> 2], 32'd5, "mem[0x100]: store data forwarded");

    $display("=== %0d errors ===", errors);
    $finish;
end

endmodule
