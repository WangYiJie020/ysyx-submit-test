#include <common.h>
#include <stdio.h>

//code of iringbuf
#define RINGBUF_SIZE 10

#ifdef CONFIG_ITRACE

typedef struct ringbuf_node{
	vaddr_t pc, snpc;
	uint32_t inst;
} ringbuf_node;
static ringbuf_node ringbuf[RINGBUF_SIZE];
static int start = 0, end = 0;

void record_ringbuf(vaddr_t pc, vaddr_t snpc, uint32_t inst) {
	end = (end + 1) % RINGBUF_SIZE;
	if (start == end) 
		start = (start + 1) % RINGBUF_SIZE;
	ringbuf[end].pc = pc;
	ringbuf[end].snpc = snpc;
	ringbuf[end].inst = inst;
}

void display_ringbuf(){
	while (start != end) {
		start = (start + 1) % RINGBUF_SIZE;
		if (start == end) 
			printf("--> ");
		else printf("    ");
		vaddr_t pc = ringbuf[start].pc;
		vaddr_t snpc = ringbuf[start].snpc;
		uint8_t *inst = (uint8_t *)&ringbuf[start].inst;
		char buf[128] = {'\0'};
		char *p = buf;
		p += snprintf(p, sizeof(buf), FMT_WORD ":", pc);
		int ilen = snpc - pc;
		for (int i = ilen - 1; i >= 0; i--)
			p += snprintf(p, 4, " %02x", inst[i]);
		int ilen_max = MUXDEF(CONFIG_ISA_x86, 8, 4);
		int space_len = ilen_max - ilen;
		if (space_len < 0) space_len = 0;
		space_len = space_len * 3 + 1;
		memset(p, ' ', space_len);
		p += space_len;
	
		void disassemble(char *str, int size, uint64_t pc, uint8_t *code, int nbyte);
		disassemble(p, buf + sizeof(buf) - p,
			MUXDEF(CONFIG_ISA_x86, snpc, pc), inst, ilen);
		printf("%s\n", buf);
	}
}

#endif
//code of mtrace

#define MTRACE_ADDR_START 0x80000000
#define MTRACE_ADDR_END 0x87ffffff

void mtrace_read(paddr_t addr, int len) {
	if (addr < MTRACE_ADDR_START || addr > MTRACE_ADDR_END)
		return;
	printf("read  addr: %#x, len: %d\n", addr, len);
}

void mtrace_write(paddr_t addr, int len, word_t data) {
	if (addr < MTRACE_ADDR_START || addr > MTRACE_ADDR_END)
		return;
	printf("write addr: %#x, len: %d, data %0#10x\n", addr, len, data);
}

//code of ftrace
#include <stdlib.h>  
#include <gelf.h>  
#include <fcntl.h>  
#include <unistd.h>  
#include <libelf.h>  

#define SYMFUNC_SIZE 256
#define SYMFUNC_NAMESIZE 32

static GElf_Sym symtab[SYMFUNC_SIZE];
static int tail = 0;
static char names[SYMFUNC_SIZE][SYMFUNC_NAMESIZE];

void init_ftrace(char *elf_file) {
	elf_version(EV_CURRENT);
	int fd = open(elf_file, O_RDONLY);
	assert(fd >= 0);
	
	Elf* elf = elf_begin(fd, ELF_C_READ, NULL);
	assert(elf != NULL);
	
	assert(elf_kind(elf) == ELF_K_ELF);

	Elf_Scn *scn = NULL;
	size_t scndx = SHN_UNDEF;
	while ((scn = elf_nextscn(elf, scn)) != NULL) {
		GElf_Shdr shdr;
		gelf_getshdr(scn, &shdr);

		if (shdr.sh_type == SHT_SYMTAB) {
			Elf_Data *data = elf_getdata(scn, NULL);
			assert(data);
			GElf_Sym sym;
			for (size_t i = 0; gelf_getsym(data, i, &sym) != NULL; ++i) {
				if (GELF_ST_TYPE(sym.st_info) == STT_FUNC) {
					assert(tail < SYMFUNC_SIZE);
					symtab[tail] = sym;
					++tail;
				}
			}
		}
		else if (shdr.sh_type == SHT_STRTAB) {
			scndx = elf_ndxscn(scn);
			break;
		}
	}

	for (int i = 0; i < tail; ++i) {
		char *name = elf_strptr(elf, scndx, symtab[i].st_name);
		strncpy(names[i], name, SYMFUNC_NAMESIZE);
	}

	elf_end(elf);
	close(fd);
}

static int nest = 0;

void ftrace_call(vaddr_t addr, vaddr_t pc) {
	for (int i = 0; i < tail; ++i) {
		if (addr >= symtab[i].st_value && addr < symtab[i].st_value + symtab[i].st_size) {
			printf("%#x: ", pc);
			for (int j = 0; j < nest; ++j)
				printf(" ");
			++nest;
			printf("call [%s@%#lx]\n", names[i], symtab[i].st_value);
			break;
		}
	}
}

void ftrace_ret(vaddr_t addr, vaddr_t pc) {
	for (int i = 0; i < tail; ++i) {
		if (addr >= symtab[i].st_value && addr < symtab[i].st_value + symtab[i].st_size) {
			--nest;
			printf("%#x: ", pc);
			for (int j = 0; j < nest; ++j)
				printf(" ");
			printf("ret [%s]\n", names[i]);
			break;
		}
	}
}

//code of dtrace

void dtrace_read(const char *name, paddr_t addr, int len, paddr_t offset) {
	printf("read : %s, addr: %#x, len: %d, offset: %#x\n", name, addr, len, offset);
}

void dtrace_write(const char *name, paddr_t addr, int len, paddr_t offset, word_t data) {
	printf("write: %s, addr: %#x, len: %d, offset: %#x, data: %#x\n", name, addr, len, offset, data);
}

//code of etrace
void etrace(word_t NO) {
	switch (NO) {
		case 11: printf("trigger yield\n"); break;
		default: printf("unknown error trace\n");
	}
}

#ifdef CONFIG_CTRACE
FILE *icache_fp;
void init_icachetrace(const char *icache_file) {
	icache_fp = stdout;
	if (icache_file != NULL) {
		FILE *fp = fopen(icache_file, "w");
		Assert(fp, "Can not open '%s'", icache_file);
		icache_fp = fp;
	}
}

void icache_trace(uint32_t pc) {
	fwrite(&pc, 4, 1, icache_fp);
}

#endif
