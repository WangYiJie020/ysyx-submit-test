#include <stdio.h>
#include <stdint.h>
#include "verilated.h"

#if defined(__PLATFORM_ysyxsoc_)
#include <VysyxSoCFull___024root.h>
#include <VysyxSoCFull.h>
#define signal(s) ysyxSoCFull__DOT__asic__DOT__cpu__DOT__cpu__DOT__##s
#elif defined(__PLATFORM_npc_)
#include <Vnpc___024root.h>
#include <Vnpc.h>
#define signal(s) npc__DOT__cpu__DOT__##s
#endif

#if defined(__ISA_riscv32_)
#define TOTAL_REGS 32
#elif defined(__ISA_riscv32e_)
#define TOTAL_REGS 16
#endif

extern TOP_NAME* top;

const char *regs[] = {
	"$0", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
	"s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
  "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
  "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
};

void reg_display() {
	uint32_t pc = top->rootp->signal(ifu_pc);
	printf("pc\t%#x\t%d\n", pc, pc);
	for (int i = 1; i < TOTAL_REGS; ++i) {
		uint32_t reg_val = top->rootp->signal(my_reg__DOT__rf[i-1]);
		printf("%s\t%#x\t%d\n", regs[i], reg_val, reg_val);
	}
}
