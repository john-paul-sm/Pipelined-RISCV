module register_file (
    input logic clk,
    input logic reset,

    input logic [4:0] rs1_addr,
    input logic [4:0] rs2_addr,
    output logic [31:0] rd_data1,
    output logic [31:0] rd_data2,

    input logic RegWrite,
    input logic [4:0] wr_addr,
    input logic [31:0] wr_data
);

logic [31:0] register [0:31]; //  32 registers, 32-bits wide

// Write first, read second

assign rd_data1 = (RegWrite && wr_addr == rs1_addr && rs1_addr != 5'b0) ? wr_data : register[rs1_addr];
assign rd_data2 = (RegWrite && wr_addr == rs2_addr && rs2_addr != 5'b0) ? wr_data : register[rs2_addr];

// Reset all register contents to 32'b0 if reset is asserted. Otherwise, put WriteData into the registers.

always_ff @(posedge clk) begin
    if (reset) begin
        for (int i = 0; i < 32; i++)
            register[i] <= '0;
    end
    else begin
        if (RegWrite && wr_addr != 5'b0) begin
            register[wr_addr] <= wr_data;
        end
    end
end

endmodule
