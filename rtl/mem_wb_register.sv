module mem_wb_register (
    input logic clk,
    input logic reset,
    input logic stall,
    input logic flush,
    input logic valid_in,

    input logic [31:0] load_data_in,
    input logic [31:0] alu_result_in,
    input logic [31:0] pc_plus4_in,
    input logic [4:0] rd_addr_in,
    input logic RegWrite_in,
    input logic [1:0] MemToReg_in,

    output logic valid_out,
    output logic [31:0] load_data_out,
    output logic [31:0] alu_result_out,
    output logic [31:0] pc_plus4_out,
    output logic [4:0] rd_addr_out,
    output logic RegWrite_out,
    output logic [1:0] MemToReg_out
);

always_ff @(posedge clk) begin
    if (reset || flush) begin
        valid_out <= 1'b0;
        load_data_out <= '0;
        alu_result_out <= '0;
        pc_plus4_out <= '0;
        rd_addr_out <= '0;
        RegWrite_out <= '0;
        MemToReg_out <= '0;
    end
    else if (stall) begin
        valid_out <= valid_out;
        load_data_out <= load_data_out;
        alu_result_out <= alu_result_out;
        pc_plus4_out <= pc_plus4_out;
        rd_addr_out <= rd_addr_out;
        RegWrite_out <= RegWrite_out;
        MemToReg_out <= MemToReg_out;
    end
    else begin
        valid_out <= valid_in;
        load_data_out <= load_data_in;
        alu_result_out <= alu_result_in;
        pc_plus4_out <= pc_plus4_in;
        rd_addr_out <= rd_addr_in;
        RegWrite_out <= RegWrite_in;
        MemToReg_out <= MemToReg_in;
    end
end
endmodule