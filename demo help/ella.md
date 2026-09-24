# Ella: Section 1 (Language and Threading Model) and Section 7 (Pros, Cons, and Limitations)

*ThreadLab · C335 Project 1 · demo prep*

| | |
|---|---|
| **When** | You open the demo with Section 1 and close it with Section 7. |
| **Time** | about 4 min for Section 1, about 3 min for Section 7 |
| **Background** | Sarah Rae and Calli wrote this part. Their notes: [`section1-threading-model.md`](../../docs/section1-threading-model.md) and [`section7-pros-cons-limitations.md`](../../docs/section7-pros-cons-limitations.md). |

> [!IMPORTANT]
> Hit every item in the checklist, then open the files in your editor and walk through the code below. Walking through your own code is how our demo covers Section 6 (Code Walkthrough).

## Section 1 · Language and Threading Model

> [!NOTE]
> **The requirement asks you to cover:**
> - [ ] Which programming language you used
> - [ ] Which operating system your team was assigned
> - [ ] Which threading library, package, or API you used
> - [ ] Whether the threads are operating-system threads, runtime-managed threads, or another model
> - [ ] Important limitations of the language's threading system or the OS's scheduling behavior

### Key points to say

- **Language:** Swift 6, compiled in Swift 6 language mode, so the compiler checks for data races.
- **OS:** macOS (13 or newer). Every team member ran it on an Apple Silicon Mac, M1 through M5.
- **Threading API:** Foundation's `Thread` class. Two helpers: `DispatchGroup` so main can wait, and `NSLock` for locking.
- **Thread model: real OS threads, 1:1.** `Thread` is Apple's NSThread, which is a POSIX thread (pthread), and on macOS each pthread is backed by one Mach kernel thread. The XNU kernel scheduler decides when and on which core each one runs, and can pause it at almost any instruction. That preemption is why the unsync counters go wrong.
- **Why not the other options:** GCD (DispatchQueue) runs your blocks on a pool of threads it picks. Swift Tasks share a small pool and can resume on a different thread after `await`, so a Task is not a thread. Neither lets you name a thread or set one thread's priority, which Part C needed.
- **Limitation 1:** `Thread` has no `join()`, so main waits with a DispatchGroup (Calli covers this).
- **Limitation 2:** macOS can't pin a thread to a core. There's no equivalent of Linux `taskset`, and Apple Silicon ignores thread affinity. Georgia's priority test creates competition by running more busy threads than cores instead.
- **Limitation 3:** Priority (Quality of Service) is only a request to the scheduler. It never guarantees execution order.
- **Limitation 4 (Swift 6):** the compiler blocks sharing a class with changeable state between threads. We had to mark ours `@unchecked Sendable` (see the code below).

### Code to walk through

