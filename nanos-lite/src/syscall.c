#include <common.h>
#include "syscall.h"
#include <stdio.h>
#include <sys/time.h>
#include <proc.h>

int fs_open(const char *pathname, int flags, int mode);
size_t fs_read(int fd, void *buf, size_t len);
size_t fs_write(int fd, const void *buf, size_t len);
size_t fs_lseek(int fd, size_t offset, int whence);
int fs_close(int fd);

int mm_brk(uintptr_t brk);

void naive_uload(PCB *pcb, const char *filename);
void context_uload(PCB *pcb, const char *filename, char *const argv[], char *const envp[]);

static int sys_gettimeofday(struct timeval *tv, struct timezone *tz) {
	uint64_t us = io_read(AM_TIMER_UPTIME).us;
	tv->tv_sec = us / 1000000;
	tv->tv_usec = us % 1000000;
	return 0;
}

void do_syscall(Context *c) {
  uintptr_t a[4];
  a[0] = c->GPR1;
	a[1] = c->GPR2;
	a[2] = c->GPR3;
	a[3] = c->GPR4;

	//strace
	//printf("cause: %d, args: %d %d %d\n", a[0], a[1], a[2], a[3]);

  switch (a[0]) {
		case SYS_exit: halt(0); context_uload(current, "/bin/nterm", (char **){NULL}, (char **){NULL});
									switch_boot_pcb(); yield(); break;
		case SYS_yield: yield(); c->GPRx = 0; break;
		case SYS_open: c->GPRx = fs_open((char *)a[1], a[2], a[3]); break;
		case SYS_read: c->GPRx = fs_read(a[1], (char *)a[2], a[3]); break;
		case SYS_write: c->GPRx = fs_write(a[1], (char *)a[2], a[3]); break;
		case SYS_close: c->GPRx = fs_close(a[1]); break;
		case SYS_lseek: c->GPRx = fs_lseek(a[1], a[2], a[3]); break;
		case SYS_brk: c->GPRx = mm_brk(a[1]); break;
		case SYS_execve: if (fs_open((char *)a[1], 0, 0) < 0) c->GPRx = -2;
										else { context_uload(current, (char *)a[1], (char **)a[2], (char **)a[3]);
										switch_boot_pcb(); yield(); } break;
		case SYS_gettimeofday: c->GPRx = sys_gettimeofday((struct timeval *)a[1], (struct timezone *)a[2]); break;
    default: panic("Unhandled syscall ID = %d", a[0]);
  }
}
