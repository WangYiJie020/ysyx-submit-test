#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/time.h>
#include <fcntl.h>

static int evtdev = -1;
static int fbdev = -1;
static int screen_w = 0, screen_h = 0;
static int canvas_w = 0, canvas_h = 0;
static uint32_t start_time = 0;

uint32_t NDL_GetTicks() {
	struct timeval tv;
	gettimeofday(&tv, NULL);
  return tv.tv_sec * 1000 + tv.tv_usec / 1000 - start_time;
}

int NDL_PollEvent(char *buf, int len) {
  int fd = open("/dev/events", 0, 0);
	len = read(fd, buf, len);
	close(fd);
	if (len > 0) return 1;
	return 0;
}

void NDL_OpenCanvas(int *w, int *h) {
  if (getenv("NWM_APP")) {
    int fbctl = 4;
    fbdev = 5;
    screen_w = *w; screen_h = *h;
    char buf[64];
    int len = sprintf(buf, "%d %d", screen_w, screen_h);
    // let NWM resize the window and create the frame buffer
    write(fbctl, buf, len);
    while (1) {
      // 3 = evtdev
      int nread = read(3, buf, sizeof(buf) - 1);
      if (nread <= 0) continue;
      buf[nread] = '\0';
      if (strcmp(buf, "mmap ok") == 0) break;
    }
    close(fbctl);
  }
	else {
		int fd = open("/proc/dispinfo", 0, 0);
		char buf[64];
		read(fd, buf, sizeof(buf));
		sscanf(buf, "WIDTH:%d\nHEIGHT:%d\n", &screen_w, &screen_h);
		if (*w == 0 && *h == 0) {
			*h = screen_h;
			*w = screen_w;
		}
		canvas_h = *h;
		canvas_w = *w;
	}
}

void NDL_DrawRect(uint32_t *pixels, int x, int y, int w, int h) {
	x += (screen_w - canvas_w) / 2;
	y += (screen_h - canvas_h) / 2;
	int fd = open("/dev/fb", 0, 0);
	size_t offset = 4 * (y * screen_w + x);
	for (int i = 0; i < h; ++i) {
		lseek(fd, offset, SEEK_SET);
		write(fd, pixels, w * 4);
		pixels += w;
		offset += screen_w * 4;
	}
	close(fd);
}

void NDL_OpenAudio(int freq, int channels, int samples) {
	int fd = open("/dev/sbctl", 0, 0);
	int buf[3] = {freq, channels, samples};
	write(fd, buf, sizeof(buf));
}

void NDL_CloseAudio() {
}

int NDL_PlayAudio(void *buf, int len) {
	int fd = open("/dev/sb", 0, 0);
	len = write(fd, buf, len);
  return len;
}

int NDL_QueryAudio() {
	int fd = open("dev/sbctl", 0, 0);
	int count;
	read(fd, count, sizeof(count));
  return count;
}

int NDL_Init(uint32_t flags) {
	struct timeval tv;
	gettimeofday(&tv, NULL);
  start_time = tv.tv_sec * 1000 + tv.tv_usec / 1000;
  if (getenv("NWM_APP")) {
    evtdev = 3;
  }
  return 0;
}

void NDL_Quit() {
}
