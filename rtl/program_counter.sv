module program_counter (
    input logic clk,
    input logic reset,
    input logic stall,
    input logic [31:0] pc_in,
    output logic [31:0] pc_out
);

always_ff @(posedge clk) begin
    if (reset) begin
        pc_out <= 32'h0000_0000;
    end
    else if (stall) begin
        pc_out <= pc_out;
    end
    else begin
        pc_out <= pc_in;
    end
end

endmodule