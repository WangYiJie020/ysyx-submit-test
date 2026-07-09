#include <am.h>
#include <klib.h>
#include <klib-macros.h>
#include <stdarg.h>

#if !defined(__ISA_NATIVE__) || defined(__NATIVE_USE_KLIB__)

int printf(const char *fmt, ...) {
	va_list ap;
	char out[512] = {'\0'};

	va_start(ap, fmt);
	int count = vsprintf(out, fmt, ap);
	va_end(ap);

	assert(count <= sizeof(out));

	for (int i = 0; out[i] != '\0'; ++i) {
		putch(out[i]);
	}
	return count;
}

static int num2str(int data, char *str, int base, int format, int sign) {
	const char table[16] = "0123456789abcdef";
	int len = 0;
	unsigned num = data;
	if (sign && data < 0) {
		num = -data;
		str[len] = '-';
		++len;
	}
	if (format) {
		str[len] = '0'; ++len;
		str[len] = 'x'; ++len;
	}
	char buf[32] = {'\0'};
	int i = 0;
	while (num) {
		buf[i] = table[num % base];
		num /= base;
		++i;
	}
	if (i > 0) --i;
	else buf[0] = '0';
	for (; i >= 0; --i, ++len) {
		str[len] = buf[i];
	}
	return len;
}

int vsprintf(char *out, const char *fmt, va_list ap) {
	char *start = out;
	for (int i = 0; fmt[i] != '\0'; ++i) {
		if (fmt[i] == '%') {
			++i;
			switch (fmt[i]) {
				case 'p':
					out += num2str(va_arg(ap, int), out, 16, 1, 0);
					break;
				case 'd':
					out += num2str(va_arg(ap, int), out, 10, 0, 1);
					break;
				case 'x':
					out += num2str(va_arg(ap, int), out, 16, 0, 1);
					break;
				case 's':
					char *str2 = va_arg(ap, char*);
					for (; *str2 != '\0'; ++str2, ++out) {
						*out = *str2;
					}
				break;
				case 'c':
					char ch = va_arg(ap, int);
					*out = ch;
					++out;
				break;
			}
		}
		else {
			*out = fmt[i];
			++out;
		}
	}
	*out = '\0';
	return out - start;
}

int sprintf(char *out, const char *fmt, ...) {
	va_list ap;

	va_start(ap, fmt);
	int count = vsprintf(out, fmt, ap);
	va_end(ap);

	return count;
}

int snprintf(char *out, size_t n, const char *fmt, ...) {
	va_list ap;

	va_start(ap, fmt);
	int count = vsnprintf(out, n, fmt, ap);
	va_end(ap);

	return count;
}

int vsnprintf(char *out, size_t n, const char *fmt, va_list ap) {
  char _out[256] = {'\0'};
	int len = vsprintf(_out, fmt, ap);
	for (int i = 0; i < n; ++i){
		out[i] = _out[i];
	}
	if (len > n) len = n;
	return n;
}

#endif
