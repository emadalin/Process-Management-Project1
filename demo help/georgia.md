# Georgia: Section 5 (Priority or Scheduling Investigation)

*ThreadLab · C335 Project 1 · demo prep*

| | |
|---|---|
| **When** | You follow Stephen's Section 4 and hand off to Ella's Section 7. |
| **Time** | about 5 min |
| **Background** | Sarah Rae and Calli wrote this part. Their notes: [`section5-priority-scheduling.md`](../../docs/section5-priority-scheduling.md). |

> [!IMPORTANT]
> Hit every item in the checklist, then open the files in your editor and walk through the code below. Walking through your own code is how our demo covers Section 6 (Code Walkthrough).

## Section 5 · Priority or Scheduling Investigation

> [!NOTE]
> **The requirement asks you to cover:**
> - [ ] How you checked or changed thread priority or scheduling behavior
> - [ ] What you expected to happen
> - [ ] What actually happened
> - [ ] Whether the result was consistent across multiple runs
> - [ ] What this shows about thread priority in your language, runtime, or OS

### Key points to say

- **How we changed priority:** Quality of Service (QoS), Apple's preferred control, set on each thread **before** `start()`. The older `threadPriority` is marked "to be deprecated" in Apple's header.
- **How we checked it:** inside each thread we read `qos_class_self()`, which reports what the kernel actually applied. It matched the request in every run. `threadPriority` read 0.50 for every racer regardless of QoS, so the two are separate settings.
- **The test:** three identical CPU-bound racers (PickerRobot1, 2, 3) count loop iterations for exactly 2 seconds. We measure **work done in a fixed time**, not who finishes first.
- **Forced competition:** macOS can't pin threads to cores, so we add one busy load thread per core. On an 8-core M2 that's 11 busy threads for 8 cores.
- **Fair start:** a starting gate built on NSCondition holds every thread and releases them together with one shared deadline, so the thread started first gets no head start.
- **Two setups, 5 runs each, alternated** with a 1-second cooldown: all `.default`, vs. `.userInteractive` / `.utility` / `.background`.
- **Expected:** higher QoS gets more CPU time.
- **What happened (Sarah Rae's M2, plugged in, Low Power Mode off, release build):** all default = 98%, 99%, 100% of the top racer, a near tie. Mixed = userInteractive 100%, utility 39%, background 8%.
- **Consistent?** Yes. The order held in all 5 runs: userInteractive 99.9 to 103.4 million, utility 35.5 to 45.8 million, background 7.5 to 11.3 million. With all default, different racers won different runs.
- **Other Mac:** Calli's M3 Pro showed the same order with a bigger gap (12% and 1%), but Low Power Mode was on, so it's a hardware comparison, not the official run.
- **What it shows about macOS:** QoS changes how much CPU time a thread gets, not the order threads run in. On Apple Silicon, .background work is kept on the slower efficiency cores and throttled. Even the background racer still did millions of iterations; it wasn't blocked until the others finished. Priority is a request, not a guarantee.

### Code to walk through (PriorityTest.swift)

**[`PriorityTest.swift`](../../Sources/ThreadLab/PriorityTest.swift#L52-L88) · lines 52–88**

```swift
/*  52 */     static let raceDuration: TimeInterval = 2.0
/*  55 */     static let roundsPerConfig = 5
/*  59 */     static let cooldownBetweenRaces: TimeInterval = 1.0
/*  66 */     static let loadThreadCount = ProcessInfo.processInfo.activeProcessorCount
/*  70 */     struct Config: Sendable {
/*  71 */         let label: String
/*  73 */         let racerQoS: [QualityOfService?]
/*  74 */     }
/*  78 */     static let configs = [
/*  83 */         Config(label: "All `.default`", racerQoS: [nil, nil, nil]),
/*  86 */         Config(label: "`.userInteractive` / `.utility` / `.background`",
/*  87 */                racerQoS: [.userInteractive, .utility, .background]),
/*  88 */     ]
```
*(Comments elided for space — the line numbers above are exact.)*


**What to say:**

- Line 52: each race lasts 2 seconds. Line 55: 5 runs per setup. Line 59: 1-second cooldown between races.
- Line 66: one load thread per core, so busy threads outnumber cores.
- Lines 78 to 88: the two setups. `nil` means QoS is never set, so the thread keeps macOS's default.

**[`PriorityTest.swift`](../../Sources/ThreadLab/PriorityTest.swift#L274-L288) · lines 274–288**

```swift
/* 274 */     private static func startThread(named name: String,
/* 275 */                                     qos: QualityOfService?,
/* 276 */                                     group: DispatchGroup,
/* 277 */                                     body: @escaping @Sendable () -> Void) {
/* 278 */         let thread = Thread {
/* 279 */             body()
/* 280 */             group.leave()
/* 281 */         }
/* 282 */         thread.name = name
/* 283 */         if let qos {
/* 284 */             thread.qualityOfService = qos   // only when requested; nil leaves the inherited value alone
/* 285 */         }
/* 286 */         group.enter()    // before start(), for the same reason as in Harness.swift
/* 287 */         thread.start()
/* 288 */     }
```

**What to say:**

- Line 284: QoS is set **before** `start()` on line 287. Apple's NSThread.h says qualityOfService is read-only once the thread starts.
- Lines 286 and 280: the same DispatchGroup enter/leave pattern as Calli's startWorker, so main can wait for every racer.

**[`PriorityTest.swift`](../../Sources/ThreadLab/PriorityTest.swift#L150-L185) · lines 150–185**

```swift
/* 150 */     final class StartGate: @unchecked Sendable {
/* 151 */         private let condition = NSCondition()
/* 152 */         private var readyCount = 0
/* 153 */         private var deadline: UInt64?   // nil = gate closed; non-nil = open, and this is the finish time
/* 155 */         /// Called by each thread. Blocks until the gate opens, then returns the shared deadline.
/* 156 */         func waitForStart() -> UInt64 {
/* 157 */             condition.lock()
/* 158 */             defer { condition.unlock() }
/* 159 */             readyCount += 1
/* 160 */             condition.broadcast()   // let the main thread see the new ready count
/* 165 */             while true {
/* 166 */                 if let deadline { return deadline }
/* 167 */                 condition.wait()
/* 168 */             }
/* 169 */         }
/* 171 */         /// Called by the main thread. Waits until every thread is at the gate, then opens it.
/* 172 */         func openWhenReady(threadCount: Int, raceDuration: TimeInterval) {
/* 173 */             condition.lock()
/* 174 */             defer { condition.unlock() }
/* 175 */             while readyCount < threadCount {
/* 176 */                 condition.wait()
/* 177 */             }
/* 182 */             deadline = DispatchTime.now().uptimeNanoseconds + UInt64(raceDuration * 1_000_000_000)
/* 183 */             condition.broadcast()   // wake every waiting thread at once, not one at a time
/* 184 */         }
/* 185 */     }
```
*(Comments elided for space — the line numbers above are exact.)*


**What to say:**

- The starting gate. Each thread calls `waitForStart()` and blocks on the condition (line 167) until the gate opens.
- Main calls `openWhenReady()`: it waits until every thread is at the gate (lines 174 to 177), sets one shared deadline (line 182), and wakes everyone at once (line 183).
- This removes start-order bias: no thread gets a head start just because it was started first.

**[`PriorityTest.swift`](../../Sources/ThreadLab/PriorityTest.swift#L219-L265) · lines 219–265**

```swift
/* 219 */     private static func race(_ config: Config) -> [RacerReport] {
/* 220 */         let group = DispatchGroup()   // same latch pattern as Part A's harness
/* 221 */         let gate = StartGate()
/* 222 */         let store = ResultsStore()
/* 223 */ 
/* 224 */         for (index, qos) in config.racerQoS.enumerated() {
/* 225 */             startThread(named: "PickerRobot\(index + 1)", qos: qos, group: group) {
/* 229 */                 let current = Thread.current
/* 230 */                 let reportedQoS = current.qualityOfService
/* 231 */                 let priority = current.threadPriority
/* 235 */                 let applied = qosClassName(qos_class_self())
/* 239 */                 let deadline = gate.waitForStart()
/* 240 */                 let iterations = countIterations(until: deadline)
/* 241 */ 
/* 242 */                 store.record(RacerReport(name: current.name ?? "?",
/* 243 */                                          requestedQoS: qos,
/* 244 */                                          reportedQoS: reportedQoS,
/* 245 */                                          threadPriority: priority,
/* 246 */                                          appliedQoSClass: applied,
/* 247 */                                          iterations: iterations))
/* 248 */             }
/* 249 */         }
/* 254 */         for index in 1...loadThreadCount {
/* 255 */             startThread(named: "LoadThread\(index)", qos: nil, group: group) {
/* 256 */                 _ = countIterations(until: gate.waitForStart())
/* 257 */             }
/* 258 */         }
/* 262 */         gate.openWhenReady(threadCount: config.racerQoS.count + loadThreadCount, raceDuration: raceDuration)
/* 263 */         group.wait()
/* 264 */         return store.sortedReports()
/* 265 */     }
```
*(Comments elided for space — the line numbers above are exact.)*


**What to say:**

- One race: start the 3 racers (lines 224 to 249), then the load threads (lines 254 to 258), open the gate (line 262), wait for all (line 263).
- Lines 229 to 235: inside each racer we read the QoS it reports and `qos_class_self()`, what the kernel actually applied.
- Results go into a lock-protected store and are printed only after every thread finishes, so printing can't skew the race.

**[`PriorityTest.swift`](../../Sources/ThreadLab/PriorityTest.swift#L298-L304) · lines 298–304**

```swift
/* 298 */     private static func countIterations(until deadline: UInt64) -> Int {
/* 299 */         var iterations = 0
/* 300 */         while DispatchTime.now().uptimeNanoseconds < deadline {
/* 301 */             iterations += 1
/* 302 */         }
/* 303 */         return iterations
/* 304 */     }
```

**What to say:**

- The identical work: count iterations until the deadline. No printing, locking or sleeping inside, so the only difference between racers is how much CPU time the scheduler gives them.

### Output to show

**output-priority-run2.txt (Apple M2, release): run 1 of each setup**

```text
Machine: Apple M2 (arm64), macOS Version 15.7.4 (Build 24G517)
Cores: 8 logical = 4 performance + 4 efficiency
Build: release · Low Power Mode: off · Thermal state: nominal

[Run 1] All `.default`
  PickerRobot1  requested: not set  ...  qos_class_self(): DEFAULT   iterations: 86,009,143
  PickerRobot2  requested: not set  ...  qos_class_self(): DEFAULT   iterations: 85,525,152
  PickerRobot3  requested: not set  ...  qos_class_self(): DEFAULT   iterations: 86,179,471

[Run 1] `.userInteractive` / `.utility` / `.background`
  PickerRobot1  requested: .userInteractive  ...  USER_INTERACTIVE  iterations: 102,171,518
  PickerRobot2  requested: .utility          ...  UTILITY           iterations: 42,497,988
  PickerRobot3  requested: .background       ...  BACKGROUND        iterations: 7,546,914
```

**What it shows:**

- The banner records the machine, build, Low Power Mode and heat, because all of them change the numbers. That's how we caught Low Power Mode on Calli's run.
- Requested QoS = applied QoS (`qos_class_self()`) in every row. (Output lines shortened here.)

| Averages over 5 runs (Apple M2) | PickerRobot1 | PickerRobot2 | PickerRobot3 |
|---|---|---|---|
| All .default | 86,878,830 (98%) | 87,751,922 (99%) | 88,329,425 (100%) |
| userInteractive / utility / background | 101,635,936 (100%) | 40,375,553 (39%) | 8,994,427 (8%) |

> [!TIP]
> Live (optional, about 30 seconds: 10 races plus cooldowns): `swift run -c release ThreadLab priority`. Plug in, turn Low Power Mode off, close heavy apps first.

### If you're asked

<details>
<summary><b>Does priority guarantee execution order?</b></summary>

No. Say "tends to get more work done," never "runs first." The kernel still preempts high-QoS threads, and low-QoS threads still progress.

</details>

<details>
<summary><b>Why is .background slow even with nothing else running?</b></summary>

macOS keeps it on the efficiency cores and throttles it. It's slower hardware, not waiting in line.

</details>

<details>
<summary><b>Why no core pinning?</b></summary>

macOS has nothing like taskset; affinity is only a hint on Intel and unsupported on Apple Silicon. So we used more busy threads than cores.

</details>

<details>
<summary><b>QoS vs. threadPriority?</b></summary>

QoS says what kind of work it is and affects CPU time, core type and throttling. threadPriority is a 0 to 1 number being deprecated; ours read 0.50 for every QoS.

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