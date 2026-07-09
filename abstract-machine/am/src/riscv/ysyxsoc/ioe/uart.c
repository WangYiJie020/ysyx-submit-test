#include <am.h>
#include <ysyxsoc.h>

void __am_uart_config(AM_UART_CONFIG_T *cfg) {
	cfg->present = true;
}

void __am_uart_rx(AM_UART_RX_T *rx) {
	if ((inb(SERIAL_PORT + 5) & 0x1) == 0) rx->data = 0xff;
	else rx->data = inb(SERIAL_PORT);
}
