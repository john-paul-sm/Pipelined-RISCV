module tb_hazard_detection_unit;

logic id_ex_MemRead;
logic [4:0] id_ex_rd_address, if_id_rs1_address, if_id_rs2_address;
logic if_id_rs1_used, if_id_rs2_used;
logic stall, expected_stall;

int errors = 0;
int passed = 0;
int mismatches = 0;
int combinations = 0;

hazard_detection_unit dut (
    .id_ex_MemRead(id_ex_MemRead),
    .id_ex_rd_address(id_ex_rd_address),
    .if_id_rs1_address(if_id_rs1_address),
    .if_id_rs2_address(if_id_rs2_address),
    .if_id_rs1_used(if_id_rs1_used),
    .if_id_rs2_used(if_id_rs2_used),
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
    passed++;
    $display("Passed: %s", label);
end
endtask

initial begin

    // Test 1: load in EX, next instruction reads the load's rd as rs1
    // lw x5, 0(x6) ; add x7, x5, x8
    if_id_rs1_used = 1;
    if_id_rs2_used = 1;
    id_ex_MemRead = 1;
    id_ex_rd_address = 5'd5;
    if_id_rs1_address = 5'd5;
    if_id_rs2_address = 5'd8;
    #1;
    check({31'b0, stall}, 32'd1, "load rd = rs1: stall");

    // Test 2: load in EX, next instruction reads the load's rd as rs2
    // lw x5, 0(x6) ; add x7, x8, x5
    if_id_rs1_address = 5'd8;
    if_id_rs2_address = 5'd5;
    #1;
    check({31'b0, stall}, 32'd1, "load rd = rs2: stall");

    // Test 3: load in EX, next instruction does not read the load's rd
    // lw x5, 0(x6) ; add x7, x8, x9
    if_id_rs1_address = 5'd8;
    if_id_rs2_address = 5'd9;
    #1;
    check({31'b0, stall}, 32'd0, "load rd not read: no stall");

    // Test 4: no load in EX, register numbers match
    // add x5, x6, x7 ; add x7, x5, x5
    id_ex_MemRead = 0;
    if_id_rs1_address = 5'd5;
    if_id_rs2_address = 5'd5;
    #1;
    check({31'b0, stall}, 32'd0, "no load in EX: no stall");

    // Test 5: load to x0, next instruction reads x0
    // lw x0, 0(x6) ; add x7, x0, x0
    id_ex_MemRead = 1;
    id_ex_rd_address = 5'd0;
    if_id_rs1_address = 5'd0;
    if_id_rs2_address = 5'd0;
    #1;
    check({31'b0, stall}, 32'd0, "load to x0: no stall");

    // Test 6: I-type immediate bits [24:20] equal the load's rd, rs2 not used
    // lw x5, 0(x6) ; addi x7, x8, 5   (immediate 5 = 00101 sits in the rs2 field)
    id_ex_rd_address = 5'd5;
    if_id_rs1_address = 5'd8;
    if_id_rs2_address = 5'd5;
    if_id_rs1_used = 1;
    if_id_rs2_used = 0;
    #1;
    check({31'b0, stall}, 32'd0, "immediate bits match rd, rs2 not used: no stall");

    // Test 7: U-type immediate bits [19:15] equal the load's rd, rs1 not used
    // lw x5, 0(x6) ; lui x7, 0x28000   (immediate bits [19:15] = 00101)
    if_id_rs1_address = 5'd5;
    if_id_rs2_address = 5'd0;
    if_id_rs1_used = 0;
    if_id_rs2_used = 0;
    #1;
    check({31'b0, stall}, 32'd0, "immediate bits match rd, rs1 not used: no stall");

    // Test 8: every input combination (exhaustive, 2^18 = 262144)
    // i[17] = rs1_used, i[16] = rs2_used, i[15] = MemRead, i[14:10] = rd, i[9:5] = rs1, i[4:0] = rs2
    for (int i = 0; i < 262144; i++) begin
        if_id_rs1_used = i[17];
        if_id_rs2_used = i[16];
        id_ex_MemRead = i[15];
        id_ex_rd_address = i[14:10];
        if_id_rs1_address = i[9:5];
        if_id_rs2_address = i[4:0];
        #1;
        expected_stall = id_ex_MemRead && (id_ex_rd_address != 5'd0) && ((if_id_rs1_used && (id_ex_rd_address == if_id_rs1_address)) || (if_id_rs2_used && (id_ex_rd_address == if_id_rs2_address)));
        combinations++;
        if (stall !== expected_stall) begin
            mismatches++;
            if (mismatches <= 5) $display("Mismatch: rs1_used=%b rs2_used=%b MemRead=%b rd=%0d rs1=%0d rs2=%0d stall=%b expected=%b", if_id_rs1_used, if_id_rs2_used, id_ex_MemRead, id_ex_rd_address, if_id_rs1_address, if_id_rs2_address, stall, expected_stall);
        end
    end
    check(combinations, 32'd262144, "every input combination applied");
    check(mismatches, 32'd0, "stall matches the load-use rule for all 262144 inputs");

    $display("=== %0d passed, %0d errors ===", passed, errors);
    $finish;
end

endmodule
