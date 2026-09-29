# Demo Section 1: Language & Threading Model (4 min)

Owner: Member 1 (Sarah Rae & Calli). Presented at rehearsal by Ella.

**One-sentence version:** ThreadLab is written in Swift on macOS and uses Foundation `Thread`, which gives us real kernel threads that we create, name, and configure ourselves. GCD and Swift Concurrency are higher-level models where the system picks the thread for us.

---

## 1. Three ways to run concurrent code in Swift

| | Foundation `Thread` (ours) | Grand Central Dispatch (GCD) | Swift Concurrency (`Task`, `actor`) |
|---|---|---|---|
| Unit of work | A thread | A block submitted to a queue | A task |
| Who creates the OS thread | **We do**, one per `Thread` object | libdispatch, from a thread pool it manages | The Swift runtime, from a small cooperative pool |
| Thread ↔ kernel thread | **1:1** | Many blocks share pool threads | Many tasks share pool threads |
| Can we name it / pick it? | Yes (`thread.name`) | No, a block may run on any pool thread | No, a task can resume on a different thread after `await` |
| Priority control | `qualityOfService`, `threadPriority` | QoS on the queue or block | `TaskPriority` |
| How you wait | No `join()`, so we use `DispatchGroup` | `DispatchGroup`, `queue.sync` | `await` |
| What it's good for | Learning and controlling threads directly | App work you want off the main thread without managing threads | Modern async code; actors prevent data races |

