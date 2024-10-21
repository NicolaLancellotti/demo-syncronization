import DemoSyncronization
import Dispatch
import Synchronization
import Testing

let iterations = 10_000_000

struct MutexTests {
  @Test func spinLock() {
    let lock = SpinLock<Int>(0)
    DispatchQueue.concurrentPerform(iterations: iterations) { _ in
      lock.withLock { $0 += 1 }
    }
    lock.withLock {
      #expect($0 == iterations)
    }
  }
  
  @Test func mutex1() {
    let lock = DemoSyncronization.Mutex1<Int>(0)
    DispatchQueue.concurrentPerform(iterations: iterations) { _ in
      lock.withLock { $0 += 1 }
    }
    lock.withLock {
      #expect($0 == iterations)
    }
  }
  
  @Test func mutex2() {
    let lock = DemoSyncronization.Mutex2<Int>(0)
    DispatchQueue.concurrentPerform(iterations: iterations) { _ in
      lock.withLock { $0 += 1 }
    }
    lock.withLock {
      #expect($0 == iterations)
    }
  }
  
  @Test func mutex3() {
    let lock = DemoSyncronization.Mutex3<Int>(0)
    DispatchQueue.concurrentPerform(iterations: iterations) { _ in
      lock.withLock { $0 += 1 }
    }
    lock.withLock {
      #expect($0 == iterations)
    }
  }
}
