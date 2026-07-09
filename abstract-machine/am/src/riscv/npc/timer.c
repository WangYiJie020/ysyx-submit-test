#include <am.h>

#define RTC_ADDR 0xa0000048

static inline uint32_t inl(uintptr_t addr) { return *(volatile uint32_t *)addr; }

static uint64_t start_us = 0;

void __am_timer_init() {
	start_us = (((uint64_t)inl(RTC_ADDR + 4)) << 32) + (uint64_t)inl(RTC_ADDR);
}

void __am_timer_uptime(AM_TIMER_UPTIME_T *uptime) {
  uptime->us = (((uint64_t)inl(RTC_ADDR + 4)) << 32) + (uint64_t)inl(RTC_ADDR);
	uptime->us -= start_us;
}

void __am_timer_rtc(AM_TIMER_RTC_T *rtc) {
  rtc->second = 0;
  rtc->minute = 0;
  rtc->hour   = 0;
  rtc->day    = 0;
  rtc->month  = 0;
  rtc->year   = 1900;
}
