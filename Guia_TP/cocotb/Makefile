SIM ?= ghdl
TOPLEVEL_LANG ?= vhdl

HDL_DIR := $(abspath ../CLP_CESE/CLP_CESE.srcs/sources_1/new)

VHDL_SOURCES := \
	$(HDL_DIR)/adder_1_bit.vhd \
	$(HDL_DIR)/adder_4_bits.vhd \
	$(HDL_DIR)/mux_2_a_1.vhd \
	$(HDL_DIR)/comparador_igual.vhd \
	$(HDL_DIR)/registro_N_bits.vhd \
	$(HDL_DIR)/contador_bcd.vhd \
	$(HDL_DIR)/contador_N_clk.vhd \
	$(HDL_DIR)/contador_bcd_1_seg.vhd

TOPLEVEL := contador_bcd_1_seg
MODULE := test_contador_bcd_1_seg

GHDL_ARGS += --std=08
SIM_ARGS += --vcd=waveforms/contador_bcd_1_seg.vcd
SIM_ARGS += -gSYS_CLK=5

.PHONY: run prepare

run: prepare
	$(MAKE) sim

prepare:
	mkdir -p waveforms

include $(shell cocotb-config --makefiles)/Makefile.sim
