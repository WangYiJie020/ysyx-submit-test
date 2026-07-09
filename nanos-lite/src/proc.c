#include <proc.h>

#define MAX_NR_PROC 4

static PCB pcb[MAX_NR_PROC] __attribute__((used)) = {};
static PCB pcb_boot = {};
PCB *current = NULL;

void context_uload(PCB *_pcb, const char *filename, char *const argv[], char *const envp[]);
void naive_uload(PCB *pcb, const char *filename);

void switch_boot_pcb() {
  current = &pcb_boot;
}

void hello_fun(void *arg) {
  int j = 1;
  while (1) {
		Log("Hello World from Nanos-lite with arg '%p' for the %dth time!", (uintptr_t)arg, j);
    j ++;
    yield();
  }
}

void context_kload(PCB *_pcb, void (*entry)(void *), void *arg) {
	_pcb->cp = kcontext((Area) {_pcb->stack, _pcb->stack + STACK_SIZE}, hello_fun, arg);
}

void init_proc() {
	context_kload(&pcb[0], hello_fun, (void *)1L);
	char *argv[] = {"/bin/pal", "--skip", NULL}, *envp[] = {NULL};
	context_uload(&pcb[1], "/bin/pal", argv, envp);
  switch_boot_pcb();

  Log("Initializing processes...");

	//naive_uload(NULL, "/bin/menu");
  // load program here

}

Context* schedule(Context *prev) {
	current->cp = prev;
	static int cnt = 0;
	if (current == &pcb[1]) {
		if (cnt == 100) {
			current = &pcb[0];
			cnt = 0;
		}
		++cnt;
	}
	else current = &pcb[1];
  return current->cp;
}
