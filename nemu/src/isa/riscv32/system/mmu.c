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
#include <memory/vaddr.h>
#include <memory/paddr.h>

paddr_t isa_mmu_translate(vaddr_t vaddr, int len, int type) {
  word_t vpn1 = vaddr >> 22;
	word_t vpn0 = (vaddr >> 12) & ((1 << 10) - 1);
	word_t satp = cpu.csr.satp << 12;
	word_t pte = paddr_read(satp + 4 * vpn1, 4);
	if ((pte & 1) == 0) return MEM_RET_FAIL;
	paddr_t pg_addr1 = (pte >> 10) << 12;
	word_t pte_leaf = paddr_read(pg_addr1 + 4 * vpn0, 4);
	if ((pte_leaf & 1) == 0) return MEM_RET_FAIL;
	paddr_t pg_addr = (pte_leaf >> 10) << 12;
	return pg_addr | MEM_RET_OK;
}
