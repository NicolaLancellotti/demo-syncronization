import DemoSyncronization
import Dispatch
import Synchronization
import Testing

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
