module tb_forwarding_unit;

logic [4:0] id_ex_rs1_address, id_ex_rs2_address;
logic [4:0] ex_mem_rd_address, mem_wb_rd_address;
logic ex_mem_RegWrite, mem_wb_RegWrite;
logic [1:0] forward_a, forward_b;
logic [1:0] expected_a, expected_b;

int errors = 0;
int passed = 0;
int mismatches = 0;
int combinations = 0;

forwarding_unit dut (
    .id_ex_rs1_address(id_ex_rs1_address),
    .id_ex_rs2_address(id_ex_rs2_address),
    .ex_mem_rd_address(ex_mem_rd_address),
    .ex_mem_RegWrite(ex_mem_RegWrite),
    .mem_wb_rd_address(mem_wb_rd_address),
    .mem_wb_RegWrite(mem_wb_RegWrite),
    .forward_a(forward_a),
    .forward_b(forward_b)
);

initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("tb_forwarding_unit.vcd");
        $dumpvars(0, tb_forwarding_unit);
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

function automatic logic [1:0] reference(
    input logic [4:0] rs,
    input logic ex_mem_writes,
    input logic [4:0] ex_mem_rd,
    input logic mem_wb_writes,
    input logic [4:0] mem_wb_rd
);
    if (ex_mem_writes && (ex_mem_rd != 5'd0) && (ex_mem_rd == rs)) return 2'b10;
    if (mem_wb_writes && (mem_wb_rd != 5'd0) && (mem_wb_rd == rs)) return 2'b01;
    return 2'b00;
endfunction

initial begin

    // Test 1: rs1 written by the instruction in MEM
    // add x5, ... (MEM) ; add x7, x5, x6 (EX)
    id_ex_rs1_address = 5'd5;
    id_ex_rs2_address = 5'd6;
    ex_mem_RegWrite = 1;
    ex_mem_rd_address = 5'd5;
    mem_wb_RegWrite = 0;
    mem_wb_rd_address = 5'd0;
    #1;
    check({30'b0, forward_a}, 32'b10, "rs1 = EX/MEM rd: forward from MEM");

    // Test 2: rs2 written by the instruction in WB
    // add x6, ... (WB) ; add x7, x5, x6 (EX)
    ex_mem_RegWrite = 0;
    ex_mem_rd_address = 5'd0;
    mem_wb_RegWrite = 1;
    mem_wb_rd_address = 5'd6;
    #1;
    check({30'b0, forward_b}, 32'b01, "rs2 = MEM/WB rd: forward from WB");

    // Test 3: MEM and WB both write rs: the newer value (MEM) wins
    // add x5 (WB) ; add x5 (MEM) ; add x7, x5, x5 (EX)
    id_ex_rs1_address = 5'd5;
    id_ex_rs2_address = 5'd5;
    ex_mem_RegWrite = 1;
    ex_mem_rd_address = 5'd5;
    mem_wb_RegWrite = 1;
    mem_wb_rd_address = 5'd5;
    #1;
    check({28'b0, forward_a, forward_b}, 32'b1010, "both stages write rs: MEM has priority");

    // Test 4: writes to x0 are never forwarded
    id_ex_rs1_address = 5'd0;
    id_ex_rs2_address = 5'd0;
    ex_mem_rd_address = 5'd0;
    mem_wb_rd_address = 5'd0;
    #1;
    check({28'b0, forward_a, forward_b}, 32'b0000, "writes to x0 are never forwarded");

    // Test 5: RegWrite = 0 (store or branch in MEM/WB): no forward
    id_ex_rs1_address = 5'd5;
    id_ex_rs2_address = 5'd5;
    ex_mem_RegWrite = 0;
    ex_mem_rd_address = 5'd5;
    mem_wb_RegWrite = 0;
    mem_wb_rd_address = 5'd5;
    #1;
    check({28'b0, forward_a, forward_b}, 32'b0000, "RegWrite = 0: no forward");

    // Test 6: every input combination (exhaustive, 2^22 = 4194304)
    // i[21:17] = rs1, i[16:12] = rs2, i[11] / i[10:6] = EX/MEM RegWrite / rd, i[5] / i[4:0] = MEM/WB RegWrite / rd
    for (int i = 0; i < 4194304; i++) begin
        id_ex_rs1_address = i[21:17];
        id_ex_rs2_address = i[16:12];
        ex_mem_RegWrite = i[11];
        ex_mem_rd_address = i[10:6];
        mem_wb_RegWrite = i[5];
        mem_wb_rd_address = i[4:0];
        #1;
        expected_a = reference(id_ex_rs1_address, ex_mem_RegWrite, ex_mem_rd_address, mem_wb_RegWrite, mem_wb_rd_address);
        expected_b = reference(id_ex_rs2_address, ex_mem_RegWrite, ex_mem_rd_address, mem_wb_RegWrite, mem_wb_rd_address);
        combinations++;
        if ((forward_a !== expected_a) || (forward_b !== expected_b)) begin
            mismatches++;
            if (mismatches <= 5) $display("Mismatch: rs1=%0d rs2=%0d ex_mem=%b/%0d mem_wb=%b/%0d forward=%b/%b expected=%b/%b", id_ex_rs1_address, id_ex_rs2_address, ex_mem_RegWrite, ex_mem_rd_address, mem_wb_RegWrite, mem_wb_rd_address, forward_a, forward_b, expected_a, expected_b);
        end
    end
    check(combinations, 32'd4194304, "every input combination applied");
    check(mismatches, 32'd0, "forward_a and forward_b match the forwarding rule for all 4194304 inputs");

    $display("=== %0d passed, %0d errors ===", passed, errors);
    $finish;
end

endmodule
