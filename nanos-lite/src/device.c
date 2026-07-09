#include <common.h>

#if defined(MULTIPROGRAM) && !defined(TIME_SHARING)
# define MULTIPROGRAM_YIELD() yield()
#else
# define MULTIPROGRAM_YIELD()
#endif

#define NAME(key) \
  [AM_KEY_##key] = #key,

static const char *keyname[256] __attribute__((used)) = {
  [AM_KEY_NONE] = "NONE",
  AM_KEYS(NAME)
};

size_t serial_write(const void *buf, size_t offset, size_t len) {
	for (int i = 0; i < len; ++i) {
		putch(*((uint8_t *)buf + i));
	}
  return len;
}

size_t events_read(void *buf, size_t offset, size_t len) {
	AM_INPUT_KEYBRD_T input = io_read(AM_INPUT_KEYBRD);
	int keycode = input.keycode;
	bool keydown = input.keydown;
	char *_buf = (char *)buf;
	const char kd[] = "kd ", ku[] = "ku ";
	if (keycode == 0)
		return 0;
	if (keydown) 
		strncpy(_buf, kd, len);
	else 
		strncpy(_buf, ku, len);
	_buf += 3;
	if (len > 3) 
	  strncpy(_buf, keyname[keycode], len - 3);
	size_t len_total = 3 + strlen(keyname[keycode]);
	if (len > len_total) len = len_total;
	return len;
}

size_t dispinfo_read(void *buf, size_t offset, size_t len) {
	AM_GPU_CONFIG_T gpu = io_read(AM_GPU_CONFIG);
	int width = gpu.width;
	int height = gpu.height;
	int len_total = snprintf((char *)buf, len, "WIDTH:%d\nHEIGHT:%d\n", width, height);
  return len_total;
}

size_t fb_write(const void *buf, size_t offset, size_t len) {
	AM_GPU_CONFIG_T gpu = io_read(AM_GPU_CONFIG);
	int width = gpu.width;
	int x = offset / 4 % width;
	int y = offset / 4 / width;
	uint32_t _buf[400];
	for (int i = 0; i < len / 4; ++i) 
		_buf[i] = *((uint32_t *)buf + i);
	io_write(AM_GPU_FBDRAW, x, y, _buf, len / 4, 1, 1);
	return len;
}

size_t sb_write(const void *buf, size_t offset, size_t len) {
	while (len > io_read(AM_AUDIO_STATUS).count);
	uint8_t _buf[len];
	for (int i = 0; i < len; ++i) {
		_buf[i] = *((uint8_t *)buf + i);
	}
	Area Area_buf = (Area) {_buf, _buf + len};
	io_write(AM_AUDIO_PLAY, Area_buf);
	return len;
}

size_t sbctl_read(void *buf, size_t offset, size_t len) {
	if (len < sizeof(int)) return 0;
	int count = io_read(AM_AUDIO_STATUS).count;
	*(int *) buf = count;
	return sizeof(int);
}

size_t sbctl_write(const void *buf, size_t offset, size_t len) {
	if (len < sizeof(int) * 3) return 0;
	int freq = *(int *)buf, channels = *((int *) buf + 1), samples = *((int *) buf + 2);
	io_write(AM_AUDIO_CTRL, freq, channels, samples);
	return sizeof(int) * 3;
}

void init_device() {
  Log("Initializing devices...");
  ioe_init();
}
