import Dispatch
import Synchronization
import Testing

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
