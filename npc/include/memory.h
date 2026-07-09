#ifndef __MEMORY_H__
#define __MEMORY_H__

#include <stdint.h>

#define MEM_BASE    0x80000000
#define MEM_SIZE    0x08000000
#define MROM_BASE   0x20000000
#define SRAM_BASE   0x0f000000
#define FLASH_BASE  0x30000000
#define FLASH_SIZE  0x10000000
#define UART_BASE   0x10000000
#define UART_SIZE   0x00001000
#define CLINT_BASE  0x02000000
#define CLINT_SIZE  0x00010000

extern "C" void pmem_write(int waddr, int wdata, char wmask);
extern "C" int pmem_read(int raddr);
extern "C" void flash_read(int32_t addr, int32_t *data);
extern "C" void mrom_read(int32_t addr, int32_t *data);
void init_memory();
uint8_t *guest2host(uint32_t paddr);
uint32_t host2guest(uint8_t *haddr);
uint8_t *guest2host_mrom(uint32_t paddr);
uint32_t host2guest_mrom(uint8_t *haddr);
uint8_t *guest2host_flash(uint32_t paddr);
uint32_t host2guest_flash(uint8_t *haddr);

#endif
