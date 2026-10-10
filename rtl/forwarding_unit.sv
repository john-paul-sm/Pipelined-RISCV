module forwarding_unit (
    input logic [4:0] id_ex_rs1_address,   // instruction_memory [19:15] -> if_id -> id_ex
    input logic [4:0] id_ex_rs2_address,   // instruction_memory [24:20] -> if_id -> id_ex
    input logic [4:0] ex_mem_rd_address,   // instruction_memory [11:7]  -> ... -> ex_mem
    input logic ex_mem_RegWrite,  // control_unit -> id_ex -> ex_mem
    input logic [4:0] mem_wb_rd_address,   // instruction_memory [11:7]  -> ... -> mem_wb
    input logic mem_wb_RegWrite,
 
    output logic [1:0] forward_a,        // -> FA mux select
    output logic [1:0] forward_b         // -> FB mux select
);
 
localparam logic [1:0] FORWARD_NONE = 2'b00;
localparam logic [1:0] FORWARD_WB = 2'b01;
localparam logic [1:0] FORWARD_MEM = 2'b10;
 
logic ex_mem_writes;
logic mem_wb_writes;
 
assign ex_mem_writes = ex_mem_RegWrite && (ex_mem_rd_address != 5'd0);
assign mem_wb_writes = mem_wb_RegWrite && (mem_wb_rd_address != 5'd0);
 
always_comb begin
    if (ex_mem_writes && (ex_mem_rd_address == id_ex_rs1_address)) begin
        forward_a = FORWARD_MEM;
    end
    else if (mem_wb_writes && (mem_wb_rd_address == id_ex_rs1_address)) begin
        forward_a = FORWARD_WB;
    end
    else begin
        forward_a = FORWARD_NONE;
    end
    if (ex_mem_writes && (ex_mem_rd_address == id_ex_rs2_address)) begin
        forward_b = FORWARD_MEM;
    end
    else if (mem_wb_writes && (mem_wb_rd_address == id_ex_rs2_address)) begin
        forward_b = FORWARD_WB;
    end
    else begin
        forward_b = FORWARD_NONE;
    end
end
endmodule
 