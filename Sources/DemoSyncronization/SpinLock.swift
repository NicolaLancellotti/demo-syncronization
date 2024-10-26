import Synchronization

private struct State {
  static let unlocked = false
  static let locked = true
}

public struct SpinLock<Value: ~Copyable>: ~Copyable, @unchecked Sendable {
  private let state = Atomic<Bool>(State.unlocked)
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
      hintSpinLoop()
    }
  }
  
  private func unlock() {
    state.store(State.unlocked, ordering: .releasing)
  }
  
  public func withLock<Result, E>(
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
