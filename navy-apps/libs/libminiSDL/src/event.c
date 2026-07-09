#include <NDL.h>
#include <SDL.h>
#include <string.h>

#define keyname(k) #k,
#define keysnap(k) [SDLK_##k] = 0,

static uint8_t keysnap[] = {
	[SDLK_NONE] = 0,
	_KEYS(keysnap)
};

static const char *keyname[] = {
  "NONE",
  _KEYS(keyname)
};

int SDL_PushEvent(SDL_Event *ev) {
  return 0;
}

int SDL_PollEvent(SDL_Event *event) {
	char buf[32];
	if (NDL_PollEvent(buf, sizeof(buf)) == 0) return 0; 
	if (event == NULL) return 1;
	if (buf[1] == 'u') event->type = SDL_KEYUP;
	else if (buf[1] == 'd') event->type = SDL_KEYDOWN;
	for (int i = 1; i < sizeof(keyname) / sizeof(char *); ++i) {
		if (strcmp(buf + 3, keyname[i]) == 0) {
			event->key.keysym.sym = i;
			if (event->type == SDL_KEYUP)
				keysnap[i] = 0;
			else if (event->type == SDL_KEYDOWN)
				keysnap[i] = 1;
			return 1;
		}
	}
  return 1;
}

int SDL_WaitEvent(SDL_Event *event) {
	char buf[32];
	while (NDL_PollEvent(buf, sizeof(buf)) == 0); 
	if (event == NULL) return 1;
	if (buf[1] == 'u') event->type = SDL_KEYUP;
	else if (buf[1] == 'd') event->type = SDL_KEYDOWN;
	for (int i = 1; i < sizeof(keyname) / sizeof(char *); ++i) {
		if (strcmp(buf + 3, keyname[i]) == 0) {
			event->key.keysym.sym = i;
			if (event->type == SDL_KEYUP)
				keysnap[i] = 0;
			else if (event->type == SDL_KEYDOWN)
				keysnap[i] = 1;
			return 1;
		}
	}
  return 1;
}

int SDL_PeepEvents(SDL_Event *ev, int numevents, int action, uint32_t mask) {
  return 0;
}

uint8_t* SDL_GetKeyState(int *numkeys) {
  return keysnap;
}
