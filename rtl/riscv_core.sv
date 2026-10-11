// 5-stage in-order RV32I pipeline: IF -> ID -> EX -> MEM -> WB.
// Synthesis boundary: contains every pipeline module and all glue logic, but not the
// two memories. The memories sit in riscv_top and connect through the memory ports.
//
// Wire prefix = the stage that holds the instruction the value belongs to.
// Forwarding wires keep their own prefix (mem_forward_value, wb_data) although EX reads them.
//
// Mux labels:
//   FA / FB : forwarding muxes for ALU operand a / b (select forward_a / forward_b)
//   SA / SB : ALU source muxes for ALU input a / b   (select ALUSrcA / ALUSrcB)
//   T       : target mux                             (select Jalr)
//   M       : forwarded value from the instruction in MEM (mem_forward_value)
//   W       : forwarded value from the instruction in WB  (wb_data)

module riscv_core (
    input logic clk,
    input logic reset,

    output logic [31:0] imem_address, // instruction_memory.address_in
    input logic [31:0] imem_read_data, // instruction_memory.instruction

    output logic [31:0] dmem_address, // data_memory.address
    output logic [31:0] dmem_write_data, // data_memory.write_data
    output logic dmem_MemWrite, // data_memory.MemWrite
    output logic [2:0] dmem_funct3, // data_memory.funct3
    input logic [31:0] dmem_read_data // data_memory.read_data
);

// Hazard / redirect control
logic load_use_stall; // hazard_detection_unit.stall (load-use)
logic mul_div_busy; // mul_div_unit.busy (M instruction in EX not finished)
logic frontend_stall; // hold PC and IF/ID: load-use or M instruction
logic ex_redirect; // branch_flush_unit.redirect (taken branch / jump)

// IF
logic [31:0] if_pc;
logic [31:0] if_pc_plus4;
logic [31:0] if_next_pc;
logic [31:0] if_instruction;

// ID
logic [31:0] id_pc;
logic id_valid;
logic [31:0] id_instruction;
logic [4:0] id_rs1_address;
logic [4:0] id_rs2_address;
logic [4:0] id_rd_address;
logic [2:0] id_funct3;
logic [31:0] id_rs1_data;
logic [31:0] id_rs2_data;
logic [31:0] id_immediate;
logic id_RegWrite;
logic id_MemRead;
logic id_MemWrite;
logic [1:0] id_MemToReg;
logic [1:0] id_ALUSrcA;
logic id_ALUSrcB;
logic id_Branch;
logic id_Jump;
logic id_Jalr;
logic id_MulDiv;
logic id_rs1_used;
logic id_rs2_used;
logic [3:0] id_alu_op;

// EX (id_ex_register outputs, then values made in EX)
logic [31:0] ex_pc;
logic ex_valid;
logic [31:0] ex_rs1_data;
logic [31:0] ex_rs2_data;
logic [31:0] ex_immediate;
logic [4:0] ex_rs1_address;
logic [4:0] ex_rs2_address;
logic [4:0] ex_rd_address;
logic [2:0] ex_funct3;
logic [3:0] ex_alu_op;
logic [1:0] ex_ALUSrcA;
logic ex_ALUSrcB;
logic ex_Branch;
logic ex_Jump;
logic ex_Jalr;
logic ex_MulDiv;
logic ex_MemRead;
logic ex_MemWrite;
logic ex_RegWrite;
logic [1:0] ex_MemToReg;

logic [1:0] ex_forward_a; // FA select
logic [1:0] ex_forward_b; // FB select
logic [31:0] ex_forwarded_rs1; // FA output: current rs1 value
logic [31:0] ex_forwarded_rs2; // FB output: current rs2 value
logic [31:0] ex_alu_operand_a; // SA output
logic [31:0] ex_alu_operand_b; // SB output
logic [31:0] ex_alu_result;
logic [31:0] ex_mul_div_result; // mul_div_unit result
logic [31:0] ex_result; // ALU result or mul_div_unit result -> EX/MEM
logic [31:0] ex_pc_target; // B-type / JAL target
logic [31:0] ex_target; // T output: redirect address
logic [31:0] ex_pc_plus4; // JAL / JALR link value

// MEM (ex_mem_register outputs, then values made in MEM)
logic [31:0] mem_alu_result;
logic mem_valid;
logic [31:0] mem_rs2_data;
logic [31:0] mem_pc_plus4;
logic [4:0] mem_rd_address;
logic [2:0] mem_funct3;
logic mem_MemWrite;
logic mem_RegWrite;
logic [1:0] mem_MemToReg;
logic [31:0] mem_load_data;
logic [31:0] mem_forward_value; // M

// WB (mem_wb_register outputs, then the WB mux)
logic [31:0] wb_load_data;
logic wb_valid;
logic [31:0] wb_alu_result;
logic [31:0] wb_pc_plus4;
logic [4:0] wb_rd_address;
logic wb_RegWrite;
logic [1:0] wb_MemToReg;
logic [31:0] wb_data; // W

