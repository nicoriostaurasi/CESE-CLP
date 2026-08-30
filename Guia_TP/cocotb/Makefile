SIM ?= ghdl
TOPLEVEL_LANG ?= vhdl

HDL_DIR := $(abspath ../CLP_CESE/CLP_CESE.srcs/sources_1/new)

VHDL_SOURCES := \
	$(HDL_DIR)/adder_1_bit.vhd \
	$(HDL_DIR)/adder_4_bits.vhd \
	$(HDL_DIR)/mux_2_a_1.vhd \
	$(HDL_DIR)/ffd.vhd \
	$(HDL_DIR)/celda_unitaria_contador_binario.vhd \
	$(HDL_DIR)/comparador_igual.vhd \
	$(HDL_DIR)/registro_N_bits.vhd \
	$(HDL_DIR)/sum_res_4_bits.vhd \
	$(HDL_DIR)/barrel_shifter.vhd \
	$(HDL_DIR)/barrel_shifter_mux.vhd \
	$(HDL_DIR)/reg_desp_estructural.vhd \
	$(HDL_DIR)/reg_desp_comportamiento.vhd \
	$(HDL_DIR)/contador_binario_4_bits.vhd \
	$(HDL_DIR)/contador_binario_4_bits_comportamiento.vhd \
	$(HDL_DIR)/contador_binario_N_bits_estructural.vhd \
	$(HDL_DIR)/contador_binario_N_bits_comportamiento.vhd \
	$(HDL_DIR)/contador_bcd.vhd \
	$(HDL_DIR)/contador_bcd_comportamiento.vhd \
	$(HDL_DIR)/contador_bcd_4_digitos.vhd \
	$(HDL_DIR)/contador_N_clk.vhd \
	$(HDL_DIR)/contador_bcd_1_seg.vhd

TOPLEVEL ?= contador_bcd_1_seg
MODULE ?= test_contador_bcd_1_seg
GENERIC_ARGS ?= -gSYS_CLK=5
SIM_BUILD ?= sim_build/$(TOPLEVEL)

GHDL_ARGS += --std=08
SIM_ARGS += --vcd=waveforms/$(TOPLEVEL).vcd
SIM_ARGS += $(GENERIC_ARGS)

.PHONY: run prepare

run: prepare
	$(MAKE) sim

prepare:
	mkdir -p waveforms

include $(shell cocotb-config --makefiles)/Makefile.sim
