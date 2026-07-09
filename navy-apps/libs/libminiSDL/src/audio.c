#include <NDL.h>
#include <SDL.h>
#include <stdlib.h>

static void (*callback)(void *userdata, uint8_t *stream, int len);
static int audio_pause = 1;
static uint32_t time_interval = 0;
static int samples = 0;

int SDL_OpenAudio(SDL_AudioSpec *desired, SDL_AudioSpec *obtained) {
	if (obtained) {
		obtained->freq = desired->freq;
		obtained->format = desired->format;
		obtained->samples = desired->samples;
		obtained->channels = desired->channels;
		obtained->size = desired->size;
		obtained->callback = desired->callback;
		obtained->userdata = desired->userdata;
	}
	samples = desired->samples;
	time_interval = samples / desired->freq;
	NDL_OpenAudio(desired->freq, desired->channels, desired->samples);
	callback = desired->callback;
  return 0;
}

void SDL_CloseAudio() {
	NDL_CloseAudio();
}

void SDL_PauseAudio(int pause_on) {
	audio_pause = pause_on;
}

void SDL_MixAudio(uint8_t *dst, uint8_t *src, uint32_t len, int volume) {
}

SDL_AudioSpec *SDL_LoadWAV(const char *file, SDL_AudioSpec *spec, uint8_t **audio_buf, uint32_t *audio_len) {
  return NULL;
}

void SDL_FreeWAV(uint8_t *audio_buf) {
}

void SDL_LockAudio() {
}

void SDL_UnlockAudio() {
}

void CallBackHelper() {
	if (time_interval == 0 || audio_pause) return;
	static uint32_t start = 0;
	uint32_t now = SDL_GetTicks();
	if (now - start > time_interval && NDL_QueryAudio() > samples) {
		start = now;
		uint8_t *stream = malloc(samples);
		callback(NULL, stream, samples);
		NDL_PlayAudio(stream, samples);
		free(stream);
	}
}
