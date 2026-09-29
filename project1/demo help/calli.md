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

**[`main.swift`](../../Sources/ThreadLab/main.swift#L29-L61) · lines 29–61**

```swift
/*  29 */ let arguments = CommandLine.arguments.dropFirst()
/*  30 */ 
/*  31 */ /// Demo switch for the "does group.wait() actually block?" experiment — lets us
/*  32 */ /// show threads being killed when main exits, without editing the source live.
/*  35 */ let skipWait = arguments.contains("--no-wait")
/*  39 */ let mode = arguments.first(where: { !$0.hasPrefix("--") }) ?? "all"
/*  40 */ 
/*  43 */ warnIfWorkerBodiesNotReady(mode: mode)
/*  44 */ 
/*  46 */ switch mode {
/*  47 */ case "unsync":
/*  48 */     runUnsynchronized(skipWait: skipWait)
/*  49 */ case "sync":
/*  50 */     runSynchronized(skipWait: skipWait)
/*  51 */ case "priority":
/*  52 */     runPriorityMode()
/*  53 */ case "all":
/*  55 */     runUnsynchronized(skipWait: skipWait)
/*  56 */     runSynchronized(skipWait: skipWait)
/*  57 */     runPriorityMode()
/*  58 */ default:
/*  59 */     print("usage: ThreadLab [unsync|sync|priority|all] [--no-wait]")
/*  60 */     exit(1)   // non-zero: a mistyped mode is a failure, not a silent no-op
/*  61 */ }
```

*(Comments elided for space — the line numbers above are exact.)*

**What to say:**

- This is the entry point: it reads the mode from the command line and calls the matching run function.
- Line 35: the `--no-wait` flag, used for the "does wait() matter?" experiment.
- main.swift only holds the switch because Swift only allows top-level code in a file named main.swift.

**[`Harness.swift`](../../Sources/ThreadLab/Harness.swift#L73-L99) · lines 73–99**

```swift
/*  73 */ /// Creates, names, prioritizes and starts one worker thread, and registers it
/*  74 */ /// with `group` so the main thread can wait for it. One helper for all five, so
/*  75 */ /// naming, QoS and the enter/leave pairing can't be got wrong per-thread.
/*  76 */ func startWorker(_ name: String,
/*  77 */                  group: DispatchGroup,
/*  78 */                  qos: QualityOfService = .default,
/*  79 */                  task: @escaping @Sendable () -> Void) {
/*  80 */     // enter() must happen BEFORE start(), on THIS thread. If it went inside the
/*  81 */     // closure, main could reach wait() before the thread body ran, see a count
/*  82 */     // of zero, and return immediately — an intermittent bug that would look like
/*  84 */     group.enter()
/*  85 */ 
/*  89 */     let thread = Thread {
/*  90 */         print("[\(name)] started")
/*  91 */         task()
/*  92 */         print("[\(name)] finished")
/*  93 */         group.leave()   // unconditional and last — a missed leave() hangs main forever
/*  94 */     }
/*  95 */ 
/*  96 */     thread.name = name              // Part A requirement; also shows in the debugger
/*  97 */     thread.qualityOfService = qos   // MUST be set before start(); ignored afterwards
/*  98 */     thread.start()
/*  99 */ }
```

*(Comments elided for space — the line numbers above are exact.)*

**What to say:**

- Line 84: `group.enter()` happens **before** the thread starts, on the calling thread. If it were inside the closure, main could reach `wait()` first, see a count of 0, and return early.
- Lines 89 to 94: the thread's body. It prints started, runs its task, prints finished, then calls `group.leave()` last, every time.
- Line 96: every thread gets a name, which Swift's GCD and Tasks can't do.
- Line 97: QoS is set **before** `start()`. Apple's header says it's read-only once the thread is running.
- Line 98: `start()` is where the kernel takes over.

**[`Harness.swift`](../../Sources/ThreadLab/Harness.swift#L108-L137) · lines 108–137**

```swift
/* 108 */ func runVendingDemo(_ safety: Safety, skipWait: Bool) {
/* 109 */     let machine = VendingMachine(startingStock: Config.startingStock)
/* 110 */     let tallies = WorkerTallies()
/* 111 */ 
/* 112 */     // Two latches: the Auditor waits on the first, main waits on both. They must
/* 115 */     let workerGroup = DispatchGroup()
/* 116 */     let auditorGroup = DispatchGroup()
/* 117 */ 
/* 119 */     startWorker("SingleBuyer", group: workerGroup) { runSingleBuyer(machine, safety, tallies) }
/* 120 */     startWorker("ComboBuyer", group: workerGroup) { runComboBuyer(machine, safety, tallies) }
/* 121 */     startWorker("RestockDriver", group: workerGroup) { runRestockDriver(machine, safety, tallies) }
/* 122 */     startWorker("CashCollector", group: workerGroup) { runCashCollector(machine, safety, tallies) }
/* 123 */     startWorker("Auditor", group: auditorGroup) {
/* 124 */         runAuditor(machine, tallies: tallies, waitingOn: workerGroup)
/* 125 */     }
/* 126 */ 
/* 130 */     if skipWait {
/* 131 */         print(">>> --no-wait: main is NOT waiting. Expect missing 'finished' lines.")
/* 132 */         return
/* 133 */     }
/* 134 */ 
/* 135 */     workerGroup.wait()    // until all four workers have left
/* 136 */     auditorGroup.wait()   // then until the Auditor has reported
/* 137 */ }
```

*(Comments elided for space — the line numbers above are exact.)*

**What to say:**

- Lines 109 to 110: one shared VendingMachine and one tally store, captured by every thread.
- Lines 115 to 116: two DispatchGroups. The four workers join `workerGroup`; the Auditor joins `auditorGroup`.
- Lines 119 to 125: the five threads are created here. The Auditor is handed `workerGroup` so it can wait for the workers before its final report.
- Lines 135 to 136: main blocks until every thread has called `leave()`.
- Lines 130 to 133: with `--no-wait`, main returns right away instead.

**[`Workers.swift`](../../Sources/ThreadLab/Workers.swift#L28-L42) · lines 28–42**

```swift
/*  28 */ func runSingleBuyer(_ machine: VendingMachine, _ safety: Safety, _ tallies: WorkerTallies) {
/*  29 */     var itemsBought = 0
/*  30 */     for _ in 0..<Config.buyerIterations {
/*  31 */         if Config.realWorkerBodiesReady {
/*  33 */             let sold = (safety == .unsafe) ? machine.buyOneUnsafe() : machine.buyOneSafe()
/*  34 */             if sold { itemsBought += 1 }   // only count sales the machine granted
/*  35 */         } else {
/*  36 */             sched_yield()
/*  37 */         }
/*  38 */     }
/*  40 */     tallies.publish { $0.singleItemsSold = itemsBought }
/*  41 */     print("[SingleBuyer] sold \(itemsBought) items")
/*  42 */ }
```

*(Comments elided for space — the line numbers above are exact.)*

**What to say:**

- One worker as an example: a loop of 4 million passes. `safety` picks the Unsafe (unsync) or Safe (sync) method. That's the only difference between the two modes.
- Line 29: the tally is a local variable, so only this thread touches it during the run.
- Line 40: it's published once at the end. Prints stay outside the loop because printing would slow threads down and hide the race.

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