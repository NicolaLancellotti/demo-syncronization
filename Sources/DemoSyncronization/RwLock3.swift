// Avoiding Writer Starvation

import Synchronization
import Futex

private struct State {
  static let unlocked: UInt32 = 0
  static let writeLocked = UInt32.max
  static let maxReaders = UInt32.max - 1
}

public struct RwLock3<Value: ~Copyable>: ~Copyable, @unchecked Sendable {
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
      switch state.isMultiple(of: 2) {
        case true:
          if state == State.maxReaders {
            fatalError("Too many readers")
          }
          let result = self.state.weakCompareExchange(expected: state,
                                                      desired: state + 2,
                                                      successOrdering: .acquiring,
                                                      failureOrdering: .relaxed)
          switch result.exchanged {
            case true: return
            case false: state = result.original
          }
        case false: // Write locked
          Futex.wait(self.state, state)
          state = self.state.load(ordering: .relaxed)
      }
    }
  }
  
  private func readUnlock() {
    if state.subtract(2, ordering: .releasing).newValue == 1 {
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
    var state = self.state.load(ordering: .relaxed)
    while true {
      if state <= 1 {
        let result = self.state.compareExchange(
          expected: state,
          desired: State.writeLocked,
          successOrdering: .acquiring,
          failureOrdering: .relaxed)
        switch result.exchanged {
          case true: return
          case false: state = result.original
        }
      }
      
      if state.isMultiple(of: 2) {
        let result = self.state.compareExchange(
          expected: state,
          desired: state + 1,
          successOrdering: .relaxed,
          failureOrdering: .relaxed)
        switch result.exchanged {
          case true: break
          case false: 
            state = result.original
            continue
        }
      }
      
      let count = writeWakeCounter.load(ordering: .acquiring)
      state = self.state.load(ordering: .relaxed)
      
      if state >= 2 {
        Futex.wait(writeWakeCounter, count)
        state = self.state.load(ordering: .relaxed)
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
