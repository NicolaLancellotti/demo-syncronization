import DemoSyncronization
import Dispatch
import Synchronization
import Testing

struct RwLockTests {
  @Test func rwLock1() {
    let concurrentQueue = DispatchQueue(
      label: "concurrentQueue",
      qos: .userInteractive,
      attributes: .concurrent)

    let lock = RwLock1(Structure(value: 0))
    let iterations = 10
    let writes = Atomic<Int>(0)

    for _ in 0..<iterations {
      concurrentQueue.async {
        lock.withWriteLock {
          $0.value += 1
          writes.store($0.value, ordering: .relaxed)
        }
      }
      concurrentQueue.async {
        lock.withReadLock {
          #expect($0.value == writes.load(ordering: .relaxed))
        }
      }
    }

    concurrentQueue.asyncAndWait(flags: .barrier) {
      lock.withReadLock {
        #expect($0.value == iterations)
      }
    }
  }

  @Test func rwLock2() {
    let concurrentQueue = DispatchQueue(
      label: "concurrentQueue",
      qos: .userInteractive,
      attributes: .concurrent)

    let lock = RwLock2(Structure(value: 0))
    let iterations = 10
    let writes = Atomic<Int>(0)

    for _ in 0..<iterations {
      concurrentQueue.async {
        lock.withWriteLock {
          $0.value += 1
          writes.store($0.value, ordering: .relaxed)
        }
      }
      concurrentQueue.async {
        lock.withReadLock {
          #expect($0.value == writes.load(ordering: .relaxed))
        }
      }
    }

    concurrentQueue.asyncAndWait(flags: .barrier) {
      lock.withReadLock {
        #expect($0.value == iterations)
      }
    }
  }

  @Test func rwLock3() {
    let concurrentQueue = DispatchQueue(
      label: "concurrentQueue",
      qos: .userInteractive,
      attributes: .concurrent)

    let lock = RwLock3(Structure(value: 0))
    let iterations = 10
    let writes = Atomic<Int>(0)

    for _ in 0..<iterations {
      concurrentQueue.async {
        lock.withWriteLock {
          $0.value += 1
          writes.store($0.value, ordering: .relaxed)
        }
      }
      concurrentQueue.async {
        lock.withReadLock {
          #expect($0.value == writes.load(ordering: .relaxed))
        }
      }
    }

    concurrentQueue.asyncAndWait(flags: .barrier) {
      lock.withReadLock {
        #expect($0.value == iterations)
      }
    }
  }
}
