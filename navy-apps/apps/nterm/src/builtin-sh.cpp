#include <nterm.h>
#include <stdarg.h>
#include <unistd.h>
#include <SDL.h>

char handle_key(SDL_Event *ev);

static void sh_printf(const char *format, ...) {
  static char buf[256] = {};
  va_list ap;
  va_start(ap, format);
  int len = vsnprintf(buf, 256, format, ap);
  va_end(ap);
  term->write(buf, len);
}

static void sh_banner() {
  sh_printf("Built-in Shell in NTerm (NJU Terminal)\n\n");
}

static void sh_prompt() {
  sh_printf("sh> ");
}

static void sh_handle_cmd(const char *cmd) {
	char _cmd[64];
	strcpy(_cmd, cmd);
	_cmd[strlen(_cmd) - 1] = '\0';
	char *token = strtok(_cmd, " ");
	if (token == NULL) return;
	char *argv[8] = {token, NULL};
	int argc = 1;
	char *arg = token;
	arg = strtok(NULL, " ");
	while (arg) {
		for (; *arg == ' '; ++arg);
		argv[argc] = arg;
		arg = strtok(NULL, " ");
		++argc;
	}
	if (argc > sizeof(argv) / sizeof(char *))
		exit(1);
	execvp(token, argv);
}

void builtin_sh_run() {
	setenv("PATH", "/bin:/usr/bin", 0);
  sh_banner();
  sh_prompt();

  while (1) {
    SDL_Event ev;
    if (SDL_PollEvent(&ev)) {
      if (ev.type == SDL_KEYUP || ev.type == SDL_KEYDOWN) {
        const char *res = term->keypress(handle_key(&ev));
        if (res) {
          sh_handle_cmd(res);
          sh_prompt();
        }
      }
    }
    refresh_terminal();
  }
}
