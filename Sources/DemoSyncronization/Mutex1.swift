import Synchronization
import Futex

// MARK: - Mutex

private struct State {
  static let unlocked: UInt32 = 0
  static let locked: UInt32 = 1
}

public struct Mutex1<Value: ~Copyable>: ~Copyable, @unchecked Sendable {
  private let state = Atomic<UInt32>(State.unlocked)
  private var value: UnsafeCellHeap<Value>
  
  public init(_ initialValue: consuming sending Value) {
    value = UnsafeCellHeap(initialValue)
  }
  
  deinit {
    value.unsafeDrop()
  }
  
  func lock() {
    while !state.weakCompareExchange(
      expected: State.unlocked,
      desired: State.locked,
      successOrdering: .acquiring,
      failureOrdering: .relaxed
    ).exchanged {
      Futex.wait(state, State.locked)
    }
  }
  
  func unlock() {
    state.store(State.unlocked, ordering: .releasing)
    Futex.wakeOne(state)
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

// MARK: - Condition Variable

extension Mutex1 where Value: ~Copyable {
  public func withHandler<Result, E>(
    _ body: (borrowing Handler) throws(E) -> Result
  )
  throws(E) -> Result
  where E: Error, Result: ~Copyable {
    lock()
    defer {
      unlock()
    }
    
    return try withUnsafePointer(to: self) { (pointer) throws(E) -> Result in
      try body(Handler(mutexPointer: pointer))
    }
  }
  
  public struct Handler: ~Copyable, @unchecked Sendable {
    let mutexPointer: UnsafePointer<Mutex1>
    
    public func withValue<Result, E>(
      _ body: (inout Value) throws(E) -> Result
    )
    throws(E) -> Result
    where E: Error, Result: ~Copyable {
      return try mutexPointer.pointee.value.withUnsafeMutablePointer { (pointer) throws(E) -> Result in
        try body(&pointer.pointee)
      }
    }
  }
  
}

public struct ConditionVariable: ~Copyable, @unchecked Sendable {
  private let counter = Atomic<UInt32>(0)
  private let waitersCount = Atomic<UInt32>(0)
  
  public init() {}
  
  public func notifyOne() {
    if waitersCount.load(ordering: .relaxed) > 0 {
      counter.wrappingAdd(1, ordering: .relaxed)
      Futex.wakeOne(counter)
    }
  }
  
  public func notifyAll() {
    if waitersCount.load(ordering: .relaxed) > 0 {
      counter.wrappingAdd(1, ordering: .relaxed)
      Futex.wakeAll(counter)
    }
  }
  
  public func wait<Value: ~Copyable>(_ handler: borrowing Mutex1<Value>.Handler) {
    waitersCount.add(1, ordering: .relaxed)
    let counterValue = counter.load(ordering: .relaxed)
    
    handler.mutexPointer.pointee.unlock()
    
    Futex.wait(counter, counterValue)
    waitersCount.subtract(1, ordering: .relaxed)
    
    handler.mutexPointer.pointee.lock()
  }
}
