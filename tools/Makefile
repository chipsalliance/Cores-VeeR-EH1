# SPDX-License-Identifier: Apache-2.0
# Copyright 2019 Western Digital Corporation or its affiliates.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Check for RV_ROOT
ifeq (,$(wildcard ${RV_ROOT}/configs/swerv.config))
$(error env var RV_ROOT does not point to a valid dir! Exiting!)
endif

# Allow snapshot override
ifeq ($(strip $(snapshot)),)
	snapshot = default
endif

# Allow tool override
SWERV_CONFIG = ${RV_ROOT}/configs/swerv.config
IRUN = irun
VCS = vcs
VERILATOR = verilator
GCC_PREFIX = riscv64-unknown-elf

# Define test name
ifeq ($(strip $(ASM_TEST)),)
	ASM_TEST = hello_world2
endif

# Define test name
ifeq ($(strip $(ASM_TEST_DIR)),)
	ASM_TEST_DIR = ${RV_ROOT}/testbench/asm
endif

defines = ${RV_ROOT}/configs/snapshots/$(snapshot)/common_defines.vh ${RV_ROOT}/design/include/def.sv
includes = -I${RV_ROOT}/design/include -I${RV_ROOT}/design/lib -I${RV_ROOT}/design/dmi -I${RV_ROOT}/configs/snapshots/$(snapshot)

# CFLAGS for verilator generated Makefiles. Without -std=c++11 it complains for `auto` variables
CFLAGS += "-std=c++11"
# Optimization for better performance; alternative is nothing for slower runtime (faster compiles)
# -O2 for faster runtime (slower compiles), or -O for balance.
VERILATOR_MAKE_FLAGS = OPT_FAST=""

# Targets
all: clean verilator

clean:
	rm -rf obj_dir *.hex build

verilator: ${RV_ROOT}/configs/snapshots/$(snapshot)/common_defines.vh
	$(VERILATOR) '-UASSERT_ON' --cc -CFLAGS ${CFLAGS} $(defines) $(includes) ${RV_ROOT}/configs/snapshots/$(snapshot)/common_defines.vh \
		-f ${RV_ROOT}/design/flist.verilator --top-module swerv_wrapper
	$(MAKE) -C obj_dir/ -f Vswerv_wrapper.mk $(VERILATOR_MAKE_FLAGS)

vcs: ${RV_ROOT}/configs/snapshots/$(snapshot)/common_defines.vh
	$(VCS) -full64 -assert svaext -sverilog +define+RV_OPENSOURCE +error+500 +incdir+${RV_ROOT}/design/lib +incdir+${RV_ROOT}/design/include \
		${RV_ROOT}/configs/snapshots/$(snapshot)/common_defines.vh \
		+incdir+${RV_ROOT}/design/dmi +incdir+${RV_ROOT}/configs/snapshots/$(snapshot)  +libext+.v ${RV_ROOT}/configs/snapshots/$(snapshot)/common_defines.vh \
		${RV_ROOT}/design/include/def.sv -f ${RV_ROOT}/design/flist.vcs -l vcs.log

irun: ${RV_ROOT}/configs/snapshots/$(snapshot)/common_defines.vh
	$(IRUN) -64bit -elaborate -ida -access +rw -q -sv -sysv  -nowarn CUVIHR -nclibdirpath ${PWD} -nclibdirname swerv.build \
		-incdir ${RV_ROOT}/design/lib -incdir ${RV_ROOT}/design/include -incdir ${RV_ROOT}/design/dmi -vlog_ext +.vh\
		${RV_ROOT}/configs/snapshots/$(snapshot)/common_defines.vh ${RV_ROOT}/design/include/def.sv \
		-incdir ${RV_ROOT}/configs/snapshots/$(snapshot) -f ${RV_ROOT}/design/flist.vcs -elaborate  -snapshot default

${RV_ROOT}/configs/snapshots/$(snapshot)/common_defines.vh:
	$(SWERV_CONFIG) -snapshot=$(snapshot)

