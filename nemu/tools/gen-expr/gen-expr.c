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

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <assert.h>
#include <string.h>

// this should be enough
static char buf[65536] = {};
static char code_buf[65536 + 128] = {}; // a little larger than `buf`
static char *code_format =
"#include <stdio.h>\n"
"int main() { "
"  unsigned result = (unsigned)%s; "
"  printf(\"%%u\", result); "
"  return 0; "
"}";

static char *buf_start = NULL;
static char *buf_end = buf + sizeof(buf)/sizeof(buf[0]);

static uint32_t choose(uint32_t n) {
	return rand() % n;
}

static void gen_num() {
	uint32_t num = choose(INT8_MAX);
	uint32_t words = snprintf(buf_start, buf_end-buf_start, "%d", num);
	buf_start += words;
}

static void gen(char ch) {
	uint32_t words = snprintf(buf_start, buf_end-buf_start, "%c", ch);
	buf_start += words;
}

static void gen_rand_op() {
	uint32_t op = choose(4);
	switch (op) {
		case 0: gen('+'); break;
		case 1: gen('-'); break;
		case 2: gen('*'); break;
		case 3: gen('/'); break;
	}
}

static void gen_rand_space() {
	uint32_t space = choose(2);
	if (space) {
		gen(' ');
		gen_rand_space();
	}
}

static void gen_rand_expr() {
	gen_rand_space();
	switch (choose(3)) {
		case 1: gen_num(); break;
		case 2: gen('('); gen_rand_expr(); gen(')'); break;
		default: gen_rand_expr(); gen_rand_op(); gen_rand_expr();
	}
	gen_rand_space();
}

int main(int argc, char *argv[]) {
  int seed = time(0);
  srand(seed);
  int loop = 1;
  if (argc > 1) {
    sscanf(argv[1], "%d", &loop);
  }
  int i;
  for (i = 0; i < loop; i ++) {
		buf_start = buf;
    gen_rand_expr();

    sprintf(code_buf, code_format, buf);

    FILE *fp = fopen("/tmp/.code.c", "w");
    assert(fp != NULL);
    fputs(code_buf, fp);
    fclose(fp);

    int ret = system("gcc /tmp/.code.c -Wall -Werror=div-by-zero -o /tmp/.expr");
    if (ret != 0) continue;

    fp = popen("/tmp/.expr", "r");
    assert(fp != NULL);

    uint32_t result = 0;
    ret = fscanf(fp, "%u", &result);
    pclose(fp);

    printf("%u %s\n", result, buf);
  }
  return 0;
}