### Foundation `Thread`
- `Thread` is the Swift name for Objective-C's `NSThread`. Under the hood it is a POSIX thread (`pthread`), and on macOS every pthread is backed by a **Mach kernel thread**. That is what "1:1" means: one `Thread` object = one kernel thread.
- The **XNU kernel scheduler** decides when and on which core each thread runs, and it can preempt a thread at almost any instruction. That preemption is why our unsynchronized counters go wrong.
- Each thread gets its own stack and kernel bookkeeping, so threads are relatively expensive. That's fine for our handful of threads but wouldn't scale to thousands.
- Priority: `qualityOfService` is Apple's preferred control. The SDK header (`NSThread.h`) marks `threadPriority` "To be deprecated; use qualityOfService" and says `qualityOfService` is **"read-only after the thread is started"**. That's why we set QoS before `start()` (practice question 15).
- There is no `join()`. Our main thread waits with a `DispatchGroup` (Member 2's section).

### Grand Central Dispatch (GCD)
- You don't create threads. You submit closures to `DispatchQueue`s, and libdispatch runs them on a pool of worker threads it manages.
- The pool can add threads when existing ones block, and many blocking tasks can pile up into "thread explosion."
- We borrow only one GCD piece as a helper, `DispatchGroup`, which acts as a latch so `main` can wait. GCD is not our threading model.

### Swift Concurrency (`async`/`await`, `Task`, `actor`)
- **A `Task` is not a thread.** Tasks run on a cooperative thread pool that has roughly one thread per CPU core. When a task hits `await`, it can suspend and give its thread back, then resume later, possibly on a different thread.
- Because the pool is so small, blocking calls inside tasks (locks held a long time, `sleep`, `DispatchGroup.wait()`, busy loops) can stall the whole pool. That's one reason our blocking, lock-based demo uses `Thread` instead.
- An `actor` lets only one task at a time touch its state, so rewriting `VendingMachine` as an actor would prevent our race by design. See the Section 7 notes.

---

## 2. Swift 6 compile-time race checking and `@unchecked Sendable`

### What `Sendable` means
`Sendable` is Swift's marker for "a value of this type is safe to share across threads." In **Swift 6 language mode**, the compiler enforces it. Our `Package.swift` uses `swift-tools-version: 6.0`, and that turns Swift 6 mode on by default.

### Why a plain `VendingMachine` won't compile
1. `Thread`'s closure initializer takes a **`@Sendable` closure**. In the macOS SDK, `-[NSThread initWithBlock:]` is annotated `NS_SWIFT_SENDABLE`.
2. Anything a `@Sendable` closure captures must itself be `Sendable`.
3. `VendingMachine` is a class with mutable `var` properties (`itemsInStock`, `coinBoxCents`, `cashCollectedCents`). The compiler can't prove that two threads won't write them at the same time, so it won't treat the class as `Sendable`.
4. Result: capturing a plain `VendingMachine` inside `Thread { ... }` is a **compile error** in Swift 6 mode. Swift is catching the data race before the program ever runs.

### What `@unchecked Sendable` does
```swift
final class VendingMachine: @unchecked Sendable { ... }
```
- It declares the class `Sendable` **without the compiler checking it**. We're saying "trust us, we handle thread safety ourselves."
- It adds **no locking and changes nothing at runtime**. It only turns off a compile-time check, and the responsibility moves from the compiler to us.

### Why our demo needs it (in both modes)
- One `VendingMachine` class serves both runs, so both runs need the class to compile when captured by threads.
- **`sync` mode keeps the promise:** every Safe method holds `NSLock`, so the claim is true.
- **`unsync` mode deliberately breaks the promise:** the Unsafe methods read, yield, and write with no lock. The compiler can't warn us because we told it not to check, so the bug shows up at runtime as wrong totals.
- **Thread Sanitizer still catches it at runtime:** `swift run --sanitize=thread ThreadLab unsync` reports the data races, while `sync` runs clean. So `@unchecked` hides the problem from the compiler, not from TSan.
- **Wording to use in the demo:** "We *did* mark it `@unchecked Sendable` in both modes. In unsync mode we just don't live up to that promise." (The brief's phrasing, "in unsync mode we deliberately don't," is about not *doing* the thread safety, not about leaving off the annotation.)

**Live demo idea:** delete `: @unchecked Sendable`, run `swift build`, and show the Sendable error the compiler reports. Then put it back.

---

## 3. What macOS does and doesn't let us control (bridge to Section 5)
- **We can:** create and name kernel threads, request a QoS class before `start()`, and read back the applied QoS with `qos_class_self()`.
- **We can't pin threads to cores.** macOS has no equivalent of Linux's `taskset`. The thread-affinity API is only a hint on Intel and isn't supported on Apple Silicon. To create contention, we run more CPU-bound threads than there are cores.
- **Priority is never an execution-order guarantee.** QoS is a request that the kernel weighs against everything else on the machine.

---

## 4. Practice-question answers for this section

**Q11. Are Foundation `Thread`s OS threads or runtime-managed? How are they different from a Swift `Task`?**
They are OS threads: each `Thread` is a pthread backed by a Mach kernel thread, 1:1, and the kernel schedules it. A `Task` is a unit of work, not a thread. Tasks share a small runtime-managed pool, can suspend at `await` without holding a thread, and may resume on a different thread.

**Q13. What does `@unchecked Sendable` mean, and why did we need it?**
It declares a type safe to share across threads without the compiler verifying it. We needed it because `Thread`'s closure is `@Sendable`, and Swift 6 rejects capturing a class with mutable state in it. It adds no safety itself: `sync` mode makes the claim true with `NSLock`, and `unsync` mode breaks it on purpose to show the race.

---

## Sources to cite
- `NSThread.h` in the macOS SDK (`xcrun --show-sdk-path`, then `System/Library/Frameworks/Foundation.framework/Headers/NSThread.h`): `NS_SWIFT_SENDABLE` on `initWithBlock:`, and the comments on `threadPriority` and `qualityOfService`.
- Apple Developer Documentation: `Thread`, `QualityOfService`, `Sendable`.
- Swift.org, *Swift 6 Migration Guide* (data-race safety, `Sendable`, `@unchecked Sendable`).
- Project brief, Sections 4.1–4.4.
