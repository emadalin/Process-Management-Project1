# Project 1 Team Brief: Threads, Synchronization & Scheduling

> **Our assignment:** Language: **Swift** · Operating system: **macOS**
> **Demo length:** 30 minutes · **Estimated effort:** ~6 hours total
> **Grading focus:** depth of understanding, not just "the code runs"

---

## 1. The Big Picture

We have to build **one program with three clearly labeled demonstrations**:

| Part | What it proves | Minimum requirement |
|---|---|---|
| **A. Thread Creation** | We can create, start, and wait for threads doing real work | **5+ threads**, each with a *distinct* task |
| **B. Unsynchronized vs. Synchronized** | We can cause a real concurrency bug, then fix it | Two modes that produce visibly different results |
| **C. Priority / Scheduling Investigation** | We understand what priority does (and doesn't) guarantee on macOS | **3+ threads**, default vs. modified settings, multiple runs |

**Every one of us must be able to explain every part.** The instructor can ask any team member any question.

---

## 2. Requirements Checklist

### Part A: Thread Creation
- [ ] At least 5 `Thread` objects, each **named** (`thread.name = "OnlineSales"`)
- [ ] Each thread does a **different, meaningful task** (not 5 copies that print a number)
- [ ] Output shows when each thread **starts**, what **work** it does, and when it **finishes**
- [ ] Main thread **waits** for all workers before moving on (Foundation `Thread` has no `join()`, so we use `DispatchGroup`; see Section 5)

### Part B: Unsynchronized vs. Synchronized
- [ ] At least one **shared resource** (a shared class instance holding counters)
- [ ] Unsynchronized mode shows a **real problem**: lost updates, wrong totals, overselling
- [ ] Synchronized mode uses a real mechanism (planned: `NSLock`)
- [ ] Output prints **expected vs. actual** so the difference is obvious
- [ ] We can explain: what goes wrong, *why*, what mechanism we used, how it changes behavior, and whether it enforces **mutual exclusion, ordering, or both**

### Part C: Priority / Scheduling
- [ ] At least 3 threads doing identical CPU-bound work
- [ ] Print default `qualityOfService` and `threadPriority` values
- [ ] Run again with modified QoS (set **before** `start()`)
- [ ] Record results across **at least 5 runs per configuration**
- [ ] Explain what macOS allows, what it doesn't, and why results may not match assigned priorities
- [ ] **Never claim priority guarantees execution order** unless we have documentation *and* evidence

### General Code Quality
- [ ] Multiple types/functions (organized, not one giant `main.swift`)
- [ ] Meaningful names for types, methods, variables, and threads
- [ ] Clear output banners: `=== UNSYNCHRONIZED RUN ===`, `=== SYNCHRONIZED RUN ===`, `=== PRIORITY TEST ===`
- [ ] Builds and runs from Terminal on macOS with `swift run`

---

## 3. Key Concepts Everyone Must Know

| Term | Plain-English meaning |
|---|---|
| **Thread** | An independent path of execution inside one process; threads share the process's memory. |
| **Scheduler** | The part of the OS that decides which thread runs on which CPU core and for how long. On macOS this is the XNU kernel scheduler. |
| **Preemption** | The scheduler can pause a thread at almost any instruction and switch to another. This is the root cause of most race conditions. |
| **Nondeterminism** | Same program, same input, different output on different runs, because thread interleaving changes each time. |
| **Race condition** | The result depends on thread timing. Classic case: two threads do `read → modify → write` on the same variable and one update is lost. |
| **Critical section** | The block of code that touches shared data and must not be run by two threads at once. |
| **Atomic operation** | An operation that can't be interrupted halfway. `count += 1` is **not** atomic (it's read, add, write). |
| **Mutual exclusion** | Only one thread at a time in the critical section. A lock/mutex provides this. |
| **Ordering / coordination** | Forcing threads to run in a specific sequence or wait for a condition. A lock alone does **not** guarantee order. |
| **Deadlock** | Two or more threads wait on each other forever. |
| **Starvation** | A thread never gets the resource/CPU because others keep getting it first. |
| **Thread priority** | A **hint** to the scheduler about importance, not a guarantee of order. |
| **Quality of Service (QoS)** | Apple's way of expressing priority: you describe *what kind of work* a thread does, and macOS decides priority, CPU core type, and throttling. |
| **Sendable** | Swift's compile-time marker for "safe to share across threads." Swift uses it to catch data races before the program runs. |

