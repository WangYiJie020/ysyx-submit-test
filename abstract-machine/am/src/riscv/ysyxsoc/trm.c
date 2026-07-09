#include <am.h>
#include <klib-macros.h>
#include <klib.h>
#include <ysyxsoc.h>

extern char _heap_start [];

uint32_t _read_csr_marchid();
uint32_t _read_csr_mvendorid();

int main(const char *args);

Area heap = RANGE(_heap_start, 0xa2000000);
#ifndef MAINARGS
#define MAINARGS ""
#endif
static const char mainargs[] = MAINARGS;

void putch(char ch) {
	while (!(inb(SERIAL_PORT + 5) & 0x20));
	outb(SERIAL_PORT, ch);
}

void halt(int code) {
	asm volatile ("mv a0,%0; ebreak" : :"r"(code));

	while(1);
}

extern char _data_start [];
extern char data_load_start [];
extern char _bss_start [];
extern char end[];

void _trm_init() {
	//set uart divisor
	uint8_t lcr = inb(SERIAL_PORT + 3);
	outb(SERIAL_PORT + 3, 0x80 | lcr);
	outb(SERIAL_PORT, 0x01);
	outb(SERIAL_PORT + 3, 0x7f & lcr);
	//memcpy(_data_start, data_load_start, (size_t) (_bss_start - _data_start));
	//memset(_bss_start, 0, (size_t)(end - _bss_start));

	uint32_t ysyx = _read_csr_mvendorid(), ID = _read_csr_marchid();
	char ysyx_s[4];
	for (int i = 3; i >= 0; --i) {
		ysyx_s[i] = (char)(ysyx & 0xff);
		ysyx >>= 8;
	}
	printf("npc made by %s_%d\n", ysyx_s, ID);

	int ret = main(mainargs);
	halt(ret);
}
