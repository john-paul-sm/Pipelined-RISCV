// Wrapper: riscv_core + instruction_memory + data_memory.
// Used by the system testbench and the FPGA build. riscv_core is the synthesis boundary.

module riscv_top #(
    parameter string IMEM_FILE = "sim/instr_mem_test.hex"
)(
    input logic clk,
    input logic reset
);

logic [31:0] imem_addr;
logic [31:0] imem_rdata;
logic [31:0] dmem_addr;
logic [31:0] dmem_wdata;
logic dmem_MemWrite;
logic [2:0] dmem_funct3;
logic [31:0] dmem_rdata;

riscv_core u_core (
    .clk(clk),
    .reset(reset),
    .imem_addr(imem_addr),
    .imem_rdata(imem_rdata),
    .dmem_addr(dmem_addr),
    .dmem_wdata(dmem_wdata),
    .dmem_MemWrite(dmem_MemWrite),
    .dmem_funct3(dmem_funct3),
    .dmem_rdata(dmem_rdata)
);

instruction_memory #(
    .memory_file_path(IMEM_FILE)
) u_imem (
    .address_in(imem_addr),
    .instruction(imem_rdata)
);

data_memory u_dmem (
    .clk(clk),
    .MemWrite(dmem_MemWrite),
    .address(dmem_addr),
    .wr_data(dmem_wdata),
    .funct3(dmem_funct3),
    .rd_data(dmem_rdata)
);

endmodule
