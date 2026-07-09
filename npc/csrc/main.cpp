#include "verilated.h"
#include <nvboard.h>
#include "verilated_fst_c.h"
#include <config.h>

#if defined(__PLATFORM_ysyxsoc_)
#include <VysyxSoCFull.h>
#elif defined(__PLATFORM_npc_)
#include <Vnpc.h>
#endif

extern TOP_NAME *top;
extern VerilatedFstC *tfp;
extern VerilatedContext *contextp;
extern int return_value;

int start = 0;
void nvboard_bind_all_pins(TOP_NAME* top);

void init_monitor(int argc, char **argv);
void sdb_mainloop();
void reset();

int main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	contextp = new VerilatedContext;
	contextp->commandArgs(argc, argv);
	top = new TOP_NAME{contextp};
#ifdef WAVE_TRACE
	tfp = new VerilatedFstC;
	contextp->traceEverOn(true);
	top->trace(tfp, 0);
	tfp->open("wave.fst");
#endif
	nvboard_bind_all_pins(top);
	nvboard_init();

	reset();

	init_monitor(argc, argv);

	start = 1;

	sdb_mainloop();

#ifdef WAVE_TRACE
	tfp->close();
#endif
	delete top;
	delete contextp;
	return return_value;
}
