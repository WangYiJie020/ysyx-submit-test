#include <stdio.h>
#include <string.h>
#include <readline/readline.h>
#include <readline/history.h>
#include <stdint.h>
#include <stdlib.h>
#include <memory.h>

void reg_display();
void cpu_exec(unsigned long n);

int batch_mode = 0;
int wave_trace = 0;

void set_batch_mode() {
	batch_mode = 1;
}

static int cmd_c(char *args) {
	cpu_exec(-1);
	return 0;
}	

static int cmd_q(char *args) {
	return -1;
}

static int cmd_help(char *args);

static int cmd_si(char *args) {
	int steps = 1;
	if (args != NULL)
		sscanf(args, "%d", &steps);
	cpu_exec(steps);
	return 0;
}

static int cmd_info(char *args) {
	char ch = 'r';
	if (args != NULL)
		ch = *args;
	if (ch == 'r')
		reg_display();
	else printf("Usage: info r\n");
	return 0;
}

static int cmd_x(char *args) {
	int num = 1;
	uint8_t* haddr = NULL;
	uint32_t paddr = 0;
	if (args == NULL) return 0;
	sscanf(args, "%d %x", &num, &paddr);
	haddr = guest2host(paddr);
	uint32_t *addr = (uint32_t *)haddr;
	for (; num > 0; --num) {
		printf("%0#8x:  %08x\n", paddr, *addr);
		addr += 1;
		paddr += 4;
	}
	return 0;
}

static int cmd_wt(char *args) {
	if (args == NULL) wave_trace = !wave_trace;
	else if (*args == 'o') wave_trace = 1;
	else if (*args == 'c') wave_trace = 0;
	else printf("Usage: 'wt o' to open, 'wt c' to close\n");
	printf("wave_trace is %s\n", wave_trace ? "ON" : "OFF");
	return 0;
}

static char *rl_gets() {
	static char *line_read = NULL;

	if (line_read) {
		free(line_read);
		line_read = NULL;
	}

	line_read = readline("(npc) ");

	if (line_read && *line_read) {
		add_history(line_read);
	}

	return line_read;
}

static struct {
	const char *name;
	const char *description;
	int (*handler) (char *);
} cmd_table [] = {
	{ "help", "Display information about all supported commands", cmd_help },
	{ "c", "Continue the execution of the program", cmd_c },
	{ "q", "Exit NPC", cmd_q },
	{ "si", "Execute the program for several steps", cmd_si },
	{ "info", "Print the status of the program", cmd_info },
	{ "x", "Scan the memory", cmd_x},
	{ "wt", "wave trace", cmd_wt},
};

#define NR_CMD sizeof(cmd_table)/sizeof(cmd_table[0])

static int cmd_help(char *args) {
	char *arg = strtok(NULL, " ");
	int i;

	if (arg == NULL) {
		for (i = 0; i < NR_CMD; ++i) {
			printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
		}
	}
	else {
		for (i = 0; i < NR_CMD; ++i) {
			if (strcmp(arg, cmd_table[i].name) == 0) {
				printf ("%s - %s", cmd_table[i].name, cmd_table[i].description);
				return 0;
			}
		}
		printf("Unknown command '%s'\n", arg);
	}
	return 0;
}

void sdb_mainloop() {
	if (batch_mode) {
		cmd_c(NULL);
		return;
	}

	for (char *str; (str = rl_gets()) != NULL; ) {
		char *str_end = str + strlen(str);

		char *cmd = strtok(str, " ");
		if (cmd == NULL) { continue; }

		char *args = cmd + strlen(cmd) + 1;
		if (args >= str_end) {
			args == NULL;
		}

		int i;
		for (i = 0; i < NR_CMD; ++i) {
			if (strcmp(cmd, cmd_table[i].name) == 0) {
				if (cmd_table[i].handler(args) < 0) { return; }
				break;
			}
		}

		if (i == NR_CMD) { printf("Unkown command '%s'\n", cmd); }
	}
}
