#include <klib.h>
#include <klib-macros.h>
#include <stdint.h>

#if !defined(__ISA_NATIVE__) || defined(__NATIVE_USE_KLIB__)

size_t strlen(const char *s) {
  size_t len = 0;
	for (; s[len] != '\0'; ++len);
	return len;
}

char *strcpy(char *dst, const char *src) {
	assert(src);
  int i = 0;
	for (; src[i] != '\0'; ++i) {
		dst[i] = src[i];
	}

	dst[i] = '\0';
	return dst;
}

char *strncpy(char *dst, const char *src, size_t n) {
  int i = 0;
	for (; src[i] != '\0' && i < n; ++i) {
		dst[i] = src[i];
	}
	for ( ; i < n; ++i) 
		dst[i] = '\0';

	return dst;
}

char *strcat(char *dst, const char *src) {
  int tail = 0;
	for (; dst[tail] != '\0'; ++tail);

	int i = 0;
	for (; src[i] != '\0'; ++i, ++tail) {
		dst[tail] = src[i];
	}

	dst[tail] = '\0';
	return dst;
}

int strcmp(const char *s1, const char *s2) {
	return strncmp(s1, s2, -1);
}

int strncmp(const char *s1, const char *s2, size_t n) {
	for (int i = 0; i < n; ++i) {
		if (s1[i] == '\0' && s2[i] == '\0') 
			return 0;
		else if (s1[i] == '\0')
			return -1;
		else if (s2[i] == '\0')
			return 1;
		else if (s1[i] < s2[i])
			return -1;
		else if (s1[i] > s2[i])
			return 1;
	}
	return 0;
}

void *memset(void *s, int c, size_t n) {
	char *schar = (char *)s;
  for (size_t i = 0; i < n; ++i) {
		schar[i] = c;
	}
	return s;
}

void *memmove(void *dst, const void *src, size_t n) {
	char srcchar[n];
	memcpy(srcchar, src, n);
	memcpy(dst, srcchar, n);
	return dst;
}

void *memcpy(void *out, const void *in, size_t n) {
	char *outchar = (char *) out, *inchar = (char *)in;
  for (size_t i = 0; i < n; ++i) {
		outchar[i] = inchar[i];
	}
	return out;
}

int memcmp(const void *s1, const void *s2, size_t n) {
	char *s1char = (char *)s1, *s2char = (char *)s2;
  for (size_t i = 0; i < n; ++i) {
		if (s1char[i] < s2char[i])
			return -1;
		else if (s1char[i] > s2char[i])
			return 1;
	}
	return 0;
}

#endif
