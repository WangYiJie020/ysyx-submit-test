#include <sys/time.h>
#include <stdio.h>
#include <NDL.h>

#define HALF_SECOND 500
#define SECOND (2 * HALF_SECOND)

int main() {
	printf("clock start\n");

	uint32_t start = NDL_GetTicks();
	uint32_t interval = 0;
	int half_sec = 1;
  while (1) {
		while(interval / HALF_SECOND < half_sec) {
			interval = NDL_GetTicks() - start;
		}
		printf("%d half_sec\n", half_sec ++);
	}
	return 0;
}