---

## 4. Our Stack: Swift on macOS

### 4.1 Swift has three concurrency approaches, and we're using Foundation `Thread`

| Approach | What it is | Real OS thread we control? | Priority control | Fit for this project |
|---|---|---|---|---|
| **Foundation `Thread`** | Object wrapper around a POSIX thread (a Mach kernel thread underneath) | **Yes**, 1:1 with a kernel thread | `qualityOfService`, `threadPriority` | **Best fit.** The assignment is about threads; we create, name, and configure each one directly |
| **Grand Central Dispatch (GCD)** | Submit work to `DispatchQueue`s; the system manages a thread pool | No, the system picks the thread | Queue QoS | Useful *helpers* (`DispatchGroup`, `DispatchSemaphore`) but not our main thread model |
| **Swift Concurrency** (`async/await`, `Task`, actors) | Tasks run on a small cooperative thread pool managed by the Swift runtime | No, tasks are not threads | `TaskPriority` | Good to mention in Pros/Cons as the modern alternative (e.g., an `actor` would prevent our race) |

**Demo talking point:** Our threads are OS (kernel) threads created with Foundation's `Thread` class. GCD and Swift Concurrency are higher-level, runtime/system-managed models built on top of OS threads.

### 4.2 Swift/macOS facts we must be able to explain

