import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge

@cocotb.test()
async def check_reset(dut):

    # Checks the reset functionality of the register file module
    
    c = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(c.start())
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0 
    await RisingEdge(dut.clk)

    for i in range(1,32):
        dut.rs1_addr.value = i
        dut.rs2_addr.value = i
        await Timer(10, units="ns")
        assert dut.rd_data1.value == 0 and dut.rd_data2.value == 0



