import DemoSyncronization
import Dispatch
import Synchronization
import Testing

struct MutexTests {
  static private let iterations = 1_000_000

  @Test func spinLock() {
    let lock = SpinLock(Structure(value: 0))
    DispatchQueue.concurrentPerform(iterations: MutexTests.iterations) { _ in
      lock.withLock { $0.value += 1 }
    }
    lock.withLock {
      #expect($0.value == MutexTests.iterations)
    }
  }

  @Test func mutex1() {
    let mutex = Mutex1(Structure(value: 0))
    DispatchQueue.concurrentPerform(iterations: MutexTests.iterations) { _ in
      mutex.withLock { $0.value += 1 }
    }
    mutex.withLock {
      #expect($0.value == MutexTests.iterations)
    }
  }

  @Test func mutex2() {
    let mutex = Mutex2(Structure(value: 0))
    DispatchQueue.concurrentPerform(iterations: MutexTests.iterations) { _ in
      mutex.withLock { $0.value += 1 }
    }
    mutex.withLock {
      #expect($0.value == MutexTests.iterations)
    }
  }

  @Test func mutex3() {
    let mutex = Mutex3(Structure(value: 0))
    DispatchQueue.concurrentPerform(iterations: MutexTests.iterations) { _ in
      mutex.withLock { $0.value += 1 }
    }
    mutex.withLock {
      #expect($0.value == MutexTests.iterations)
    }
  }
}
