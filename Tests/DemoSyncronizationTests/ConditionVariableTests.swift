import DemoSyncronization
import Dispatch
import Synchronization
import Testing

struct ConditionVariableTests {
  @Test func conditionVariable() {
    let concurrentQueue = DispatchQueue(
      label: "concurrentQueue",
      qos: .userInteractive,
      attributes: .concurrent)

    let lock = Mutex1(Structure(value: 0))
    let conditionVariable = ConditionVariable()
    var wakeups = 0

    concurrentQueue.async {
      sleep(1)
      lock.withLock {
        $0.value = 1
      }
      conditionVariable.notifyOne()
    }

    lock.withHandler { handler in
      while handler.withValue({ $0.value == 0 }) {
        conditionVariable.wait(handler)
        wakeups += 1
      }
      let x = handler.withValue { $0.value }
      #expect(x == 1)
      #expect(wakeups < 10)
    }
  }
}
