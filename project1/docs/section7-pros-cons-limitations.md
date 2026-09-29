# Demo Section 7: Pros, Cons & Limitations (3 min)

Owner: Member 1 (Sarah Rae & Calli). Presented at rehearsal by Ella.

**One-sentence version:** Foundation threads plus `NSLock` gave us direct, explainable control and correct totals, at the cost of lock contention, manual discipline the compiler can't check, and results that depend on the Mac they run on.

---

## 1. Pros of our approach (`Thread` + `NSLock` + `DispatchGroup`)
- **Direct mapping to OS concepts.** Each `Thread` is a real kernel thread that we name, configure, and start, so what we say about scheduling and preemption applies to exactly the code on screen.
- **Per-thread control.** We can set `qualityOfService` on each thread individually, which Part C needs. With GCD or `Task` the system chooses the thread.
- **`NSLock` is simple to read and explain.** `lock.lock()` + `defer { lock.unlock() }` makes the critical section obvious, and `defer` unlocks even on an early `return`.
- **One lock for all three counters keeps the invariants consistent.** Stock and money change together inside the same critical section, so the Auditor never sees items gone with no coins added.
- **Easy before/after comparison.** The Safe and Unsafe methods share the same logic, so the only difference between the two runs is the lock.

## 2. Cons
- **Lock overhead and contention.** Every buy, restock, and collection has to take the same lock, so threads line up and wait for each other. During those stretches, four worker threads effectively do one thread's work at a time. The synchronized run is expected to be slower than the unsynchronized one. *(Measure it: time both runs on the same Mac and quote the numbers, rather than claiming a figure.)*
- **Coarse locking is a trade-off.** A separate lock per counter would allow more parallelism, but it could break the invariants between counters and brings a deadlock risk if two threads take locks in different orders.
- **`NSLock` is not recursive.** If a Safe method ever called another Safe method (for example, `buyOneSafe()` calling `restockSafe()`), the thread would try to lock twice and **deadlock itself**. It also must be unlocked on the same thread that locked it.
- **Mutual exclusion only: no ordering or fairness.** `NSLock` doesn't promise which waiting thread goes next. In principle one worker could keep losing (starvation), and forcing a turn order would need something like `NSConditionLock`.
- **`@unchecked Sendable` switches off the compiler's safety net.** If a future edit touched `itemsInStock` without the lock, it would still compile. Only a TSan run or wrong totals would reveal it.
- **Threads are heavyweight.** Each one has its own stack and kernel resources. Our small fixed number of workers is fine, but modeling thousands of customers as threads wouldn't scale.
- **Manual waiting.** `Thread` has no `join()`, so we hand-pair `group.enter()` / `group.leave()`. A missed `leave()` means `group.wait()` blocks forever.

## 3. Limitations of our results
- **Races are nondeterministic.** An unsynchronized run can occasionally come out correct, and the size of the drift changes every run. That's why we show several runs plus TSan, not a single screenshot.
- **`sched_yield()` makes the race easier to see.** It widens a gap that already exists but doesn't create the bug. Without it, the race still exists but shows up less often.
- **Debug vs. release builds differ.** Optimizations change timing and how often the race appears (see Section 4 testing notes).
- **Results vary by Mac hardware.** Core count, Apple Silicon P-cores vs. E-cores, Intel vs. ARM, thermals, battery vs. plugged in, and background apps all change the numbers. Priority results from different machines aren't directly comparable (see `docs/machine-details.md`).
- **QoS is a request, not a guarantee, and there's no CPU pinning.** Part C shows tendencies over at least 5 runs, not a fixed execution order.

---

## 4. Improvement: rewrite `VendingMachine` as an `actor`

```swift
actor VendingMachine {
    private(set) var itemsInStock: Int
    private(set) var coinBoxCents = 0
    private(set) var cashCollectedCents = 0
    let itemPriceCents: Int

    init(startingStock: Int = 10_000, itemPriceCents: Int = 150) {
        itemsInStock = startingStock
        self.itemPriceCents = itemPriceCents
    }

    func buyOne() -> Bool {
        guard itemsInStock > 0 else { return false }
        itemsInStock -= 1
        coinBoxCents += itemPriceCents
        return true
    }
}

// Callers must now await, from inside a Task:
// let sold = await machine.buyOne()
```

**What would change (practice question 18):**
- **No lock and no `@unchecked`.** An actor lets only one caller at a time run its methods, and actors are `Sendable` automatically.
- **The compiler enforces it.** Code outside the actor can't touch `itemsInStock` directly; it must `await` a method. That means the unsafe version couldn't even be written without deliberately working around the compiler, so the unsynchronized demo would no longer be possible as-is.
- **Callers become `async`.** Workers would become `Task`s instead of `Thread`s, so we'd lose per-thread naming and per-thread QoS control (tasks use `TaskPriority` on a shared pool). Part C would need a different design.
- **Reentrancy caveat.** If an actor method `await`s partway through, other calls can run during that suspension, so a check made before the `await` may be stale afterwards. Our methods have no `await` inside, so this doesn't apply today, but it's the actor version of our check-then-act bug.
- **No ordering promise.** An actor gives mutual exclusion, not a guaranteed order of callers. That's the same answer as for `NSLock`.

## 5. Other alternatives worth naming
| Alternative | Why we didn't pick it |
|---|---|
| `Mutex` (Synchronization module) | Needs macOS 15+; our package targets macOS 13 so it builds on every team Mac |
| `OSAllocatedUnfairLock` | Faster, but lower-level and less familiar to explain than `NSLock` |
| Serial `DispatchQueue` (`queue.sync { }`) | Works, but mixes GCD into a demo that's about threads |
| `NSConditionLock` | Adds ordering; considered as an optional bonus to contrast with plain mutual exclusion, but not implemented |

---

## Practice-question answers for this section

**Q9. What is one limitation of our implementation?**
One lock guards everything, so the synchronized workers mostly take turns. We get correctness but lose most of the benefit of having multiple threads. Also, `@unchecked Sendable` means the compiler can't catch a future edit that skips the lock.

**Q10. Could our program deadlock?**
Not as designed. There is only one lock, every Safe method takes it once and releases it with `defer`, and no Safe method calls another Safe method while holding it. It *would* deadlock if a Safe method called another Safe method, because `NSLock` isn't recursive, or if a thread forgot `group.leave()` and `main` waited forever. *(Member 4 confirms this against the final code.)*