verilator-run: program.hex
	snapshot=ahb
	$(SWERV_CONFIG) -snapshot=$(snapshot) -ahb
	$(VERILATOR) '-UASSERT_ON' --cc -CFLAGS ${CFLAGS} $(defines) $(includes) ${RV_ROOT}/configs/snapshots/$(snapshot)/common_defines.vh \
		${RV_ROOT}/testbench/tb_top.sv -I${RV_ROOT}/testbench \
		-f ${RV_ROOT}/design/flist.verilator --top-module tb_top -exe test_tb_top.cpp --trace --autoflush
	cp ${RV_ROOT}/testbench/test_tb_top.cpp obj_dir/
	$(MAKE) -C obj_dir/ -f Vtb_top.mk $(VERILATOR_MAKE_FLAGS)
	./obj_dir/Vtb_top

irun-run: program.hex
	snapshot=ahb
	$(SWERV_CONFIG) -snapshot=$(snapshot) -ahb
	$(IRUN) -64bit -ida -access +rw -q -sv -sysv  -nowarn CUVIHR -nclibdirpath ${PWD} -nclibdirname swerv.build \
		-incdir ${RV_ROOT}/design/lib -incdir ${RV_ROOT}/design/include -incdir ${RV_ROOT}/design/dmi -vlog_ext +.vh\
		${RV_ROOT}/configs/snapshots/$(snapshot)/common_defines.vh ${RV_ROOT}/design/include/def.sv \
		-top tb_top  ${RV_ROOT}/testbench/tb_top.sv -I${RV_ROOT}/testbench ${RV_ROOT}/testbench/ahb_sif.sv\
		-incdir ${RV_ROOT}/configs/snapshots/$(snapshot) -f ${RV_ROOT}/design/flist.vcs -snapshot default

vcs-run: program.hex
	snapshot=ahb
	$(SWERV_CONFIG) -snapshot=$(snapshot) -ahb
	cp ${RV_ROOT}/testbench/hex/*.hex .
	$(VCS) -full64 -assert svaext -sverilog +define+RV_OPENSOURCE +error+500 +incdir+${RV_ROOT}/design/lib +incdir+${RV_ROOT}/design/include \
		${RV_ROOT}/configs/snapshots/$(snapshot)/common_defines.vh \
		+incdir+${RV_ROOT}/design/dmi +incdir+${RV_ROOT}/configs/snapshots/$(snapshot)  +libext+.v ${RV_ROOT}/configs/snapshots/$(snapshot)/common_defines.vh \
		${RV_ROOT}/design/include/def.sv -f ${RV_ROOT}/design/flist.vcs ${RV_ROOT}/testbench/tb_top.sv -I${RV_ROOT}/testbench ${RV_ROOT}/testbench/ahb_sif.sv -l vcs.log
	./simv

program.hex: $(ASM_TEST_DIR)/$(ASM_TEST).s ${RV_ROOT}/configs/snapshots/$(snapshot)/common_defines.vh
	@echo Building $(ASM_TEST)
ifeq ($(shell which $(GCC_PREFIX)-as),)
	@echo " !!! No $(GCC_PREFIX)-as in path, using canned hex files !!"
	cp ${RV_ROOT}/testbench/hex/*.hex .
else
	cp $(ASM_TEST_DIR)/$(ASM_TEST).s .
	$(GCC_PREFIX)-cpp   -I${RV_ROOT}/configs/snapshots/$(snapshot)  $(ASM_TEST).s  > $(ASM_TEST).cpp.s
	$(GCC_PREFIX)-as -march=rv32imc $(ASM_TEST).cpp.s -o $(ASM_TEST).o
	$(GCC_PREFIX)-ld -m elf32lriscv --discard-none -T${RV_ROOT}/testbench/link.ld -o $(ASM_TEST).exe $(ASM_TEST).o
	$(GCC_PREFIX)-objcopy -O verilog --only-section ".data*" --only-section ".rodata*" $(ASM_TEST).exe data.hex
	$(GCC_PREFIX)-objcopy -O verilog --only-section ".text*" --set-start=0x0 $(ASM_TEST).exe program.hex
	$(GCC_PREFIX)-objdump -dS $(ASM_TEST).exe > $(ASM_TEST).dis
	$(GCC_PREFIX)-nm -f posix -C $(ASM_TEST).exe > $(ASM_TEST).tbl
	@echo Completed building $(ASM_TEST)
endif
	
help:
	@echo Make sure the environment variable RV_ROOT is set.
	@echo Possible targets: verilator vcs irun help clean all verilator-run irun-run vcs-run program.hex

.PHONY: help clean verilator vcs irun verilator-run irun-run  vcs-run
