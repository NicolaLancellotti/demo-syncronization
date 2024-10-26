// https://docs.rs/atomic-wait/latest/x86_64-apple-darwin/src/atomic_wait/macos.rs.html

import CXXFutex
import Synchronization

public func wait(_ atomic: borrowing Atomic<UInt32>, _ expected: UInt32) {
  withUnsafePointer(to: atomic) {
    let monitor = _ZNSt3__123__libcpp_atomic_monitorEPVKv($0)
    if atomic.load(ordering: .relaxed) != expected {
      return
    }
    _ZNSt3__120__libcpp_atomic_waitEPVKvx($0, monitor)
  }
}

public func wakeOne(_ atomic: borrowing Atomic<UInt32>) {
  withUnsafePointer(to: atomic) {
    _ZNSt3__123__cxx_atomic_notify_oneEPVKv($0)
  }
}

public func wakeAll(_ atomic: borrowing Atomic<UInt32>) {
  withUnsafePointer(to: atomic) {
    _ZNSt3__123__cxx_atomic_notify_allEPVKv($0)
  }
}
