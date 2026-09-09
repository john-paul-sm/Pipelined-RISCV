DUT ?= register_file
SIM = verilator
TOPLEVEL_LANG = verilog
VERILOG_SOURCES = ../../rtl/riscv_ref.sv ../../rtl/$(DUT).sv
TOPLEVEL = $(DUT)
MODULE = tb_$(DUT)
include $(shell cocotb-config --makefiles)/Makefile.sim