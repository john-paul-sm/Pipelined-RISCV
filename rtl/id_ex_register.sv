module id_ex_register (
    input logic clk,
    input logic reset,
    input logic stall,
    input logic flush,
    input logic valid_in,

    // Data from ID
    input logic [31:0] pc_in,          // AUIPC, branch/JAL target, PC+4
    input logic [31:0] rs1_data_in,    // ALU operand A
    input logic [31:0] rs2_data_in,    // ALU operand B / store data
    input logic [31:0] imm_in,         // immediate operand
    input logic [4:0] rs1_addr_in,    // for the forwarding unit
    input logic [4:0] rs2_addr_in,    // for the forwarding unit
    input logic [4:0] rd_addr_in,     // destination, travels to WB
    input logic [2:0] funct3_in,      // branch type, load/store width

    // Control from Control Unit
    // EX
    input logic [3:0] alu_op_in,
    input logic [1:0] ALUSrcA_in,
    input logic ALUSrcB_in,
    input logic Branch_in,
    input logic Jump_in,
    input logic Jalr_in,
    // MEM
    input logic MemRead_in,
    input logic MemWrite_in,
    // WB
    input logic RegWrite_in,
    input logic [1:0] MemToReg_in,

    // Outputs to EX
    output logic valid_out,
    output logic [31:0] pc_out,
    output logic [31:0] rs1_data_out,
    output logic [31:0] rs2_data_out,
    output logic [31:0] imm_out,
    output logic [4:0] rs1_addr_out,
    output logic [4:0] rs2_addr_out,
    output logic [4:0] rd_addr_out,
    output logic [2:0] funct3_out,

    output logic [3:0] alu_op_out,
    output logic [1:0] ALUSrcA_out,
    output logic ALUSrcB_out,
    output logic Branch_out,
    output logic Jump_out,
    output logic Jalr_out,
    output logic MemRead_out,
    output logic MemWrite_out,
    output logic RegWrite_out,
    output logic [1:0] MemToReg_out
);

always_ff @(posedge clk) begin
    if (reset || flush) begin
        valid_out <= 1'b0;
        // Bubble: RegWrite, MemRead, MemWrite, Branch, Jump all 0,
        // so this slot cannot change any register, memory or the PC.
        pc_out <= 32'b0;
        rs1_data_out <= 32'b0;
        rs2_data_out <= 32'b0;
        imm_out <= 32'b0;
        rs1_addr_out <= 5'b0;
        rs2_addr_out <= 5'b0;
        rd_addr_out <= 5'b0;
        funct3_out <= 3'b0;

        alu_op_out <= 4'b0;
        ALUSrcA_out <= 2'b0;
        ALUSrcB_out <= 1'b0;
        Branch_out <= 1'b0;
        Jump_out <= 1'b0;
        Jalr_out <= 1'b0;
        MemRead_out  <= 1'b0;
        MemWrite_out <= 1'b0;
        RegWrite_out <= 1'b0;
        MemToReg_out <= 2'b0;
    end
    else if (stall) begin
        valid_out <= valid_out;
        pc_out <= pc_out;
        rs1_data_out <= rs1_data_out;
        rs2_data_out <= rs2_data_out;
        imm_out <= imm_out;
        rs1_addr_out <= rs1_addr_out;
        rs2_addr_out <= rs2_addr_out;
        rd_addr_out <= rd_addr_out;
        funct3_out <= funct3_out;
 
        alu_op_out <= alu_op_out;
        ALUSrcA_out<= ALUSrcA_out;
        ALUSrcB_out <= ALUSrcB_out;
        Branch_out <= Branch_out;
        Jump_out <= Jump_out;
        Jalr_out <= Jalr_out;
        MemRead_out  <= MemRead_out;
        MemWrite_out <= MemWrite_out;
        RegWrite_out <= RegWrite_out;
        MemToReg_out <= MemToReg_out;
    end
    else begin
        valid_out <= valid_in;
        pc_out <= pc_in;
        rs1_data_out <= rs1_data_in;
        rs2_data_out <= rs2_data_in;
        imm_out <= imm_in;
        rs1_addr_out <= rs1_addr_in;
        rs2_addr_out <= rs2_addr_in;
        rd_addr_out <= rd_addr_in;
        funct3_out <= funct3_in;
        alu_op_out <= alu_op_in;
        ALUSrcA_out <= ALUSrcA_in;
        ALUSrcB_out <= ALUSrcB_in;
        Branch_out <= Branch_in;
        Jump_out <= Jump_in;
        Jalr_out <= Jalr_in;
        MemRead_out  <= MemRead_in;
        MemWrite_out <= MemWrite_in;
        RegWrite_out <= RegWrite_in;
        MemToReg_out <= MemToReg_in;
    end
end

endmodule