assign frontend_stall = load_use_stall || mul_div_busy;

assign if_pc_plus4 = if_pc + 32'd4;


assign if_next_pc = ex_redirect ? ex_target : if_pc_plus4;

program_counter u_program_counter (
    .clk(clk),
    .reset(reset),
    .stall(frontend_stall),
    .pc_in(if_next_pc),
    .pc_out(if_pc)
);

assign imem_address = if_pc;
assign if_instruction = imem_read_data;

if_id_register u_if_id (
    .clk(clk),
    .reset(reset),
    .stall(frontend_stall), // load-use: keep the dependent instruction in ID; M busy: hold
    .flush(ex_redirect), // taken branch / jump: the instruction in IF is wrong-path
    .valid_in(1'b1),
    .valid_out(id_valid),
    .pc_in(if_pc),
    .instruction_in(if_instruction),
    .pc_out(id_pc),
    .instruction_out(id_instruction)
);

assign id_rs1_address = id_instruction[19:15];
assign id_rs2_address = id_instruction[24:20];
assign id_rd_address = id_instruction[11:7];
assign id_funct3 = id_instruction[14:12];

control_unit u_control_unit (
    .instruction(id_instruction),
    .RegWrite(id_RegWrite),
    .MemRead(id_MemRead),
    .MemWrite(id_MemWrite),
    .MemToReg(id_MemToReg),
    .ALUSrcA(id_ALUSrcA),
    .ALUSrcB(id_ALUSrcB),
    .Branch(id_Branch),
    .Jump(id_Jump),
    .Jalr(id_Jalr),
    .MulDiv(id_MulDiv),
    .rs1_used(id_rs1_used),
    .rs2_used(id_rs2_used),
    .alu_op(id_alu_op)
);

immediate_generator u_immediate_generator (
    .instruction(id_instruction),
    .immediate(id_immediate)
);

// Read ports use ID wires, the write port uses WB wires (write-first).
register_file u_register_file (
    .clk(clk),
    .reset(reset),
    .RegWrite(wb_RegWrite),
    .write_address(wb_rd_address),
    .write_data(wb_data),
    .rs1_address(id_rs1_address),
    .rs2_address(id_rs2_address),
    .read_data1(id_rs1_data),
    .read_data2(id_rs2_data)
);

hazard_detection_unit u_hazard_detection_unit (
    .id_ex_MemRead(ex_MemRead),
    .id_ex_rd_address(ex_rd_address),
    .if_id_rs1_address(id_rs1_address),
    .if_id_rs2_address(id_rs2_address),
    .if_id_rs1_used(id_rs1_used),
    .if_id_rs2_used(id_rs2_used),
    .stall(load_use_stall)
);

id_ex_register u_id_ex (
    .clk(clk),
    .reset(reset),
    .stall(mul_div_busy), // holds the M instruction in EX until mul_div_unit finishes
    .flush(load_use_stall || ex_redirect), // load-use bubble, or kill a wrong-path instruction
    .valid_in(id_valid),
    .valid_out(ex_valid),

    .pc_in(id_pc),
    .rs1_data_in(id_rs1_data),
    .rs2_data_in(id_rs2_data),
    .immediate_in(id_immediate),
    .rs1_address_in(id_rs1_address),
    .rs2_address_in(id_rs2_address),
    .rd_address_in(id_rd_address),
    .funct3_in(id_funct3),

    .alu_op_in(id_alu_op),
    .ALUSrcA_in(id_ALUSrcA),
    .ALUSrcB_in(id_ALUSrcB),
    .Branch_in(id_Branch),
    .Jump_in(id_Jump),
    .Jalr_in(id_Jalr),
    .MulDiv_in(id_MulDiv),
    .MemRead_in(id_MemRead),
    .MemWrite_in(id_MemWrite),
    .RegWrite_in(id_RegWrite),
    .MemToReg_in(id_MemToReg),

    .pc_out(ex_pc),
    .rs1_data_out(ex_rs1_data),
    .rs2_data_out(ex_rs2_data),
    .immediate_out(ex_immediate),
    .rs1_address_out(ex_rs1_address),
    .rs2_address_out(ex_rs2_address),
    .rd_address_out(ex_rd_address),
    .funct3_out(ex_funct3),

    .alu_op_out(ex_alu_op),
    .ALUSrcA_out(ex_ALUSrcA),
    .ALUSrcB_out(ex_ALUSrcB),
    .Branch_out(ex_Branch),
    .Jump_out(ex_Jump),
    .Jalr_out(ex_Jalr),
    .MulDiv_out(ex_MulDiv),
    .MemRead_out(ex_MemRead),
    .MemWrite_out(ex_MemWrite),
    .RegWrite_out(ex_RegWrite),
    .MemToReg_out(ex_MemToReg)
);


forwarding_unit u_forwarding_unit (
    .id_ex_rs1_address(ex_rs1_address),
    .id_ex_rs2_address(ex_rs2_address),
    .ex_mem_rd_address(mem_rd_address),
    .ex_mem_RegWrite(mem_RegWrite),
    .mem_wb_rd_address(wb_rd_address),
    .mem_wb_RegWrite(wb_RegWrite),
    .forward_a(ex_forward_a),
    .forward_b(ex_forward_b)
);

// FA / FB: 00 = register file, 10 = M, 01 = W. 11 is never generated.
always_comb begin
    case (ex_forward_a)
        2'b10: ex_forwarded_rs1 = mem_forward_value;
        2'b01: ex_forwarded_rs1 = wb_data;
        default: ex_forwarded_rs1 = ex_rs1_data;
    endcase
end

always_comb begin
    case (ex_forward_b)
        2'b10: ex_forwarded_rs2 = mem_forward_value;
        2'b01: ex_forwarded_rs2 = wb_data;
        default: ex_forwarded_rs2 = ex_rs2_data;
    endcase
end


always_comb begin
    case (ex_ALUSrcA)
        2'b01: ex_alu_operand_a = ex_pc;
        2'b10: ex_alu_operand_a = 32'd0;
        default: ex_alu_operand_a = ex_forwarded_rs1;
    endcase
end


assign ex_alu_operand_b = ex_ALUSrcB ? ex_immediate : ex_forwarded_rs2;

alu u_alu (
    .operand_a(ex_alu_operand_a),
    .operand_b(ex_alu_operand_b),
    .alu_op(ex_alu_op),
    .result(ex_alu_result)
);

mul_div_unit u_mul_div_unit (
    .clk(clk),
    .reset(reset),
    .start(ex_MulDiv),
    .funct3(ex_funct3),
    .operand_a(ex_forwarded_rs1),
    .operand_b(ex_forwarded_rs2),
    .busy(mul_div_busy),
    .result(ex_mul_div_result)
);

assign ex_result = ex_MulDiv ? ex_mul_div_result : ex_alu_result;

assign ex_pc_target = ex_pc + ex_immediate;


assign ex_target = ex_Jalr ? (ex_alu_result & ~32'd1) : ex_pc_target;

assign ex_pc_plus4 = ex_pc + 32'd4;

branch_flush_unit u_branch_flush_unit (
    .Branch(ex_Branch),
    .Jump(ex_Jump),
    .funct3(ex_funct3),
    .operand_a(ex_forwarded_rs1),
    .operand_b(ex_forwarded_rs2),
    .redirect(ex_redirect)
);

ex_mem_register u_ex_mem (
    .clk(clk),
    .reset(reset),
    .stall(1'b0),
    .flush(mul_div_busy), // bubble while the M instruction stays in EX
    .valid_in(ex_valid),
    .valid_out(mem_valid),

    .alu_result_in(ex_result),
    .rs2_data_in(ex_forwarded_rs2), // store data must be the forwarded rs2 value
    .pc_plus4_in(ex_pc_plus4),
    .rd_address_in(ex_rd_address),
    .funct3_in(ex_funct3),
    .MemWrite_in(ex_MemWrite),
    .RegWrite_in(ex_RegWrite),
    .MemToReg_in(ex_MemToReg),

    .alu_result_out(mem_alu_result),
    .rs2_data_out(mem_rs2_data),
    .pc_plus4_out(mem_pc_plus4),
    .rd_address_out(mem_rd_address),
    .funct3_out(mem_funct3),
    .MemWrite_out(mem_MemWrite),
    .RegWrite_out(mem_RegWrite),
    .MemToReg_out(mem_MemToReg)
);

assign dmem_address = mem_alu_result;
assign dmem_write_data = mem_rs2_data;
assign dmem_MemWrite = mem_MemWrite;
assign dmem_funct3 = mem_funct3;
assign mem_load_data = dmem_read_data;

assign mem_forward_value = (mem_MemToReg == 2'b10) ? mem_pc_plus4 : mem_alu_result;

mem_wb_register u_mem_wb (
    .clk(clk),
    .reset(reset),
    .stall(1'b0),
    .flush(1'b0),
    .valid_in(mem_valid),
    .valid_out(wb_valid),

    .load_data_in(mem_load_data),
    .alu_result_in(mem_alu_result),
    .pc_plus4_in(mem_pc_plus4),
    .rd_address_in(mem_rd_address),
    .RegWrite_in(mem_RegWrite),
    .MemToReg_in(mem_MemToReg),

    .load_data_out(wb_load_data),
    .alu_result_out(wb_alu_result),
    .pc_plus4_out(wb_pc_plus4),
    .rd_address_out(wb_rd_address),
    .RegWrite_out(wb_RegWrite),
    .MemToReg_out(wb_MemToReg)
);

always_comb begin
    case (wb_MemToReg)
        2'b01: wb_data = wb_load_data;
        2'b10: wb_data = wb_pc_plus4;
        default: wb_data = wb_alu_result;
    endcase
end

endmodule
