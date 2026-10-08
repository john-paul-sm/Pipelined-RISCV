module instruction_memory #(
    parameter WIDTH = 32,
    parameter DEPTH = 512,
    parameter string memory_file_path = "sim/instr_mem_test.hex"
)(
    input logic [WIDTH-1:0] address_in,
    output logic [WIDTH-1:0] instruction
);

logic [WIDTH-1:0] memory [0:DEPTH-1]; // 2KB storage

initial begin
    $readmemh(memory_file_path, memory);
end

// discard lower two bits
assign instruction = memory[address_in[$clog2(DEPTH)+1:2]];


endmodule