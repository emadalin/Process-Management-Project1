# Calli: Section 2 (Thread Creation)

*ThreadLab · C335 Project 1 · demo prep*

| | |
|---|---|
| **When** | You follow Ella's Section 1 and hand off to Sarah Rae's Section 3. |
| **Time** | about 4 to 5 min |
| **Background** | Stephen wrote this part. His notes: [`section2-thread-creation-harness.md`](../../docs/section2-thread-creation-harness.md). |

> [!IMPORTANT]
> Hit every item in the checklist, then open the files in your editor and walk through the code below. Walking through your own code is how our demo covers Section 6 (Code Walkthrough).

## Section 2 · Thread Creation

> [!NOTE]
> **The requirement asks you to cover:**
> - [ ] Where each thread is created
> - [ ] What task each thread performs
> - [ ] How the program starts and stops each thread

### Key points to say

- **Where:** every thread is created by one function, `startWorker()` in Harness.swift. `runVendingDemo()` calls it five times, once per named thread. (Georgia's priority test makes its own threads the same way in PriorityTest.swift.)
- **The five threads and their tasks:**

| Thread | Task | Loop passes |
|---|---|---|
| SingleBuyer | If stock > 0, take 1 item and add 150 cents to the coin box | 4,000,000 |
| ComboBuyer | If stock ≥ 3, take 3 items and add 450 cents | 4,000,000 |
| RestockDriver | If stock < 500, load a tray of 50 | 4,000,000 |
| CashCollector | Move the coin box into collected cash, reset the box to 0 | 200 |
| Auditor | Snapshots every 0.25 s while the others run, then checks expected vs. actual totals | until the others finish |

- Each worker counts what it did in a **private local variable** and publishes it once at the end. No other thread touches it, so the Auditor can trust it as the expected total.
- **Start:** `thread.start()` hands the thread to the kernel. All five run at the same time.
- **Stop:** a thread ends when its closure returns. Nothing kills it early.
- **Waiting (no join):** Foundation Thread has no `join()`. A DispatchGroup works like a counter instead: `enter()` adds 1, `leave()` subtracts 1, and `wait()` blocks until it's 0.
- **Proof the wait matters:** with the `--no-wait` flag, main skips the wait, the process exits, and no thread ever prints "finished".

### Code to walk through

**[`main.swift`](../../Sources/ThreadLab/main.swift#L20-L43) · lines 20–43**

```swift
/*  20 */ let arguments = CommandLine.arguments.dropFirst()
/*  21 */ 
/*  22 */ /// Demo switch for the "does group.wait() actually block?" experiment — lets us
/*  23 */ /// show threads being killed when main exits, without editing the source live.
/*  24 */ let skipWait = arguments.contains("--no-wait")
/*  25 */ let mode = arguments.first(where: { !$0.hasPrefix("--") }) ?? "all"
/*  26 */ 
/*  27 */ warnIfWorkerBodiesNotReady(mode: mode)
/*  28 */ 
/*  29 */ switch mode {
/*  30 */ case "unsync":
/*  31 */     runUnsynchronized(skipWait: skipWait)
/*  32 */ case "sync":
/*  33 */     runSynchronized(skipWait: skipWait)
/*  34 */ case "priority":
/*  35 */     runPriorityMode()
/*  36 */ case "all":
/*  37 */     runUnsynchronized(skipWait: skipWait)
/*  38 */     runSynchronized(skipWait: skipWait)
/*  39 */     runPriorityMode()
/*  40 */ default:
/*  41 */     print("usage: ThreadLab [unsync|sync|priority|all] [--no-wait]")
/*  42 */     exit(1)
/*  43 */ }
```

**What to say:**

- This is the entry point: it reads the mode from the command line and calls the matching run function.
- Line 24: the `--no-wait` flag, used for the "does wait() matter?" experiment.
- main.swift only holds the switch because Swift only allows top-level code in a file named main.swift.

**[`Harness.swift`](../../Sources/ThreadLab/Harness.swift#L66-L87) · lines 66–87**

```swift
/*  66 */ /// Creates, names, prioritizes and starts one worker thread, and registers it
/*  67 */ /// with `group` so the main thread can wait for it.
/*  68 */ func startWorker(_ name: String,
/*  69 */                  group: DispatchGroup,
/*  70 */                  qos: QualityOfService = .default,
/*  71 */                  task: @escaping @Sendable () -> Void) {
/*  72 */     // enter() must happen BEFORE start(), on THIS thread. If it went inside the
/*  73 */     // closure, main could reach wait() before the thread body ran, see a count
/*  74 */     // of zero, and return immediately.
/*  75 */     group.enter()
/*  76 */ 
/*  77 */     let thread = Thread {
/*  78 */         print("[\(name)] started")
/*  79 */         task()
/*  80 */         print("[\(name)] finished")
/*  81 */         group.leave()   // unconditional and last — a missed leave() hangs main forever
/*  82 */     }
/*  83 */ 
/*  84 */     thread.name = name
/*  85 */     thread.qualityOfService = qos   // MUST be set before start(); ignored afterwards
/*  86 */     thread.start()
/*  87 */ }
```

**What to say:**

- Line 75: `group.enter()` happens **before** the thread starts, on the calling thread. If it were inside the closure, main could reach `wait()` first, see a count of 0, and return early.
- Lines 77 to 82: the thread's body. It prints started, runs its task, prints finished, then calls `group.leave()` last, every time.
- Line 84: every thread gets a name, which Swift's GCD and Tasks can't do.
- Line 85: QoS is set **before** `start()`. Apple's header says it's read-only once the thread is running.
- Line 86: `start()` is where the kernel takes over.

**[`Harness.swift`](../../Sources/ThreadLab/Harness.swift#L98-L121) · lines 98–121**

```swift
/*  98 */ func runVendingDemo(_ safety: Safety, skipWait: Bool) {
/*  99 */     let machine = VendingMachine(startingStock: Config.startingStock)
/* 100 */     let tallies = WorkerTallies()
/* 101 */ 
/* 102 */     // Two latches: the Auditor waits on the first, main waits on both.
/* 103 */     let workerGroup = DispatchGroup()
/* 104 */     let auditorGroup = DispatchGroup()
/* 105 */ 
/* 106 */     startWorker("SingleBuyer", group: workerGroup) { runSingleBuyer(machine, safety, tallies) }
/* 107 */     startWorker("ComboBuyer", group: workerGroup) { runComboBuyer(machine, safety, tallies) }
/* 108 */     startWorker("RestockDriver", group: workerGroup) { runRestockDriver(machine, safety, tallies) }
/* 109 */     startWorker("CashCollector", group: workerGroup) { runCashCollector(machine, safety, tallies) }
/* 110 */     startWorker("Auditor", group: auditorGroup) {
/* 111 */         runAuditor(machine, tallies: tallies, waitingOn: workerGroup)
/* 112 */     }
/* 113 */ 
/* 114 */     if skipWait {
/* 115 */         print(">>> --no-wait: main is NOT waiting. Expect missing 'finished' lines.")
/* 116 */         return
/* 117 */     }
/* 118 */ 
/* 119 */     workerGroup.wait()
/* 120 */     auditorGroup.wait()
/* 121 */ }
```

**What to say:**

- Lines 99 to 100: one shared VendingMachine and one tally store, captured by every thread.
- Lines 103 to 104: two DispatchGroups. The four workers join `workerGroup`; the Auditor joins `auditorGroup`.
- Lines 106 to 112: the five threads are created here. The Auditor is handed `workerGroup` so it can wait for the workers before its final report.
- Lines 119 to 120: main blocks until every thread has called `leave()`.
- Lines 114 to 117: with `--no-wait`, main returns right away instead.

**[`Workers.swift`](../../Sources/ThreadLab/Workers.swift#L16-L28) · lines 16–28**

```swift
/*  16 */ func runSingleBuyer(_ machine: VendingMachine, _ safety: Safety, _ tallies: WorkerTallies) {
/*  17 */     var itemsBought = 0
/*  18 */     for _ in 0..<Config.buyerIterations {
/*  19 */         if Config.realWorkerBodiesReady {
/*  20 */             let sold = (safety == .unsafe) ? machine.buyOneUnsafe() : machine.buyOneSafe()
/*  21 */             if sold { itemsBought += 1 }
/*  22 */         } else {
/*  23 */             sched_yield()
/*  24 */         }
/*  25 */     }
/*  26 */     tallies.publish { $0.singleItemsSold = itemsBought }
/*  27 */     print("[SingleBuyer] sold \(itemsBought) items")
/*  28 */ }
```

**What to say:**

- One worker as an example: a loop of 4 million passes. `safety` picks the Unsafe (unsync) or Safe (sync) method. That's the only difference between the two modes.
- Line 17: the tally is a local variable, so only this thread touches it during the run.
- Line 26: it's published once at the end. Prints stay outside the loop because printing would slow threads down and hide the race.

### Output to show

**Sample from output-sync-run1.txt: every thread prints when it starts and finishes**

```text
=== SYNCHRONIZED RUN ===
[SingleBuyer] started
[ComboBuyer] started
[RestockDriver] started
[Auditor] started
[CashCollector] started
[CashCollector] emptied the coin box 200 times
[CashCollector] finished
...
[SingleBuyer] finished
[ComboBuyer] finished
[RestockDriver] finished
[Auditor] all workers done — final report
[Auditor] finished
```

**What it shows:**

- The start order and finish order change every run: the kernel decides, not our code.
- The Auditor always finishes last, because it waits on the workers' group.

**output-nowait-run1.txt: the same run with --no-wait**

```text
=== UNSYNCHRONIZED RUN ===
>>> --no-wait: main is NOT waiting. Expect missing 'finished' lines.
=== UNSYNCHRONIZED RUN COMPLETE ===
```

**What it shows:**

- Main didn't wait, so the process ended and took the threads with it. No "finished" lines at all.
- Live: `swift run ThreadLab unsync --no-wait`

### If you're asked

<details>
<summary><b>Why does enter() go outside the thread?</b></summary>

So the count is already up before main reaches wait(). Inside the thread, main might see 0 and return early.

</details>

<details>
<summary><b>Why two DispatchGroups?</b></summary>

The Auditor has to wait on the workers to know when to report; main waits on everyone, including the Auditor.

</details>

<details>
<summary><b>What if a thread forgot leave()?</b></summary>

The count never reaches 0 and main waits forever. That's a hang, not a lock deadlock.

</details>

<details>
<summary><b>Are these OS threads?</b></summary>

Yes, each Thread is one kernel thread (1:1).

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