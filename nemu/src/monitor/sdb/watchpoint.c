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

#include "sdb.h"

#define NR_WP 32

typedef struct watchpoint {
  int NO;
  struct watchpoint *next;
	struct watchpoint *pre;
	char e[65536];
	word_t old;

  /* TODO: Add more members if necessary */

} WP;

static WP wp_pool[NR_WP] = {};
static WP *head = NULL, *free_ = NULL;

void init_wp_pool() {
  int i;
  for (i = 0; i < NR_WP; i ++) {
    wp_pool[i].NO = i;
    wp_pool[i].next = (i == NR_WP - 1 ? NULL : &wp_pool[i + 1]);
		wp_pool[i].pre = (i == 0 ? NULL : &wp_pool[i - 1]);
  }

  head = NULL;
  free_ = wp_pool;
}

/* TODO: Implement the functionality of watchpoint */

void display_wp() {
	if (head == NULL) {
		printf("NO watchpoint\n");
		return;
	}
	printf("Num     what\n");
	WP* h = head;
	while (h) {
		printf("%-8d%-8s\n", h->NO, h->e);
		h = h->next;
	}
}

WP* new_wp() {
	assert(free_);
	WP *tmp = free_;
	free_ = free_->next;
	tmp->next = head;
	if (head) head->pre = tmp;
	if (free_) free_->pre = NULL;
	head = tmp;
	return head;
}

void free_wp(WP* wp) {
	if (wp->next) wp->next->pre = wp->pre;
	if (wp->pre) wp->pre->next = wp->next;
	else head = head->next;
	wp->next = free_;
	wp->pre = NULL;
	if (free_) free_->pre = wp;
	free_ = wp;
}

void watch_wp(char *expr, word_t res) {
	WP* wp = new_wp();
	strcpy(wp->e, expr);
	wp->old = res;
	printf("Watchpoint: %d, %s\n", wp->NO, wp->e);
}

void delete_wp(int NO) {
	assert(NO < NR_WP);
	free_wp(&wp_pool[NO]);
	printf("Delete Watchpoint: %d, %s\n", wp_pool[NO].NO, wp_pool[NO].e);
}

void difftest_wp() {
	if (nemu_state.state != NEMU_RUNNING) return;
	WP* h = head;
	while (h) {
		bool success = true;
		word_t res = expr(h->e, &success);
		assert(success);
		if (res != h->old) {
			nemu_state.state = NEMU_STOP;
			printf("trigger watchpoint %d: %s\n", h->NO, h->e);
			printf("old value: %d, new value: %d\n", h->old, res);
			h->old = res;
		}
		h = h->next;
	}
}
