import Synchronization

private let maxReferences = UInt.max / 2
private let locked = UInt.max

private struct ArcData<Value: ~Copyable>: ~Copyable {
  let strongCount = Atomic<UInt>(1)  // strong refs
  let weakCount = Atomic<UInt>(1)  // weak refs + (strong refs > 0 ? 1 : 0)
  var value: UnsafeCellHeap<Value>

  init(_ initialValue: consuming Value) {
    self.value = .init(initialValue)
  }

  static func drop(_ ptr: ArcDataPointer<Value>) {
    ptr.deinitialize(count: 1)
    ptr.deallocate()
  }

  deinit {
    print("ArcData - deinit")
  }
}

private typealias ArcDataPointer<T: ~Copyable> = UnsafeMutablePointer<ArcData<T>>

public struct Weak<T: Sendable & ~Copyable>: ~Copyable, @unchecked Sendable {
  private let arcDataPtr: ArcDataPointer<T>

  fileprivate init(arcDataPtr: ArcDataPointer<T>) {
    self.arcDataPtr = arcDataPtr
  }

  deinit {
    if arcDataPtr.pointee.weakCount.subtract(1, ordering: .releasing).newValue == 0 {
      atomicMemoryFence(ordering: .acquiring)
      ArcData.drop(arcDataPtr)
    }
  }

  public func clone() -> Weak {
    guard arcDataPtr.pointee.weakCount.add(1, ordering: .relaxed).newValue <= maxReferences else {
      fatalError()
    }
    return Weak(arcDataPtr: arcDataPtr)
  }

  public func upgrade() -> Arc<T>? {
    var strongCount = arcDataPtr.pointee.strongCount.load(ordering: .relaxed)
    while true {
      if strongCount == 0 {
        return nil
      }
      precondition(strongCount < maxReferences)

      let (exchanged, newStrongCount) = arcDataPtr.pointee.strongCount.weakCompareExchange(
        expected: strongCount, desired: strongCount + 1, ordering: .relaxed)
      if exchanged {
        return Arc(arcDataPtr: arcDataPtr)
      } else {
        strongCount = newStrongCount
      }
    }
  }
}

public struct Arc<T: Sendable & ~Copyable>: ~Copyable, @unchecked Sendable {
  private let arcDataPtr: UnsafeMutablePointer<ArcData<T>>

  fileprivate init(arcDataPtr: UnsafeMutablePointer<ArcData<T>>) {
    self.arcDataPtr = arcDataPtr
  }

  public init(_ initialValue: consuming T) {
    self.arcDataPtr = .allocate(capacity: 1)
    self.arcDataPtr.initialize(to: ArcData(initialValue))
  }

  deinit {
    if arcDataPtr.pointee.strongCount.subtract(1, ordering: .releasing).oldValue == 1 {
      atomicMemoryFence(ordering: .acquiring)
      arcDataPtr.pointee.value.unsafeDrop()
      _ = Weak(arcDataPtr: arcDataPtr)
    }
  }

  public func deref(_ body: (borrowing T) -> Void) {
    arcDataPtr.pointee.value.withUnsafeMutablePointer { body($0.pointee) }
  }

  public func clone() -> Arc {
    guard arcDataPtr.pointee.strongCount.add(1, ordering: .relaxed).newValue <= maxReferences else {
      fatalError()
    }
    return Arc(arcDataPtr: arcDataPtr)
  }

  public func downgrade() -> Weak<T> {
    var weakCount = arcDataPtr.pointee.weakCount.load(ordering: .relaxed)
    while true {
      if weakCount == locked {
        weakCount = arcDataPtr.pointee.weakCount.load(ordering: .relaxed)
      }

      precondition(weakCount < maxReferences)

      let (exchanged, newWeakCount) = arcDataPtr.pointee.weakCount.weakCompareExchange(
        expected: weakCount, desired: weakCount + 1, ordering: .relaxed)
      if exchanged {
        return Weak(arcDataPtr: arcDataPtr)
      } else {
        weakCount = newWeakCount
      }
    }
  }

  @discardableResult
  public mutating func getMut(_ body: (inout T) -> Void) -> Bool {
    if !arcDataPtr.pointee.weakCount.compareExchange(
      expected: 1, desired: UInt.max, successOrdering: .acquiring, failureOrdering: .relaxed
    ).exchanged {
      return false
    }

    let isUnique = arcDataPtr.pointee.strongCount.load(ordering: .relaxed) == 1
    arcDataPtr.pointee.weakCount.store(1, ordering: .releasing)
    if !isUnique {
      return false
    }

    atomicMemoryFence(ordering: .acquiring)

    arcDataPtr.pointee.value.withUnsafeMutablePointer { body(&$0.pointee) }
    return true
  }
}
