// https://docs.rs/atomic-wait/latest/x86_64-apple-darwin/src/atomic_wait/macos.rs.html

#ifndef Futex_hpp
#define Futex_hpp

#include <cstdint>

extern "C" {
int64_t _ZNSt3__123__libcpp_atomic_monitorEPVKv(void const volatile *);
void _ZNSt3__120__libcpp_atomic_waitEPVKvx(void const volatile *, int64_t monitor);
void _ZNSt3__123__cxx_atomic_notify_oneEPVKv(void const volatile *);
void _ZNSt3__123__cxx_atomic_notify_allEPVKv(void const volatile *);
}

#endif
