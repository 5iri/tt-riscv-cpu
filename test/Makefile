# Makefile — RV32I + VGA simulation
SIM              ?= icarus
TOPLEVEL_LANG    ?= verilog
SRC_DIR           = $(PWD)/../src

PROJECT_SOURCES = \
	tt_um_rv32_vga.v \
	riscv_cpu.v \
	execution_unit.v \
	decoder.v \
	alu.v \
	registerfile.v \
	pc.v \
	IF_ID.v \
	ID_EX.v \
	EX_MEM.v \
	MEM_WB.v \
	forwarding_unit.v \
	load_use_detector.v \
	store_load_detector.v \
	memory_unit.v \
	writeback.v \
	spi_instr_fetch.v \
	data_scratchpad.v \
	vga_sync.v \
	line_buffer.v

ifneq ($(GATES),yes)

SIM_BUILD        = sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

SIM_BUILD        = sim_build/gl
COMPILE_ARGS    += -DGL_TEST -DFUNCTIONAL -DUSE_POWER_PINS -DSIM -DUNIT_DELAY=\#1
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

COMPILE_ARGS    += -I$(SRC_DIR) -I$(SRC_DIR)/include

VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL         = tb
COCOTB_TEST_MODULES = test

include $(shell cocotb-config --makefiles)/Makefile.sim
