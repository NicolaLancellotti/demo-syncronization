import Dispatch
import Synchronization
import Futex

private struct State {
  static let unlocked: UInt32 = 0
  static let locked: UInt32 = 1
}

public struct Mutex1<Value>: ~Copyable, @unchecked Sendable where Value: ~Copyable {
  private let state = Atomic<UInt32>(State.unlocked)
  private var value: UnsafeCellHeap<Value>
  
  public init(_ initialValue: consuming sending Value) {
    value = UnsafeCellHeap(initialValue)
  }
  
  deinit {
    value.unsafeDrop()
  }
  
  private func lock() {
    while !state.weakCompareExchange(
      expected: State.unlocked,
      desired: State.locked,
      successOrdering: .acquiring,
      failureOrdering: .relaxed
    ).exchanged {
      Futex.wait(state, State.locked)
    }
  }
  
  private func unlock() {
    state.store(State.unlocked, ordering: .releasing)
    Futex.wakeOne(state)
  }
  
  public borrowing func withLock<Result, E>(
    _ body: (inout Value) throws(E) -> Result
  )
  throws(E) -> Result
  where E: Error, Result: ~Copyable {
    lock()
    defer {
      unlock()
    }
    return try value.withUnsafeMutablePointer { (pointer) throws(E) -> Result in
      try body(&pointer.pointee)
    }
  }
}
