module fpga_top #(
    parameter string IMEM_FILE = "isa_m.hex"
)(
    input logic sysclk,
    input logic btn0,
    output logic [3:0] led
);

localparam logic [31:0] TOHOST = 32'h0000_07FC;

logic clk;
logic locked;

(* ASYNC_REG = "TRUE" *) logic reset_meta = 1'b1;
(* ASYNC_REG = "TRUE" *) logic core_reset = 1'b1;

logic [31:0] imem_address;
logic [31:0] imem_read_data;
logic [31:0] dmem_address;
logic [31:0] dmem_write_data;
logic dmem_MemWrite;
logic [2:0] dmem_funct3;
logic [31:0] dmem_read_data;

(* mark_debug = "true" *) logic [31:0] cycles;
(* mark_debug = "true" *) logic done;
(* mark_debug = "true" *) logic pass;

logic [25:0] heartbeat = 26'd0;

clk_wiz_0 u_clk_wiz (
    .clk_in1(sysclk),
    .reset(1'b0),
    .clk_out1(clk),
    .locked(locked)
);

always_ff @(posedge clk) begin
    reset_meta <= btn0 || !locked;
    core_reset <= reset_meta;
end

riscv_core u_core (
    .clk(clk),
    .reset(core_reset),
    .imem_address(imem_address),
    .imem_read_data(imem_read_data),
    .dmem_address(dmem_address),
    .dmem_write_data(dmem_write_data),
    .dmem_MemWrite(dmem_MemWrite),
    .dmem_funct3(dmem_funct3),
    .dmem_read_data(dmem_read_data)
);

instruction_memory #(
    .memory_file_path(IMEM_FILE)
) u_instruction_memory (
    .address_in(imem_address),
    .instruction(imem_read_data)
);

data_memory u_data_memory (
    .clk(clk),
    .MemWrite(dmem_MemWrite),
    .address(dmem_address),
    .write_data(dmem_write_data),
    .funct3(dmem_funct3),
    .read_data(dmem_read_data)
);

always_ff @(posedge clk) begin
    if (core_reset) begin
        cycles <= 32'd0;
        done <= 1'b0;
        pass <= 1'b0;
    end
    else if (!done) begin
        cycles <= cycles + 32'd1;
        if (dmem_MemWrite && (dmem_address == TOHOST)) begin
            done <= 1'b1;
            pass <= (dmem_write_data == 32'd1);
        end
    end
end

always_ff @(posedge clk) begin
    heartbeat <= heartbeat + 26'd1;
end

assign led[0] = done;
assign led[1] = done && pass;
assign led[2] = done && !pass;
assign led[3] = heartbeat[25];

endmodule
