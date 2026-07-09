#include <am.h>

#define RTC_ADDR 0x02000000

static inline uint32_t inl(uintptr_t addr) { return *(volatile uint32_t *)addr; }

void __am_timer_init() {
}

void __am_timer_uptime(AM_TIMER_UPTIME_T *uptime) {
  uint64_t total_cycle = (((uint64_t)inl(RTC_ADDR + 4)) << 32) + (uint64_t)inl(RTC_ADDR);
	//让uptime返回的时间（周期数）除以时钟速率以接近真实时间
	uptime->us = total_cycle / 773;
}

void __am_timer_rtc(AM_TIMER_RTC_T *rtc) {
  rtc->second = 0;
  rtc->minute = 0;
  rtc->hour   = 0;
  rtc->day    = 0;
  rtc->month  = 0;
  rtc->year   = 1900;
}
