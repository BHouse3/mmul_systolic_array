
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

dut ?= top

PWD=$(shell pwd)
VERILOG_SOURCES = $(PWD)/src/pe.v \
                  $(PWD)/src/input_buffer.v \
                  $(PWD)/src/output_buffer.v \
                  $(PWD)/src/grid.v \
                  $(PWD)/src/axi_stream.v \
				  $(PWD)/src/top.v

# toplevel is the name of the verilog module to test
# cocotb_test_modules is the name of the python test file
TOPLEVEL := $(dut)
COCOTB_TEST_MODULES   := test.test_$(dut)

# # These override parameters in the top-level Verilog module
# COMPILE_ARGS += -P$(TOPLEVEL).N=4
# COMPILE_ARGS += -P$(TOPLEVEL).DATA_WIDTH=8
# COMPILE_ARGS += -P$(TOPLEVEL).RESULT_WIDTH=32

# waveform gen
WAVES = 1
WAVE_FORMAT = fst

include $(shell cocotb-config --makefiles)/Makefile.sim