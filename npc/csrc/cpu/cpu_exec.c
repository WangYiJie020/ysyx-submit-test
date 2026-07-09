#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include "verilated.h"
#include <memory.h>
#include <config.h>
#include <nvboard.h>
#include "verilated_fst_c.h"

#if defined(__PLATFORM_ysyxsoc_)
#include <VysyxSoCFull___024root.h>
#include <VysyxSoCFull.h>
#define signal(s) top->rootp->ysyxSoCFull__DOT__asic__DOT__cpu__DOT__cpu__DOT__##s
#elif defined(__PLATFORM_npc_)
#include <Vnpc___024root.h>
#include <Vnpc.h>
#define signal(s) top->rootp->npc__DOT__cpu__DOT__##s
#endif

TOP_NAME *top = NULL;
VerilatedFstC *tfp = NULL;
VerilatedContext *contextp = NULL;
int trigger_difftest = 0;
extern int wave_trace;
int return_value = 1;

//performance register
static long total_inst = 0;
static long total_cycle = 0;
static long total_lsu_getdata = 0;
static long total_lsu_writedata = 0;
static long total_ifu_getinst = 0;
static long total_lsu_readingcycle = 0;
static long total_lsu_writingcycle = 0;
static long total_ifu_readingcycle = 0;
static long hit_icache = 0;
static long miss_icache = 0;
static long tmt = 0;
static long raw_conflict = 0;
static long raw_conflict_cycle = 0;
static long jump_wrong = 0;
static long jump_wrong_cycle = 0;
static int lsu_awaddr = 0;
static int inst_ebreak = 0;

enum { DIFFTEST_TO_DUT, DIFFTEST_TO_REF };
void difftest_step();
void difftest_skip_ref();
extern void (*ref_difftest_regcpy)(void *dut, uint32_t *pc, bool direction);
void reg_display();
void nvboard_update();
void print_difftest_reg();

void print_statistic() {
	printf("\ntotal_cycle: %ld\ntotal_inst: %ld\n", total_cycle, total_inst);
	printf("IPC: %f\n", (double)total_inst / total_cycle);
	//performance conter
	printf("\nperformance counter:\n");
	printf("total_ifu_getinst: %ld\n", total_ifu_getinst);
	printf("total_ifu_readingcycle: %ld\n", total_ifu_readingcycle);
	printf("average ifu reading delay: %f\n", (double)total_ifu_readingcycle / total_ifu_getinst);
	printf("total_lsu_getdata: %ld\n", total_lsu_getdata);
	printf("total_lsu_readingcycle: %ld\n", total_lsu_readingcycle);
	printf("average lsu reading delay: %f\n", (double)total_lsu_readingcycle / total_lsu_getdata);
	printf("total_lsu_writedata: %ld\n", total_lsu_writedata);
	printf("total_lsu_writingcycle: %ld\n", total_lsu_writingcycle);
	printf("average lsu writing delay: %f\n", (double)total_lsu_writingcycle / total_lsu_writedata);
	//cache performance
	printf("\ncache performance:\n");
	printf("hit_icache: %ld\nmiss_icache: %ld\n", hit_icache, miss_icache);
	printf("hit rate: %f\n", (double)hit_icache / (hit_icache + miss_icache));
	printf("TMT: %ld\n", tmt);
	printf("average miss time: %f\n", (double)tmt / miss_icache);
	//pipeline performance
	printf("\npipeline performance:\n");
	printf("raw_conflict_cycle: %ld\n", raw_conflict_cycle);
	printf("raw_conflict: %ld\n", raw_conflict);
	printf("average raw conflict penalty: %f\n", (double)raw_conflict_cycle / raw_conflict);
	printf("jump_wrong_cycle: %ld\n", jump_wrong_cycle);
	printf("jump_wrong: %ld\n", jump_wrong);
	printf("average jump wrong penalty: %f\n", (double)jump_wrong_cycle / jump_wrong);
	printf("\n");
}

extern "C" void add_total_inst() { ++total_inst; }
extern "C" void add_total_cycle() { ++total_cycle; }
extern "C" void add_lsu_getdata() { ++total_lsu_getdata; }
extern "C" void add_lsu_writedata() { ++total_lsu_writedata; }
extern "C" void add_ifu_getinst() { ++total_ifu_getinst; }
extern "C" void add_lsu_readingcycle() { ++total_lsu_readingcycle; }
extern "C" void add_lsu_writingcycle() { ++total_lsu_writingcycle; }
extern "C" void add_ifu_readingcycle() { ++total_ifu_readingcycle; }
extern "C" void add_hit_icache() { ++hit_icache; }
extern "C" void add_miss_icache() { ++miss_icache; }
extern "C" void add_tmt() { ++tmt; }
extern "C" void add_raw_conflict_cycle() { ++raw_conflict_cycle; }
extern "C" void add_raw_conflict() { ++raw_conflict; }
extern "C" void add_jump_wrong() { ++jump_wrong; }
extern "C" void add_jump_wrong_cycle() { ++jump_wrong_cycle; }
extern "C" void record_lsu_awaddr(int awaddr) { lsu_awaddr = awaddr; }
extern "C" void program_end() { inst_ebreak = 1; }

static void one_cycle() {
	top->clock = 0; top->eval(); 
#ifdef WAVE_TRACE
	if (wave_trace) { tfp->dump(contextp->time()); contextp->timeInc(1); }
#endif
	top->clock = 1; top->eval(); 
#ifdef WAVE_TRACE
	if (wave_trace) { tfp->dump(contextp->time()); contextp->timeInc(1); }
#endif
}

void cpu_exec(unsigned long n) {
	if (inst_ebreak || trigger_difftest) {
		printf("the program is ended.\n");
		return;
	}

	uint32_t pc = signal(ifu_pc);
	uint32_t inst = signal(inst);
	for (; n > 0; --n) {
		pc = signal(ifu_pc);
		inst = signal(inst);
		nvboard_update();
		one_cycle();
#ifdef DIFFTEST
		static int difftest = 0;
		bool in_uart = (lsu_awaddr >= UART_BASE) && (lsu_awaddr < UART_BASE + UART_SIZE);
		bool in_clint = (lsu_awaddr >= CLINT_BASE) && (lsu_awaddr < CLINT_BASE + CLINT_SIZE);
		if (difftest) {
			difftest_step();
		}
		difftest = signal(wb_valid);
#endif
		if (inst_ebreak || trigger_difftest) break;
	}

	if (trigger_difftest) {
		reg_display();
		printf("\33[1;31mdifftest ABORT\33[1;0m at pc = %#x\n", pc);
		return;
	}
	if (!inst_ebreak) return;
	return_value = signal(my_reg__DOT__rf[9]);
	if (return_value)
		printf("\33[1;31mHIT BAD TRAP\33[1;0m ");
	else printf("\33[1;32mHIT GOOD TRAP\33[1;0m ");
	printf("at pc = %#x\n", signal(ifu_pc));
#ifdef PRINT_PERF
	print_statistic();
#endif
}

void reset() {
	top->reset = 1;
	one_cycle();
	one_cycle();
	one_cycle();
	one_cycle();
	one_cycle();
	one_cycle();
	one_cycle();
	one_cycle();
	one_cycle();
	one_cycle();
	one_cycle();
	top->reset = 0;
}
