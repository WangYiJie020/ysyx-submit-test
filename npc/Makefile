STUID = ysyx_23060236

PLATFORM = npc
ISA = riscv32e
ifeq ($(PLATFORM),ysyxsoc)
TOPNAME = ysyxSoCFull
NXDC_FILES = constr/ysyxsoc.nxdc
else ifeq ($(PLATFORM),npc)
TOPNAME = npc
NXDC_FILES = constr/npc.nxdc
endif

INC_PATH ?= 

VERILATOR = verilator
VERILATOR_CFLAGS += -MMD --build -cc -O3 --x-assign \
										fast --x-initial fast --noassert --autoflush \
										--timescale "1ns/1ns" --no-timing --trace-fst

WORK_DIR = $(abspath .)
BUILD_DIR = $(WORK_DIR)/build
OBJ_DIR = $(BUILD_DIR)/obj_dir
IMG ?= 
BIN = $(BUILD_DIR)/$(TOPNAME)
ONE_VSRC = $(BUILD_DIR)/$(STUID).v
ONE_VSRC_SIM = $(BUILD_DIR)/$(STUID)_sim.v
IBIN = $(BUILD_DIR)/iverilog_sim
IBIN_NETLIST = $(BUILD_DIR)/iverilog_sim_netlist

CXX_INC_PATH = $(abspath ./include) $(INC_PATH)
VER_INC_PATH += $(abspath ./vinclude)
ifeq ($(PLATFORM),ysyxsoc)
VER_INC_PATH += $(abspath ./vinclude/ysyxsoc)
VER_INC_PATH += $(abspath ../ysyxSoC/perip/uart16550/rtl) $(abspath ../ysyxSoC/perip/spi/rtl)
else ifeq ($(PLATFORM),npc)
VER_INC_PATH += $(abspath ./vinclude/npc)
endif

default:
	make $(BIN)

$(shell mkdir -p $(BUILD_DIR))

SRC_AUTO_BIND = $(abspath $(BUILD_DIR)/auto_bind.cpp)
$(SRC_AUTO_BIND): $(NXDC_FILES)
	python3 $(NVBOARD_HOME)/scripts/auto_pin_bind.py $^ $@

VSRCS = $(shell find $(abspath ./vsrc) -name "*.v")
CSRCS = $(shell find $(abspath ./csrc) -name "*.c" -or -name "*.cc" -or -name "*.cpp")
CSRCS += $(SRC_AUTO_BIND)
ifeq ($(PLATFORM),ysyxsoc)
VSRCS += $(shell find $(abspath ../ysyxSoC/perip) -name "*.v")
VSRCS += $(abspath ../ysyxSoC/build/ysyxSoCFull.v)
else ifeq ($(PLATFORM),npc)
VSRCS += $(abspath ./simtop/npc.v)
endif

include $(NVBOARD_HOME)/scripts/nvboard.mk

CXX_INCFLAGS = $(addprefix -I, $(CXX_INC_PATH))
VER_INCFLAGS = $(addprefix -I, $(VER_INC_PATH))
CXXFLAGS += $(CXX_INCFLAGS) \
						-DTOP_NAME=\"V$(TOPNAME)\"\
						-D__PLATFORM_$(PLATFORM)_ \
						-D__ISA_$(ISA)_
VERILATOR_CFLAGS += $(VER_INCFLAGS)
DIFF_SO = $(NEMU_HOME)/build/riscv32-nemu-interpreter-so
LDFLAGS += -lreadline
ifneq ($(IMG),)
override ARGS += -g $(IMG)
endif
ifneq ($(DIFF_SO),)
override ARGS += -d $(DIFF_SO)
endif

$(BIN): $(VSRCS) $(CSRCS) $(NVBOARD_ARCHIVE)
	@rm -rf $(OBJ_DIR)
	$(VERILATOR) $(VERILATOR_CFLAGS) \
		--top-module $(TOPNAME) $^ \
		$(addprefix -CFLAGS , $(CXXFLAGS)) $(addprefix -LDFLAGS , $(LDFLAGS)) \
		--Mdir $(OBJ_DIR) --exe -o $(abspath $(BIN)) 

all: default

sim: 
	make $(BIN)
	$(BIN) $(ARGS)
	$(call git_commit, "sim RTL") # DO NOT REMOVE THIS LINE!!!

.PHONY: clean all default sim

clean:
	rm -rf $(BUILD_DIR)

include ../Makefile

count:
	find ./csrc ./vsrc -name *.[chv] | xargs cat | wc -l

countNoblank:
	find ./csrc ./vsrc -name *.[cvh] | xargs grep -v '^$$' | wc -l

perf:
	make -C ../am-kernels/benchmarks/microbench ARCH=riscv32e-ysyxsoc run mainargs=train

CHECK_VSRCS = $(shell find $(abspath ./vsrc) -name "*.v")
CHECKFLAGS = --lint-only -Wall $(VER_INCFLAGS)

check:
	$(VERILATOR) $(CHECKFLAGS) $(CHECK_VSRCS)

verilog:
	@echo "\`define SYN"  > $(ONE_VSRC)
	@cat ./vinclude/ysyxsoc/ysyx_23060236_defines_platform.v >> $(ONE_VSRC)
	@cat ./vsrc/*.v | grep -v "include " | grep -v "define" >> $(ONE_VSRC)

verilog_sim:
	@cat ./vinclude/ysyxsoc/ysyx_23060236_defines_platform.v > $(ONE_VSRC_SIM)
	@cat ./vsrc/*.v | grep -v "include " | grep -v "define" >> $(ONE_VSRC_SIM)

sim-iverilog: verilog_sim
	@python3 ./utils/bin_to_hex.py $(IMG) $(BUILD_DIR)/memory.hex
	@iverilog -g2012 $(ONE_VSRC_SIM) ./simtop/npc.v -o $(IBIN) -s iverilog_tb -DMEM_FILE=\"$(BUILD_DIR)/memory.hex\"
	@vvp -n $(IBIN) -fst

sim-iverilog-netlist:
	@python3 ./utils/bin_to_hex.py $(IMG) $(BUILD_DIR)/memory.hex
	@iverilog -g2012 $(CELLS) $(NETLIST) ./simtop/npc.v -o $(IBIN_NETLIST) -s iverilog_tb -DMEM_FILE=\"$(BUILD_DIR)/memory.hex\" -DNETLIST
	@vvp -n $(IBIN_NETLIST) -fst

