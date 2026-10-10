module register_file (
    input logic clk,
    input logic reset,

    input logic RegWrite,
    input logic[4:0] write_address,
    input logic[31:0] write_data,

    input logic[4:0] rs1_address,
    input logic[4:0] rs2_address,
    output logic[31:0] read_data1,
    output logic[31:0] read_data2
);

logic [31:0] registers [0:31];

always_ff @(posedge clk) begin
    if (reset) begin
        for (int i = 0; i < 32; i++) begin
            registers[i] <= 32'b0;
        end
    end
    else if (RegWrite && write_address != 5'b0) begin
        registers[write_address] <= write_data;
    end
end

assign read_data1 = (RegWrite && rs1_address == write_address && write_address != 5'b0) ? write_data : registers[rs1_address];
assign read_data2 = (RegWrite && rs2_address == write_address && write_address != 5'b0) ? write_data : registers[rs2_address];

endmodule