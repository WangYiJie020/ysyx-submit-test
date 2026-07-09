AM_SRCS := riscv/ysyxsoc/start.S \
           riscv/ysyxsoc/trm.c \
           riscv/ysyxsoc/ioe/ioe.c \
           riscv/ysyxsoc/ioe/timer.c \
           riscv/ysyxsoc/ioe/input.c \
           riscv/ysyxsoc/ioe/uart.c \
           riscv/ysyxsoc/ioe/gpu.c \
           riscv/npc/cte.c \
           riscv/npc/trap.S \
           platform/dummy/vme.c \
           platform/dummy/mpe.c

CFLAGS    += -fdata-sections -ffunction-sections
LDFLAGS   += -T $(AM_HOME)/scripts/soc_linker.ld
LDFLAGS   += --gc-sections -e _start 
CFLAGS += -DMAINARGS=\"$(mainargs)\"
CFLAGS += -I$(AM_HOME)/am/src/riscv/ysyxsoc/include
CACHETRACE = $(WORK_DIR)/build/icache_trace.bin
CACHESIMFLAGS = -b -c $(CACHETRACE)
CACHESIM_HOME = /home/ysyx/cachesim
.PHONY: $(AM_HOME)/am/src/riscv/ysyxsoc/trm.c

# 批处理
NPC_FLAGS += -b

image: $(IMAGE).elf
	@$(OBJDUMP) -d $(IMAGE).elf > $(IMAGE).txt
	@echo + OBJCOPY "->" $(IMAGE_REL).bin
	@$(OBJCOPY) -S --set-section-flags .bss=alloc,contents -O binary $(IMAGE).elf $(IMAGE).bin

run: image
	$(MAKE) -C $(NPC_HOME) sim IMG=$(IMAGE).bin ARGS="$(NPC_FLAGS)" ISA=$(ISA) PLATFORM=$(PLATFORM)

cachetrace: image
	$(MAKE) -C $(NEMU_HOME) ISA=$(ISA) run ARGS="$(CACHESIMFLAGS)" IMG=$(IMAGE).bin

cachesim: 
	$(MAKE) -C $(CACHESIM_HOME) ARGS="$(CACHETRACE)" run
