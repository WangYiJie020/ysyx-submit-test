#include <am.h>
#include <ysyxsoc.h>

void __am_gpu_init() {
}

void __am_gpu_config(AM_GPU_CONFIG_T *cfg) {
	*cfg = (AM_GPU_CONFIG_T) {
		.present = true, .has_accel = false,
		.width = 640, .height = 480,
		.vmemsz = 0
	};
}

void __am_gpu_fbdraw(AM_GPU_FBDRAW_T *ctl) {
	uint32_t *pixels = (uint32_t *)ctl->pixels;
	volatile uint32_t *fb = (uint32_t *)FB_ADDR;
	int screen_w = 640;
	for (int i = ctl->y; i < ctl->y + ctl->h; ++i) {
		for (int j = ctl->x; j < ctl->x + ctl->w; ++j) {
			fb[i*screen_w + j] = pixels[(i - ctl->y)*ctl->w + (j - ctl->x)];
		}
	}
}

void __am_gpu_status(AM_GPU_STATUS_T *status) {
	status->ready = true;
}
