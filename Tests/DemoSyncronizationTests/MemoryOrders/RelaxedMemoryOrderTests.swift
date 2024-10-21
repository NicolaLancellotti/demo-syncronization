import Dispatch
import Synchronization
import Testing

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
