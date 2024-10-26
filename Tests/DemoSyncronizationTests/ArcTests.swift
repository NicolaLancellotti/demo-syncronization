import DemoSyncronization
import Dispatch
import Synchronization
import Testing

struct ArcTests {
  final class DropCounter: @unchecked Sendable {
    private let count = Atomic<Int>(0)

    func increase() {
      count.add(1, ordering: .relaxed)
    }

    func load() -> Int {
      count.load(ordering: .relaxed)
    }
  }

  final class MyClass: Sendable {
    let value: String
    let counter: DropCounter

    init(value: String, counter: DropCounter) {
      self.value = value
      self.counter = counter
    }

    deinit {
      print("Deinit - \(self.value)")
      counter.increase()
    }
  }

  @Test func arcQueue() {
    let counter = DropCounter()
    let concurrentQueue = DispatchQueue(
      label: "concurrentQueue",
      qos: .userInteractive,
      attributes: .concurrent)

    do {
      var strong = Arc(MyClass(value: "1", counter: counter))
      strong.getMut { $0 = MyClass(value: "2", counter: counter) }

      let weak = strong.downgrade()
      concurrentQueue.async {
        let result = weak.upgrade() != nil
        #expect(result)
      }

      concurrentQueue.asyncAndWait(flags: .barrier) {
        weak.upgrade()!.deref {
          #expect($0.value == "2")
        }
      }
    }
    #expect(counter.load() == 2)
  }

  @Test func arcAsync() async {
    actor MyActor {
      var arc: Arc<MyClass>
      let counter: DropCounter

      init(arc: consuming Arc<MyClass>, counter: DropCounter) {
        self.arc = arc
        self.counter = counter
      }

      func mutate() {
        arc.getMut {
          $0 = MyClass(value: "3", counter: counter)
        }
      }
    }

    let counter = DropCounter()
    do {
      var strong = Arc(MyClass(value: "1", counter: counter))
      strong.getMut { $0 = MyClass(value: "2", counter: counter) }

      let actor = MyActor(arc: strong.clone(), counter: counter)
      _ = consume strong
      await actor.mutate()
    }
    #expect(counter.load() == 3)
  }
}
