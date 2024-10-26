struct UnsafeCellHeap<Value: ~Copyable>: ~Copyable {
  private var value = UnsafeMutablePointer<Value>.allocate(capacity: 1)

  init(_ initialValue: consuming Value) {
    value.initialize(to: initialValue)
  }

  func withUnsafeMutablePointer<Result: ~Copyable, E>(
    _ body: (UnsafeMutablePointer<Value>) throws(E) -> Result
  )
    throws(E) -> Result
  {
    return try body(value)
  }

  func unsafeDrop() {
    value.deinitialize(count: 1)
    value.deallocate()
  }
}

struct UnsafeCellUndefinedBehavior<Value: ~Copyable>: ~Copyable {
  private var value: Value?

  init(_ initialValue: consuming Value) {
    self.value = consume initialValue
  }

  func withUnsafeMutablePointer<Result: ~Copyable, E>(
    _ body: (UnsafeMutablePointer<Value>) throws(E) -> Result
  )
    throws(E) -> Result
  {
    return try withUnsafePointer(to: value!) { (pointer) throws(E) -> Result in
      try body(UnsafeMutablePointer(mutating: pointer))
    }
  }

  func unsafeDrop() {
    withUnsafePointer(to: self.value) {
      UnsafeMutablePointer(mutating: $0).pointee = nil
    }
  }
}
