// Wrapper: riscv_core + instruction_memory + data_memory.
// Used by the system testbench and the FPGA build. riscv_core is the synthesis boundary.

module riscv_top #(
    parameter string IMEM_FILE = "sim/instr_mem_test.hex"
)(
    input logic clk,
    input logic reset
);

logic [31:0] imem_address;
logic [31:0] imem_read_data;
logic [31:0] dmem_address;
logic [31:0] dmem_write_data;
logic dmem_MemWrite;
logic [2:0] dmem_funct3;
logic [31:0] dmem_read_data;

riscv_core u_core (
    .clk(clk),
    .reset(reset),
    .imem_address(imem_address),
    .imem_read_data(imem_read_data),
    .dmem_address(dmem_address),
    .dmem_write_data(dmem_write_data),
    .dmem_MemWrite(dmem_MemWrite),
    .dmem_funct3(dmem_funct3),
    .dmem_read_data(dmem_read_data)
);

instruction_memory #(
    .memory_file_path(IMEM_FILE)
) u_instruction_memory (
    .address_in(imem_address),
    .instruction(imem_read_data)
);

data_memory u_data_memory (
    .clk(clk),
    .MemWrite(dmem_MemWrite),
    .address(dmem_address),
    .write_data(dmem_write_data),
    .funct3(dmem_funct3),
    .read_data(dmem_read_data)
);

endmodule
