#include <memory.h>
#include <proc.h>
#include <sys/mman.h>

static void *pf = NULL;

void* new_page(size_t nr_page) {
	void *ret = pf;
	pf += nr_page * PGSIZE;
  return ret;
}

#ifdef HAS_VME
static void* pg_alloc(int n) {
	void *ret = new_page(n / PGSIZE);
	memset(ret, 0, n);
  return ret;
}
#endif

void free_page(void *p) {
  panic("not implement yet");
}

/* The brk() system call handler. */
int mm_brk(uintptr_t brk) {
	if (current->max_brk == 0) {
		current->max_brk = brk;
		void *va = (void *)ROUNDDOWN(brk, PGSIZE);
		void *pa = maped(&current->as, va);
		if (pa == NULL) {
			pa = new_page(1);
			map(&current->as, va, pa, PROT_WRITE | PROT_READ | PROT_EXEC);
		}
	}
	for (void *va = (void*)ROUNDDOWN(current->max_brk, PGSIZE); (uintptr_t)va < ROUNDDOWN(brk, PGSIZE); va += PGSIZE) {
		void *pa = new_page(1);
		map(&current->as, va + PGSIZE, pa, PROT_WRITE | PROT_READ | PROT_EXEC);
	}
	if (current->max_brk < brk)
		current->max_brk = brk;
  return 0;
}

void init_mm() {
  pf = (void *)ROUNDUP(heap.start, PGSIZE);
  Log("free physical pages starting from %p", pf);

#ifdef HAS_VME
  vme_init(pg_alloc, free_page);
#endif
}