1. **`Thread` has no `join()` method.** We use a `DispatchGroup`: call `enter()` before starting each thread, `leave()` when the thread finishes, and `wait()` on the main thread. It works like a latch.
2. **If `main` finishes, the whole process exits** and any running threads are killed. That's why the waiting step is required.
3. **Swift 6 tries to stop data races at compile time.** In Swift 6 language mode (the default for packages with `swift-tools-version: 6.0`+), sharing a mutable object across threads is a compile error. To demonstrate a race, our shared class must be marked `@unchecked Sendable`, which tells the compiler "trust us, we handle thread safety." In unsync mode we deliberately *don't*, which is exactly why the bug appears. This is a great point to explain in the demo.
4. **Data races in Swift are undefined behavior.** Racing on an `Int` usually gives wrong numbers. Racing on an `Array` or `Dictionary` can **crash** the program. Use integer counters for the unsync demo.
5. **Thread Sanitizer (TSan)** is built in. Running the unsync mode with `--sanitize=thread` prints a "Data race" report pointing at the exact lines, which is strong evidence for the demo. The sync mode should report nothing.
6. **`print` lines usually stay intact** (they don't garble mid-line), so show the race through wrong *data*, not messy text. The *order* of lines is still nondeterministic.
7. **Debug vs. release builds behave differently.** Compiler optimizations can change how often a race shows up. Test both and note what we see.

### 4.3 Synchronization tools available in Swift on macOS

| Tool | Provides | Notes |
|---|---|---|
| **`NSLock`** | Mutual exclusion | **Our main choice.** Simple and easy to explain. Not recursive: locking twice on the same thread deadlocks. Must unlock on the same thread that locked |
| `NSRecursiveLock` | Mutual exclusion | Same thread may lock multiple times |
| `NSCondition` | Mutual exclusion + condition variable | `wait()` / `signal()` / `broadcast()` |
| **`NSConditionLock`** | Mutual exclusion + **ordering** | Lock "when condition == N": great for forcing threads to take turns |
| `DispatchSemaphore` | Limits concurrent access / handoffs | Counting semaphore; value 1 acts like a lock |
| **`DispatchGroup`** | Coordination (wait for completion) | **Our replacement for `join()`** |
| Serial `DispatchQueue` | Mutual exclusion via queuing | Common Apple idiom (`queue.sync { }`) |
| `OSAllocatedUnfairLock` | Mutual exclusion | Fast low-level lock (macOS 13+) |
| `Mutex` (Synchronization module) | Mutual exclusion | Newest option (macOS 15+) |
| `actor` | Data isolation | Swift Concurrency model; a possible "improvement" talking point |

**Plan:** `NSLock` for mutual exclusion in the synchronized run, `DispatchGroup` for waiting on threads. **Optional bonus:** `NSConditionLock` to show *ordering*, which highlights the difference between the two.

### 4.4 Priority and scheduling on macOS

**How macOS schedules threads:**
- The XNU kernel uses a **preemptive, priority-based** scheduler (priority values 0–127). Normal threads are "timeshare" threads whose effective priority can drop as they use a lot of CPU, so a thread's priority isn't fixed.
- Apple's recommended control is **Quality of Service (QoS)**, not raw priority numbers. QoS classes from highest to lowest: `.userInteractive`, `.userInitiated`, `.default`, `.utility`, `.background`.
- QoS affects more than priority: it can also affect **which CPU cores** a thread may use, plus CPU and I/O throttling.

**Apple Silicon vs. Intel matters a lot here:**
- **Apple Silicon (M-series):** has **performance cores (P)** and **efficiency cores (E)**. `.background` QoS work is kept on the E-cores, so it will likely run slower even when the machine is idle. That's a real, visible effect, but its cause is *core placement and throttling*, not a guaranteed execution order.
- **Intel Macs:** all cores are the same type, so QoS differences may be much smaller or only appear under heavy load.
- **Check which one each laptop is:** `uname -m` → `arm64` (Apple Silicon) or `x86_64` (Intel). Results from different machines aren't directly comparable.

**What Swift's `Thread` lets us control:**

| Property | What it does | Caveat |
|---|---|---|
| `qualityOfService` | Sets the thread's QoS class | Must be set **before** `start()`; Apple's preferred mechanism |
| `threadPriority` | Value from 0.0 to 1.0 (often 0.5 by default) | Apple's docs note the mapping to real kernel priority isn't guaranteed; QoS is the recommended approach |
| `qos_class_self()` | Called *inside* a thread, reports the QoS the system actually applied | Useful for printing "requested vs. actual" |

**What macOS does NOT let us do (worth saying in the demo):**
- **No CPU pinning.** Linux has `taskset` to force threads onto one core; macOS doesn't. The thread affinity API is only a hint on Intel Macs and isn't supported on Apple Silicon.
- **No guaranteed execution order from priority.** QoS is a request; the kernel balances it against everything else on the system.
- Real-time scheduling exists but is meant for audio/media-style workloads, and it isn't needed for this project.

**How to create CPU contention without pinning:** run *more* CPU-bound threads than the machine has cores so they actually compete. Check core counts with:
```bash
sysctl -n hw.ncpu                                          # total cores
sysctl hw.perflevel0.physicalcpu hw.perflevel1.physicalcpu # P-cores / E-cores (Apple Silicon only)
```

**Reduce noise while testing:** plug in the laptop, turn off Low Power Mode, close heavy apps, and let the machine cool between runs.

---

## 5. Suggested Program Design

**Scenario: "Concert Ticket Booth"**, easy to explain and the bug is obvious.

Shared resource: a `TicketBooth` class with `ticketsRemaining` (e.g., starts at 10,000) and `ticketsSold`.

| Thread name | Distinct task |
|---|---|
| `OnlineSales` | Sells tickets one at a time in a loop |
| `BoxOfficeSales` | Sells tickets in small batches |
| `PhoneSales` | Checks "if tickets > 0, sell one" (check-then-act) |
| `RefundProcessor` | Returns a fixed number of tickets to the pool |
| `Auditor` | Periodically reports counts, then prints a final expected-vs-actual report |

- **Unsynchronized run:** totals don't add up (lost sales, lost refunds, possibly overselling).
- **Synchronized run:** same threads, same work, critical sections protected with `NSLock`. Totals always match.
- **Priority test:** 3 "racer" threads do identical CPU-heavy work for a fixed time (e.g., count iterations for 2 seconds). Compare work done with all-default QoS vs. mixed QoS (`.userInteractive` / `.utility` / `.background`). Optionally add extra "load" threads to create contention.

Choose the mode from the command line: `swift run ThreadLab unsync`, `sync`, `priority`, or `all`.

### Code sketches

> These show the *shape* of the APIs. They are not the finished program: adapt, compile, and test them. Exact compiler messages depend on the Swift version and language mode.

**Starting a named thread and waiting for it (our `join()` replacement):**
```swift
import Foundation

func startWorker(_ name: String,
                 group: DispatchGroup,
                 qos: QualityOfService = .default,
                 task: @escaping @Sendable () -> Void) {
    group.enter()                         // count this thread as "in progress"
    let thread = Thread {
        print("▶ [\(name)] started")
        task()
        print("■ [\(name)] finished")
        group.leave()                     // mark this thread done
    }
    thread.name = name
    thread.qualityOfService = qos         // must be set BEFORE start()
    thread.start()
}

// In main: start all workers, then
// group.wait()   // main thread blocks until every worker has called leave()
```

**Shared resource: the race and the fix side by side:**
```swift
final class TicketBooth: @unchecked Sendable {   // "trust us" — we manage thread safety ourselves
    private(set) var ticketsRemaining: Int
    private(set) var ticketsSold = 0
    private let lock = NSLock()

    init(tickets: Int) { ticketsRemaining = tickets }

    // UNSYNCHRONIZED: read, pause, write. Another thread can sneak in during the gap.
    func sellUnsafe() {
        if ticketsRemaining > 0 {
            let current = ticketsRemaining     // READ
            sched_yield()                       // widen the timing window (exposes the bug, doesn't create it)
            ticketsRemaining = current - 1      // WRITE (may overwrite another thread's update)
            ticketsSold += 1                    // also not atomic
        }
    }

    // SYNCHRONIZED: identical logic, but only one thread at a time can be inside.
    func sellSafe() {
        lock.lock()
        defer { lock.unlock() }                 // guarantees unlock even on early return
        guard ticketsRemaining > 0 else { return }
        ticketsRemaining -= 1
        ticketsSold += 1
    }
}
```

**Optional ordering demo with `NSConditionLock`:**
```swift
let turnstile = NSConditionLock(condition: 0)
// Inside the thread whose turn number is `myTurn`:
turnstile.lock(whenCondition: myTurn)          // sleep until it's my turn
print("Stage \(myTurn) running")
turnstile.unlock(withCondition: myTurn + 1)    // hand the turn to the next thread
```

**Priority racer idea:**
```swift
// Inside each racer thread
print("[\(Thread.current.name ?? "?")] QoS=\(Thread.current.qualityOfService.rawValue) priority=\(Thread.current.threadPriority)")
let deadline = Date().addingTimeInterval(2.0)
var iterations = 0
while Date() < deadline { iterations += 1 }
// record `iterations` in a lock-protected results store, print after all racers finish
```

### Tips for a convincing demo
1. **Print expected vs. actual.** Numbers are more convincing than jumbled text.
2. **Run TSan on both modes.** Unsync → race reports; sync → clean. Screenshot or save this output.
3. **Keep prints out of hot loops.** Printing slows threads and can hide races.
4. **Run many times and keep a results table**, for example:

| Run | Config | Racer-A | Racer-B | Racer-C | Notes |
|---|---|---|---|---|---|
| 1 | All `.default` | | | | |
| 1 | `.userInteractive` / `.utility` / `.background` | | | | |

5. **Watch for start-order bias.** The thread started first often gets a head start regardless of QoS, so measure *work done in a fixed time*, not "who printed first."

---

## 6. Build & Run (README starting point)

```bash
# 1. Make sure Swift is installed (Xcode or Command Line Tools)
xcode-select --install     # only if `swift` isn't found
swift --version

# 2. Build and run
swift run ThreadLab all                  # debug build
swift run -c release ThreadLab all       # optimized build
swift run ThreadLab unsync               # just one mode

# 3. Race detection evidence
swift run --sanitize=thread ThreadLab unsync
swift run --sanitize=thread ThreadLab sync

# 4. Save output for submission
swift run ThreadLab unsync | tee output-unsync-run1.txt
```

**Record in the README for every captured run:** macOS version (`sw_vers`), chip (`uname -m`), core counts, Swift version, and debug vs. release.

---

## 7. 30-Minute Demo Plan

| # | Section | Time | Swift/macOS-specific points to hit |
|---|---|---|---|
| 1 | Language & threading model | 4 min | Swift + macOS; Foundation `Thread` = kernel threads; GCD and Swift Concurrency are managed alternatives; Swift 6 compile-time race checking; no CPU pinning on macOS |
| 2 | Thread creation | 4 min | Where `Thread` objects are created and named; `start()`; `DispatchGroup` as our `join()`; why main must wait |
| 3 | Unsynchronized behavior | 5 min | Shared `TicketBooth`; read/yield/write gap; `@unchecked Sendable`; sample output with wrong totals; TSan report |
| 4 | Synchronized behavior | 5 min | `NSLock` + `defer`; mutual exclusion (not ordering); sample output with correct totals; clean TSan run; optional `NSConditionLock` ordering |
| 5 | Priority / scheduling | 5 min | QoS vs. `threadPriority`; set before `start()`; results table across runs; P-core vs. E-core effect (if Apple Silicon); why this isn't guaranteed ordering |
| 6 | Code walkthrough | woven into 2–5 | Focus on thread creation, shared data, critical sections, lock/unlock, QoS settings, waiting |
| 7 | Pros, cons, limitations | 3 min | Threads vs. GCD vs. actors; lock overhead/contention; results vary by Mac hardware; improvement: rewrite `TicketBooth` as an `actor` and compare |
| | Buffer / questions | 4 min | |

---

## 8. Submission Checklist

- [ ] Source code (Swift package: `Package.swift` + `Sources/`)
- [ ] `README.md` with macOS build/run commands, required Swift version, and machine details
- [ ] Sample output, **at least two runs**: one unsynchronized, one synchronized (more is better, plus the priority results table)
- [ ] Team contribution statement: who did what **and** how we made sure everyone understands the whole project
- [ ] If we used AI tools or online examples: note it, and make sure we've reviewed, adapted, and tested the code

---

## 9. Practice Questions (everyone should be able to answer these)

**General**
1. What does each of our threads do?
2. What shared resource is being accessed?
3. What exactly goes wrong without synchronization, and why?
4. Why did we choose `NSLock` over other options?
5. Does our synchronization provide mutual exclusion, ordering, or both?
6. What would happen if we removed the lock?
7. Does thread priority guarantee execution order? Why or why not?
8. What does this specific output demonstrate?
9. What is one limitation of our implementation?
10. Could our program deadlock? Why or why not?

**Swift/macOS-specific**
11. Are Foundation `Thread`s OS threads or runtime-managed? How are they different from a Swift `Task`?
12. Swift `Thread` has no `join()`. How does our main thread wait for workers?
13. What does `@unchecked Sendable` mean, and why did we need it?
14. What is Quality of Service, and how is it different from `threadPriority`?
15. Why must QoS be set before `start()`?
16. Why might a `.background` thread run slower on an M-series Mac even when nothing else is running?
17. Why can't we pin threads to one core on macOS, and how did we create contention instead?
18. What would change if we rewrote `TicketBooth` as an `actor`?

---

## 10. Proposed Work Plan (~6 hours)

| Phase | Time | Output |
|---|---|---|
| Research Swift threading, sync tools, macOS QoS/scheduler | ~1 hr | Notes for Demo Sections 1 and 5 |
| Set up Swift package, agree on design | ~30 min | `ThreadLab` package that builds on everyone's Mac |
| Code Parts A & B | ~1.5 hr | Working unsync + sync modes |
| Code Part C | ~30 min | Priority racer test |
| Test: multiple runs, TSan, debug vs. release, capture outputs | ~1 hr | Saved outputs + results table (note each Mac's chip) |
| README + contribution statement | ~30 min | Submission docs |
| Demo rehearsal | ~1 hr | Everyone practices explaining a section **they didn't write** |

**Roles (fill in):**
- Research & threading-model explanation: `________`
- Thread creation + unsync/sync code: `________`
- Priority/QoS investigation: `________`
- Testing, output capture, README: `________`
