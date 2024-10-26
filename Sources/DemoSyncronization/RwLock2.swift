// Avoiding Busy-Looping Writers

import Synchronization
import Futex

private struct State {
  static let unlocked: UInt32 = 0
  static let writeLocked = UInt32.max
  static let maxReaders = UInt32.max - 1
}

public struct RwLock2<Value: ~Copyable>: ~Copyable, @unchecked Sendable {
  private let state = Atomic<UInt32>(State.unlocked)
  private let writeWakeCounter = Atomic<UInt32>(State.unlocked)
  private var value: UnsafeCellHeap<Value>
  
  public init(_ initialValue: consuming sending Value) {
    value = UnsafeCellHeap(initialValue)
  }
  
  deinit {
    value.unsafeDrop()
  }
  
  // MARK: - Read Lock
  
  private func readLock() {
    var state = self.state.load(ordering: .relaxed)
    while true {
      switch state {
        case State.writeLocked:
          Futex.wait(self.state, State.writeLocked)
          state = self.state.load(ordering: .relaxed)
        case State.maxReaders:
          fatalError("Too many readers")
        default:
          let result = self.state.weakCompareExchange(expected: state,
                                                      desired: state + 1,
                                                      successOrdering: .acquiring,
                                                      failureOrdering: .relaxed)
          switch result.exchanged {
            case true: return
            case false: state = result.original
          }
      }
    }
  }
  
  private func readUnlock() {
    if state.subtract(1, ordering: .releasing).newValue == State.unlocked {
      writeWakeCounter.wrappingAdd(1, ordering: .releasing)
      Futex.wakeOne(writeWakeCounter)
    }
  }
  
  public func withReadLock<Result, E>(
    _ body: (borrowing Value) throws(E) -> Result
  )
  throws(E) -> Result
  where E: Error, Result: ~Copyable {
    readLock()
    defer {
      readUnlock()
    }
    return try value.withUnsafeMutablePointer { (pointer) throws(E) -> Result in
      try body(pointer.pointee)
    }
  }
  
  // MARK: - Write Lock
  
  private func writeLock() {
    while true {
      let result = state.weakCompareExchange(
        expected: State.unlocked,
        desired: State.writeLocked,
        successOrdering: .acquiring,
        failureOrdering: .relaxed)
      switch result.exchanged {
        case true: return
        case false:
          let count = writeWakeCounter.load(ordering: .acquiring)
          if state.load(ordering: .relaxed) != State.unlocked {
            Futex.wait(writeWakeCounter, count)
          }
      }
    }
  }
  
  private func writeUnlock() {
    state.store(State.unlocked, ordering: .releasing)
    writeWakeCounter.wrappingAdd(1, ordering: .releasing)
    Futex.wakeOne(writeWakeCounter)
    Futex.wakeAll(state)
  }
  
  public func withWriteLock<Result, E>(
    _ body: (inout Value) throws(E) -> Result
  )
  throws(E) -> Result
  where E: Error, Result: ~Copyable {
    writeLock()
    defer {
      writeUnlock()
    }
    return try value.withUnsafeMutablePointer { (pointer) throws(E) -> Result in
      try body(&pointer.pointee)
    }
  }
}
