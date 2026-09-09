module program_counter (
    input logic clk,
    input logic reset,
    input logic[31:0] pc,
    output logic[31:0] next_pc
);

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        next_pc <= 32'b0;
    end
    else begin
        next_pc <= pc;
    end
end

endmodule
