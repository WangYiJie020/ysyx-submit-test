#include <am.h>
#include <sys/time.h>
#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/stat.h>
#include <unistd.h>
#include <assert.h>

#define NAME(key) \
  [AM_KEY_##key] = #key,

static const char *keyname[256] __attribute__((used)) = {
	[AM_KEY_NONE] = "NONE",
	AM_KEYS(NAME)
};

void __am_timer_config(AM_TIMER_CONFIG_T *cfg) {
	cfg->present = true; cfg->has_rtc = true;
}

void __am_timer_rtc(AM_TIMER_RTC_T *rtc) {
	rtc->year = 1900;
	rtc->month = rtc->day = rtc->hour = rtc->minute = rtc->second = 0;
}

void __am_timer_uptime(AM_TIMER_UPTIME_T *uptime) {
	struct timeval tv;
	gettimeofday(&tv, NULL);
	uptime->us = tv.tv_sec * 1000000 + tv.tv_usec;
}

void __am_input_config(AM_INPUT_CONFIG_T *cfg) {
	cfg->present = true;
}

void __am_input_keybrd(AM_INPUT_KEYBRD_T *kbd) {
	int fd = open("/dev/events", 0, 0);
	char buf[32];
	if (read(fd, buf, sizeof(buf)) == 0) {
		kbd->keycode = 0;
		close(fd);
		return;
	}
	close(fd);
	if (buf[1] == 'd')
		kbd->keydown = true;
	else if (buf[1] == 'u') 
		kbd->keydown = false;
	for (int i = 1; i < sizeof(keyname) / sizeof(char *); ++i) {
		if (strcmp(keyname[i], buf + 3) == 0) {
			kbd->keycode = i;
			return;
		}
	}
}

void __am_gpu_config(AM_GPU_CONFIG_T *cfg) {
	int fd = open("/proc/dispinfo", 0, 0);
	char buf[64];
	read(fd, buf, sizeof(buf));
	sscanf(buf, "WIDTH:%d\nHEIGHT:%d\n", &cfg->width, &cfg->height);
	cfg->present = true; cfg->has_accel = false; cfg->vmemsz = 0;
	close(fd);
}

void __am_gpu_fbdraw(AM_GPU_FBDRAW_T *ctl) {
	int width, height;
	int fd = open("/proc/dispinfo", 0, 0);
	char buf[64];
	read(fd, buf, sizeof(buf));
	sscanf(buf, "WIDTH:%d\nHEIGHT:%d\n", &width, &height);
	close(fd);
	fd = open("/dev/fb", 0, 0);
	size_t offset = 4 * (ctl->y * width + ctl->x);
	for (int i = 0; i < ctl->h; ++i) {
		lseek(fd, offset, SEEK_SET);
		write(fd, ctl->pixels, 4 * ctl->w);
		ctl->pixels += ctl->w;
		offset += width * 4;
	}
	close(fd);
}

typedef void (*handler_t)(void *buf);
static void *lut[128] = {
	[AM_TIMER_CONFIG] = __am_timer_config,
	[AM_TIMER_RTC   ] = __am_timer_rtc,
	[AM_TIMER_UPTIME] = __am_timer_uptime,
	[AM_INPUT_CONFIG] = __am_input_config,
	[AM_INPUT_KEYBRD] = __am_input_keybrd,
	[AM_GPU_CONFIG  ] = __am_gpu_config,
	[AM_GPU_FBDRAW  ] = __am_gpu_fbdraw,
};

static void fail(void *buf) { printf("access nonexist register\n"); assert(0); }

bool ioe_init() {
	for (int i = 0; i < sizeof(lut) / sizeof(void *); i++)
		if (!lut[i]) lut[i] = fail;
  return true;
}

void ioe_read (int reg, void *buf) { ((handler_t)lut[reg])(buf); }
void ioe_write(int reg, void *buf) { ((handler_t)lut[reg])(buf); }
