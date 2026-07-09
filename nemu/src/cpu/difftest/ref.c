/***************************************************************************************
* Copyright (c) 2014-2022 Zihao Yu, Nanjing University
*
* NEMU is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
*
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
*
* See the Mulan PSL v2 for more details.
***************************************************************************************/

#include <isa.h>
#include <cpu/cpu.h>
#include <difftest-def.h>
#include <memory/paddr.h>

__EXPORT void difftest_memcpy(paddr_t addr, void *buf, size_t n, bool direction) {
	uint8_t *_buf = (uint8_t *)buf;
	if (direction == DIFFTEST_TO_REF) {
		memcpy(guest_to_host(addr), buf, n);
	}
	else for (int i = 0; i < n; ++i) {
		_buf[i] = paddr_read(addr, 1);
	}
}

__EXPORT void difftest_regcpy(void *dut, uint32_t *pc, bool direction) {
	CPU_state *cpu_dut = (CPU_state *)dut;
	if (direction == DIFFTEST_TO_REF) {
		for (int i = 1; i < 32; ++i) {
			cpu.gpr[i] = cpu_dut->gpr[i-1];
		}
		cpu.pc = *pc;
	}
	else {
		for (int i = 1; i < 32; ++i) {
			cpu_dut->gpr[i-1] = cpu.gpr[i];
		}
		*pc = cpu.pc;
	}
}

__EXPORT void difftest_exec(uint64_t n) {
	cpu_exec(n);
}

__EXPORT void difftest_raise_intr(word_t NO) {
  assert(0);
}

__EXPORT void difftest_init(int port) {
  void init_mem();
  init_mem();
  /* Perform ISA dependent initialization. */
  init_isa();
}
