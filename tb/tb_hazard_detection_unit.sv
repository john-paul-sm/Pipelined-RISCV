module tb_hazard_detection_unit;

logic id_ex_MemRead;
logic [4:0] id_ex_rd_addr, if_id_rs1_addr, if_id_rs2_addr;
logic stall, expected_stall;

int errors = 0;
int mismatches = 0;
int combinations = 0;

hazard_detection_unit dut (
    .id_ex_MemRead(id_ex_MemRead),
    .id_ex_rd_addr(id_ex_rd_addr),
    .if_id_rs1_addr(if_id_rs1_addr),
    .if_id_rs2_addr(if_id_rs2_addr),
    .stall(stall)
);

initial begin
    $dumpfile("tb_hazard_detection_unit.vcd");
    $dumpvars(0, tb_hazard_detection_unit);
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

    // Test 1: load in EX, next instruction reads the load's rd as rs1
    // lw x5, 0(x6) ; add x7, x5, x8
    id_ex_MemRead = 1;
    id_ex_rd_addr = 5'd5;
    if_id_rs1_addr = 5'd5;
    if_id_rs2_addr = 5'd8;
    #1;
    check({31'b0, stall}, 32'd1, "load rd = rs1: stall");

    // Test 2: load in EX, next instruction reads the load's rd as rs2
    // lw x5, 0(x6) ; add x7, x8, x5
    if_id_rs1_addr = 5'd8;
    if_id_rs2_addr = 5'd5;
    #1;
    check({31'b0, stall}, 32'd1, "load rd = rs2: stall");

    // Test 3: load in EX, next instruction does not read the load's rd
    // lw x5, 0(x6) ; add x7, x8, x9
    if_id_rs1_addr = 5'd8;
    if_id_rs2_addr = 5'd9;
    #1;
    check({31'b0, stall}, 32'd0, "load rd not read: no stall");

    // Test 4: no load in EX, register numbers match
    // add x5, x6, x7 ; add x7, x5, x5
    id_ex_MemRead = 0;
    if_id_rs1_addr = 5'd5;
    if_id_rs2_addr = 5'd5;
    #1;
    check({31'b0, stall}, 32'd0, "no load in EX: no stall");

    // Test 5: load to x0, next instruction reads x0
    // lw x0, 0(x6) ; add x7, x0, x0
    id_ex_MemRead = 1;
    id_ex_rd_addr = 5'd0;
    if_id_rs1_addr = 5'd0;
    if_id_rs2_addr = 5'd0;
    #1;
    check({31'b0, stall}, 32'd0, "load to x0: no stall");

    // Test 6: every input combination (exhaustive, 2^16 = 65536)
    // i[15] = MemRead, i[14:10] = rd, i[9:5] = rs1, i[4:0] = rs2
    for (int i = 0; i < 65536; i++) begin
        id_ex_MemRead = i[15];
        id_ex_rd_addr = i[14:10];
        if_id_rs1_addr = i[9:5];
        if_id_rs2_addr = i[4:0];
        #1;
        expected_stall = id_ex_MemRead && (id_ex_rd_addr != 5'd0) && ((id_ex_rd_addr == if_id_rs1_addr) || (id_ex_rd_addr == if_id_rs2_addr));
        combinations++;
        if (stall !== expected_stall) begin
            mismatches++;
            if (mismatches <= 5) $display("Mismatch: MemRead=%b rd=%0d rs1=%0d rs2=%0d stall=%b expected=%b", id_ex_MemRead, id_ex_rd_addr, if_id_rs1_addr, if_id_rs2_addr, stall, expected_stall);
        end
    end
    check(combinations, 32'd65536, "every input combination applied");
    check(mismatches, 32'd0, "stall matches the load-use rule for all 65536 inputs");

    $display("=== %0d errors ===", errors);
    $finish;
end

endmodule