**[`Package.swift`](../../Package.swift#L1-L24) · lines 1–24**

```swift
/*   1 */ // swift-tools-version: 6.0
/*  11 */ import PackageDescription
/*  12 */ 
/*  13 */ let package = Package(
/*  14 */     name: "ThreadLab",
/*  15 */     platforms: [.macOS(.v13)],
/*  16 */     targets: [
/*  19 */         .executableTarget(
/*  20 */             name: "ThreadLab",
/*  21 */             path: "Sources/ThreadLab"
/*  22 */         )
/*  23 */     ]
/*  24 */ )
```

*(Comments elided for space — the line numbers above are exact.)*

**What to say:**

- Line 1: `swift-tools-version: 6.0` turns on Swift 6 language mode, which is what enforces the data-race checks.
- Line 15: targets macOS 13 or newer, so it builds on every team Mac.
- It's one executable target, ThreadLab, and all the source files share one module.

**[`VendingMachine.swift`](../../Sources/ThreadLab/VendingMachine.swift#L1-L31) · lines 1–31**

```swift
/*   1 */ import Foundation
/*   2 */ 
/*  15 */ /// The shared resource for Sections 3 and 4 of the demo (Part B).
/*  16 */ ///
/*  17 */ /// `@unchecked Sendable`: we're telling the Swift 6 compiler "trust us, we
/*  18 */ /// handle thread safety ourselves" so this instance can be captured by
/*  19 */ /// multiple `Thread` closures. In `unsync` mode we deliberately don't
/*  20 */ /// actually handle it — that's the bug we're demonstrating. Swift 6 can stop us
/*  21 */ /// writing a race by accident, not on purpose.
/*  22 */ final class VendingMachine: @unchecked Sendable {
/*  23 */ 
/*  24 */     // MARK: - Shared state (Section 1 — the three counters everything races on)
/*  25 */     //
/*  29 */     var itemsInStock: Int          // inventory — buyers decrement, restocker increments
/*  30 */     var coinBoxCents: Int          // money in the machine, emptied by the collector
/*  31 */     var cashCollectedCents: Int    // money already banked
```

*(Comments elided for space — the line numbers above are exact.)*

**What to say:**

- Line 20 is the key line. A Thread's closure must be `@Sendable` (safe to share across threads). This class has `var` properties (lines 24 to 31) that several threads change, so Swift 6 refuses to compile if a thread captures it.
- `@unchecked Sendable` tells the compiler "trust us, we handle thread safety ourselves." It adds no locking and changes nothing at runtime; it only turns off the check.
- We use it in **both** modes. Sync mode keeps the promise with NSLock. Unsync mode breaks it on purpose, which is the bug the demo shows.
- ThreadSanitizer still catches the race at runtime even though the compiler was told not to check.

**[`Harness.swift`](../../Sources/ThreadLab/Harness.swift#L20-L27) · lines 20–27**

```swift
/*  20 */ // MARK: - Configuration
/*  21 */ //
/*  22 */ // These live inside a type, not at file scope: in Swift 6 top-level `let`s in
/*  23 */ // main.swift are implicitly @MainActor-isolated, which our Thread closures
/*  24 */ // cannot touch. Keeping them in an enum here sidesteps that entirely and gives
/*  25 */ // every member one place to tune numbers.
/*  26 */ 
/*  27 */ enum Config {
```

**What to say:**

- Another Swift 6 limit: top-level `let`s in main.swift belong to the main actor, and thread closures can't read them.
- So all our settings live in `enum Config` instead, where every thread can read them.

> [!TIP]
> Optional live demo: delete `: @unchecked Sendable` on line 20 of VendingMachine.swift, run `swift build`, show the compiler error, then put it back.

## Section 7 · Pros, Cons, and Limitations

> [!NOTE]
> **The requirement asks you to cover:**
> - [ ] Benefits of using threads
> - [ ] Risks or difficulties introduced by threads
> - [ ] Limitations of your synchronization approach
> - [ ] Limitations of thread priority or scheduling control
> - [ ] One improvement you would make if you had more time

### Key points to say

- **Benefits:** threads let the buyers, restocker and collector do real work at the same time on multiple cores. Because ours are real kernel threads, everything we say about scheduling applies directly to our code. We can name each thread and set its priority individually.
- **Benefits of our lock:** `lock()` plus `defer { unlock() }` is easy to read. One lock covers stock and money together, so they always stay consistent with each other.
- **Risks threads introduce:** shared data can be corrupted (Section 3 showed thousands of items and dollars lost). Bugs are nondeterministic: they change every run and can hide. A missed `group.leave()` would hang main forever.
- **Limits of our synchronization:** one lock for everything means sync-mode threads mostly take turns, so we give up a lot of the benefit of multiple threads. NSLock isn't recursive, so locking twice on one thread deadlocks. It gives mutual exclusion only, not ordering: it doesn't choose which waiting thread goes next. And `@unchecked Sendable` means the compiler won't catch a future edit that skips the lock.
- **Limits of priority control:** QoS is a request, not a guarantee. No core pinning. Results change with the Mac (core count, performance vs. efficiency cores), Low Power Mode, heat and other apps.
- **Also:** threads are heavyweight (each has its own stack and kernel resources), so this design wouldn't scale to thousands of customers.
- **Improvement:** rewrite VendingMachine as a Swift `actor` (sketch below).

### Code to point at

**[`VendingMachine.swift`](../../Sources/ThreadLab/VendingMachine.swift#L2-L142) · lines 2–142**

```swift
/*   2 */ 
/*  74 */     @discardableResult
/* 135 */     func buyOneSafe() -> Bool {
/* 136 */         lock.lock()
/* 137 */         defer { lock.unlock() }            // runs on every exit, including the early return
/* 138 */         guard itemsInStock > 0 else { return false }
/* 139 */         itemsInStock -= 1
/* 140 */         coinBoxCents += itemPriceCents     // both counters updated in one critical section
/* 141 */         return true
/* 142 */     }
```

*(Comments elided for space — the line numbers above are exact.)*

**What to say:**

- The pros in one method: two lines of locking, and `defer` unlocks on every exit, including the early `return false`.
- The con: every Safe method uses this same single lock, so threads line up behind each other.

**The improvement: VendingMachine as an actor (a sketch, not in our code)**

```swift
actor VendingMachine {
    private(set) var itemsInStock: Int
    private(set) var coinBoxCents = 0
    let itemPriceCents = 150

    func buyOne() -> Bool {
        guard itemsInStock > 0 else { return false }
        itemsInStock -= 1
        coinBoxCents += itemPriceCents
        return true
    }
}
// caller:  let sold = await machine.buyOne()
```

**What to say:**

- An actor lets only one caller in at a time, and the compiler enforces it. No lock and no `@unchecked`.
- Cost: callers must `await`, so the workers would become Tasks instead of Threads. We'd lose per-thread names and per-thread QoS, so Part C would need a new design.
- Catch: if an actor method awaited partway through, a check made before the await could be stale afterwards.

### Closing lines

- Three takeaways: races happen because an update is several steps and the kernel can switch threads in between; a lock only fixes that if every access goes through it, reads included; priority is a request that changes how much work a thread gets, not the order.
- Everything is in the GitHub repo, and our AI use is marked in the commits and described in the README.

### If you're asked

<details>
<summary><b>Are Threads OS threads or runtime-managed?</b></summary>

OS threads, 1:1 with Mach kernel threads. A Task is a unit of work on a shared pool and can switch threads after await.

</details>

<details>
<summary><b>What does @unchecked Sendable do?</b></summary>

It declares the class safe to share without the compiler checking. It adds no safety. Sync keeps the promise; unsync breaks it on purpose.

</details>

<details>
<summary><b>Could the program deadlock?</b></summary>

Not as designed: one lock, taken once per method, released by defer, and no Safe method calls another.

</details>

<details>
<summary><b>Why not Mutex or a serial queue?</b></summary>

Mutex needs macOS 15 and we target 13. A serial DispatchQueue would mix GCD into a demo about threads.

</details>


### Say this, not that

| Say this | Not this |
|---|---|
| QoS makes a thread *tend to get more work done* | “Higher priority runs first” |
| sched_yield() *exposes* the race | “sched_yield() causes the bug” |
| We used @unchecked Sendable *in both modes* | “Unsync mode isn’t marked Sendable” |
| NSLock gives *mutual exclusion*, not ordering | “The lock makes threads go in order” |
| Races are *nondeterministic*, so we ran 10 times plus TSan | “It always loses exactly this much” |


---
[← All demo prep files](README.md)