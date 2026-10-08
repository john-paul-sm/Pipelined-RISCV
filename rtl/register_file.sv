module register_file (
    input logic clk,
    input logic reset,

    input logic RegWrite,
    input logic[4:0] wr_addr,
    input logic[31:0] wr_data,

    input logic[4:0] rs1_addr,
    input logic[4:0] rs2_addr,
    output logic[31:0] rd_data1,
    output logic[31:0] rd_data2
);

logic [31:0] registers [0:31];

always_ff @(posedge clk) begin
    if (reset) begin
        for (int i = 0; i < 32; i++) begin
            registers[i] <= 32'b0;
        end
    end
    else if (RegWrite && wr_addr != 5'b0) begin
        registers[wr_addr] <= wr_data;
    end
end

assign rd_data1 = (RegWrite && rs1_addr == wr_addr && wr_addr != 5'b0) ? wr_data : registers[rs1_addr];
assign rd_data2 = (RegWrite && rs2_addr == wr_addr && wr_addr != 5'b0) ? wr_data : registers[rs2_addr];

endmodule