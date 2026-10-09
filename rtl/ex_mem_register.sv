module ex_mem_register (
    input logic clk,
    input logic reset,
    input logic stall,
    input logic flush,
    input logic valid_in,

    input logic [31:0] alu_result_in, // ALU result
    input logic [31:0] rs2_data_in, // rd_data2 from the register_file
    input logic [31:0] pc_plus4_in, // 
    input logic [4:0] rd_addr_in, // instruction memory
    input logic [2:0] funct3_in, // instruction memory
    input logic MemWrite_in, // control unit
    input logic RegWrite_in, // control unit
    input logic [1:0] MemToReg_in, // control unit

    output logic valid_out,
    output logic [31:0] alu_result_out,
    output logic [31:0] rs2_data_out, // data memory
    output logic [31:0] pc_plus4_out, // 
    output logic [4:0] rd_addr_out,
    output logic [2:0] funct3_out, // data memory
    output logic MemWrite_out, // data memory
    output logic RegWrite_out,
    output logic [1:0] MemToReg_out
);

always_ff @(posedge clk) begin
    if (reset || flush) begin
        valid_out <= 1'b0;
        alu_result_out <= '0;
        rs2_data_out <= '0;
        pc_plus4_out <= '0;
        rd_addr_out <= '0;
        funct3_out <= '0;
        MemWrite_out <= '0;
        RegWrite_out <= '0;
        MemToReg_out <= '0;
    end
    else if (stall) begin
        valid_out <= valid_out;
        alu_result_out <= alu_result_out;
        rs2_data_out <= rs2_data_out;
        pc_plus4_out <= pc_plus4_out;
        rd_addr_out <= rd_addr_out;
        funct3_out <= funct3_out;
        MemWrite_out <= MemWrite_out;
        RegWrite_out <= RegWrite_out;
        MemToReg_out <= MemToReg_out;
    end
    else begin
        valid_out <= valid_in;
        alu_result_out <= alu_result_in;
        rs2_data_out <= rs2_data_in;
        pc_plus4_out <= pc_plus4_in;
        rd_addr_out <= rd_addr_in;
        funct3_out <= funct3_in;
        MemWrite_out <= MemWrite_in;
        RegWrite_out <= RegWrite_in;
        MemToReg_out <= MemToReg_in;
    end
end


endmodule