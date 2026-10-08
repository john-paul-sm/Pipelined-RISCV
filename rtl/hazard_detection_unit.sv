module hazard_detection_unit (
    input logic id_ex_MemRead,   // control_unit.MemRead (ID) -> id_ex_register
    input logic [4:0] id_ex_rd_addr,   // instruction_memory [11:7]  -> if_id -> id_ex
    input logic [4:0] if_id_rs1_addr,  // instruction_memory [19:15] -> if_id, sliced in ID
    input logic [4:0] if_id_rs2_addr,  // instruction_memory [24:20] -> if_id, sliced in ID
    output logic stall            // -> program_counter, if_id_register, id_ex_register.flush
);
 
// EX holds a load that writes a real register (not x0)
logic load_in_ex;
    
assign load_in_ex = id_ex_MemRead && (id_ex_rd_addr != 5'd0);
 
// the ID instruction reads that register on either operand
logic rs_match;
assign rs_match = (id_ex_rd_addr == if_id_rs1_addr) || (id_ex_rd_addr == if_id_rs2_addr);
 
// stall only when both are true. A continuous assign drives stall on every path, so no latch can form
assign stall = load_in_ex && rs_match;
 
endmodule
 