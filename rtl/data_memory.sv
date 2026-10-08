module data_memory import riscv_ref::*; #(
    parameter WIDTH = 32,
    parameter DEPTH = 512
)(
    input logic clk,
    input logic MemWrite,
    input logic [31:0] address,
    input logic [31:0] wr_data,
    input logic [2:0] funct3,
    output logic [31:0] rd_data
);

// Asynchronous read & Synchronous write

logic [WIDTH-1:0] word;
logic [WIDTH-1:0] memory [0:DEPTH-1];

assign word = memory[address[$clog2(DEPTH)+1:2]];

always_comb begin
    case (funct3)
        F3_LB: begin
            case(address[1:0])
                2'b00: rd_data = {{24{word[7]}}, word[7:0]};
                2'b01: rd_data = {{24{word[15]}}, word[15:8]};
                2'b10: rd_data = {{24{word[23]}}, word[23:16]};
                2'b11: rd_data = {{24{word[31]}}, word[31:24]};
            endcase
        end
        F3_LH: begin
            case (address[1]) // Half word, use address[1] instead of address[0] since half words always start on even addresses (address[0] is always 0)
                1'b0: rd_data = {{16{word[15]}}, word[15:0]};
                1'b1: rd_data = {{16{word[31]}}, word[31:16]};
            endcase
        end
        F3_LW: begin
            rd_data = word;
        end
        F3_LBU: begin
            case(address[1:0])
                2'b00: rd_data = {{24{1'b0}}, word[7:0]};
                2'b01: rd_data = {{24{1'b0}}, word[15:8]};
                2'b10: rd_data = {{24{1'b0}}, word[23:16]};
                2'b11: rd_data = {{24{1'b0}}, word[31:24]};
            endcase
        end
        F3_LHU: begin
            case (address[1]) // Half word, use address[1] instead of address[0] since half words always start on even addresses (address[0] is always 0)
                1'b0: rd_data = {{16{1'b0}}, word[15:0]};
                1'b1: rd_data = {{16{1'b0}}, word[31:16]};
            endcase
        end
        default: rd_data = 32'b0;
    endcase
end

always_ff @(posedge clk) begin
    if (MemWrite) begin
        case (funct3)
            F3_SB: begin
                case (address[1:0])
                    2'b00: memory[address[$clog2(DEPTH)+1:2]][7:0] <= wr_data[7:0];
                    2'b01: memory[address[$clog2(DEPTH)+1:2]][15:8] <= wr_data[7:0];
                    2'b10: memory[address[$clog2(DEPTH)+1:2]][23:16] <= wr_data[7:0];
                    2'b11: memory[address[$clog2(DEPTH)+1:2]][31:24] <= wr_data[7:0];
                endcase
            end
            F3_SH: begin
                case (address[1])
                    1'b0: memory[address[$clog2(DEPTH)+1:2]][15:0] <= wr_data[15:0];
                    1'b1: memory[address[$clog2(DEPTH)+1:2]][31:16] <= wr_data[15:0];
                endcase
            end
            F3_SW: begin
                memory[address[$clog2(DEPTH)+1:2]] <= wr_data;
            end
            default: ;
        endcase
    end
end
endmodule
