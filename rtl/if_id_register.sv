module if_id_register (
    input logic clk,
    input logic reset,
    input logic stall,
    input logic flush,
    input logic valid_in,
    input logic [31:0] pc_in,
    input logic [31:0] instruction_in,
    output logic valid_out,
    output logic [31:0] pc_out,
    output logic [31:0] instruction_out
);

always_ff @(posedge clk) begin
    if (reset || flush) begin
        valid_out <= 1'b0;
        pc_out <= 32'b0;
        instruction_out <= 32'b0;
    end
    else if (stall) begin
        valid_out <= valid_out;
        pc_out <= pc_out;
        instruction_out <= instruction_out;
    end
    else begin
        valid_out <= valid_in;
        pc_out <= pc_in;
        instruction_out <= instruction_in;
    end
end

endmodule