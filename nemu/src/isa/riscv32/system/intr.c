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

word_t isa_raise_intr(word_t NO, vaddr_t epc) {
  /* TODO: Trigger an interrupt/exception with ``NO''.
   * Then return the address of the interrupt/exception vector.
   */

	void etrace(word_t NO);
	IFDEF(CONFIG_ETRACE, etrace(NO));

	cpu.csr.mstatus &= ~(1 << 7);
	cpu.csr.mstatus |= ((1 << 7) & (cpu.csr.mstatus << 4));
	cpu.csr.mstatus &= ~(1 << 3);
	cpu.csr.mepc = epc;
	cpu.csr.mcause = NO;

  return cpu.csr.mtvec;
}

#define IRQ_TIMER 0x80000007

word_t isa_query_intr() {
	if (cpu.INTR == true && ((cpu.csr.mstatus >> 3) & 1) == 1) {
		cpu.INTR = false;
		return IRQ_TIMER;
	}
  return INTR_EMPTY;
}
