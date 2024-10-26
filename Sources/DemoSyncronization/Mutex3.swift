// Optimizing Further: spin up to 100 times.

import Synchronization
import Futex

private struct State {
  static let unlocked: UInt32 = 0
  static let lockedWithoutWaiters: UInt32 = 1
  static let lockedWithMaybeWaiters: UInt32 = 2
}

public struct Mutex3<Value: ~Copyable>: ~Copyable, @unchecked Sendable {
  private let state = Atomic<UInt32>(State.unlocked)
  private var value: UnsafeCellHeap<Value>
  
  public init(_ initialValue: consuming sending Value) {
    value = UnsafeCellHeap(initialValue)
  }
  
  deinit {
    value.unsafeDrop()
  }
  
  private func lock() {
    if state.compareExchange(
      expected: State.unlocked,
      desired: State.lockedWithoutWaiters,
      successOrdering: .acquiring,
      failureOrdering: .relaxed
    ).exchanged {
      return
    }
    lockContended()
  }
  
  private func lockContended() {
    var spinCount = 0
    while state.load(ordering: .relaxed) == State.lockedWithoutWaiters &&
            spinCount < 100 {
      spinCount += 1
      hintSpinLoop()
    }
    
    if state.compareExchange(
      expected: State.unlocked,
      desired: State.lockedWithoutWaiters,
      successOrdering: .acquiring,
      failureOrdering: .relaxed
    ).exchanged {
      return
    }
    
    while state.exchange(State.lockedWithMaybeWaiters,
                         ordering: .acquiring) != State.unlocked {
      Futex.wait(state, State.lockedWithMaybeWaiters)
    }
  }
  
  private func unlock() {
    if state.exchange(State.unlocked,
                      ordering: .releasing) == State.lockedWithMaybeWaiters {
      Futex.wakeOne(state)
    }
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
