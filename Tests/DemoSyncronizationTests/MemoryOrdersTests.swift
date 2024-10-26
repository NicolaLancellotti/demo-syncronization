import DemoSyncronization
import Dispatch
import Synchronization
import Testing

struct MemoryOrdersTests {
  @Test func relaxedMemoryOrder() {
    let max: Int = 10
    let counter = Atomic<Int>(1)

    @Sendable func makeIdentifier() -> Int? {
      var id = counter.load(ordering: .relaxed)
      if id > max {
        return nil
      }

      while true {
        let (exchanged, original) = counter.weakCompareExchange(
          expected: id,
          desired: id + 1,
          ordering: .relaxed)
        switch exchanged {
        case true: return id
        case false: id = original
        }
      }
    }

    let mutex = Synchronization.Mutex([Int?]())

    DispatchQueue.concurrentPerform(iterations: max + 1) { _ in
      let id = makeIdentifier()
      mutex.withLock { $0.append(id) }
    }

    mutex.withLock {
      #expect($0.count == max + 1)
      #expect($0.compactMap { $0 }.sorted() == Array(1...10))
    }
  }

  @Test func releaseAcquireMemoryOrder() {
    do {
      nonisolated(unsafe) var data: Int = 0
      let ready = Atomic<Bool>(false)

      DispatchQueue.global().async {
        sleep(2)
        data = 1
        ready.store(true, ordering: .releasing)
      }

      while !ready.load(ordering: .acquiring) {
        sleep(1)
      }
      #expect(data == 1)
    }

    do {
      nonisolated(unsafe) var data: Int = 0
      let lock = Atomic<Bool>(false)

      DispatchQueue.concurrentPerform(iterations: 10) { _ in
        while !lock.weakCompareExchange(
          expected: false,
          desired: true,
          successOrdering: .acquiring,
          failureOrdering: .relaxed
        ).exchanged {
          hintSpinLoop()
        }
        data += 1
        lock.store(false, ordering: .releasing)
      }
      #expect(data == 10)
    }
  }

  @Test func sequentiallyConsistentMemoryOrder() {
    nonisolated(unsafe) var data: Int = 0
    let atomic1 = Atomic<Bool>(false)
    let atomic2 = Atomic<Bool>(false)

    @Sendable
    func tryStore(atomic1: borrowing Atomic<Bool>, atomic2: borrowing Atomic<Bool>, value: Int) {
      atomic1.store(true, ordering: .sequentiallyConsistent)
      if !atomic2.load(ordering: .sequentiallyConsistent) {
        data += value
      }
    }

    let concurrentQueue = DispatchQueue(
      label: "concurrentQueue",
      qos: .default,
      attributes: .concurrent)

    concurrentQueue.async {
      tryStore(atomic1: atomic1, atomic2: atomic2, value: 1)
    }

    concurrentQueue.async {
      tryStore(atomic1: atomic2, atomic2: atomic1, value: 2)
    }

    concurrentQueue.asyncAndWait(flags: .barrier) {
      #expect(data >= 0 && data <= 2)
    }
  }
}
