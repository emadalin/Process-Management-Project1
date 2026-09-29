# Demo Section 2: Thread Creation Harness (Part A) (4 min)

Owner: Member 2 (Stephen). Presented at rehearsal by Calli (Members 1/5 split Sections 2 and 3 between them — Calli takes this one, Sarah Rae takes Section 3).

**One-sentence version:** `startWorker(_:group:qos:task:)` is the one place we create, name, QoS-configure, and start every worker `Thread`, and a `DispatchGroup` stands in for the `join()` that Foundation's `Thread` doesn't have.

---

## 1. Why this file exists at all (`Sources/ThreadLab/main.swift`)

Top-level statements — code not inside a function, type, or closure — are only legal in a file literally named `main.swift`. Every other file in an executable target may hold only declarations (functions, types, enums). That's a Swift build-system rule, not a style choice, and it's the entire reason the module is split the way it is:

```
Harness.swift       Member 2   Config, Safety, startWorker, the run functions
Workers.swift       Member 3   the four worker thread bodies
Auditor.swift       Member 4   the Auditor thread and the invariant report
PriorityTest.swift  Member 5   the PickerRobot racers
Tallies.swift        shared    the tally store the Auditor reads
VendingMachine.swift M3 + M4   the shared resource
```

`main.swift` itself ([main.swift](../Sources/ThreadLab/main.swift)) is 44 lines and does nothing but parse `CommandLine.arguments` and switch on the mode:

```swift
let mode = arguments.first(where: { !$0.hasPrefix("--") }) ?? "all"
switch mode {
case "unsync":   runUnsynchronized(skipWait: skipWait)
case "sync":     runSynchronized(skipWait: skipWait)
case "priority": runPriorityMode()
case "all":      runUnsynchronized(...); runSynchronized(...); runPriorityMode()
default:         print("usage: ..."); exit(1)
}
```
Everything it calls — `runUnsynchronized`, `runSynchronized`, `runPriorityMode` — lives in [Harness.swift](../Sources/ThreadLab/Harness.swift), which is a normal file full of declarations. All these files are one module (`ThreadLab`), so none of them need to `import` each other.

---

## 2. `startWorker` — the one place every thread gets created ([Harness.swift:68-87](../Sources/ThreadLab/Harness.swift#L68-L87))

```swift
func startWorker(_ name: String,
                 group: DispatchGroup,
                 qos: QualityOfService = .default,
                 task: @escaping @Sendable () -> Void) {
    group.enter()                       // BEFORE start(), on THIS thread

    let thread = Thread {
        print("[\(name)] started")
        task()
        print("[\(name)] finished")
        group.leave()                   // unconditional and last
    }

    thread.name = name
    thread.qualityOfService = qos       // MUST be set before start(); ignored afterwards
    thread.start()
}
```

Four things happen here, in order, and the order matters for three of them:
1. **`group.enter()` before `start()`, on the caller's thread.** If `enter()` moved inside the closure, `main` could race ahead to `group.wait()` before the new thread has even run far enough to call `enter()`, see a count of zero, and return immediately — main would stop waiting for a thread that hasn't started yet.
2. **`thread.name = name`.** Every worker gets a real name (`SingleBuyer`, `ComboBuyer`, ...), which is what makes `[SingleBuyer] started` / `[SingleBuyer] finished` possible instead of an anonymous thread number.
3. **`thread.qualityOfService = qos` before `thread.start()`.** The macOS SDK marks `qualityOfService` read-only once a thread is running — set it after `start()` and it's silently ignored. (Member 5's Section 5 covers this in depth for Part C; here it just means every `startWorker` call takes QoS as a parameter set before the one and only `start()` call.)
4. **`group.leave()` is unconditional and last**, right after the "finished" print, whether `task()` did anything interesting or not. A worker that returns early or throws past this line would leave the group short one `leave()` — and `group.wait()` would then block forever, since `DispatchGroup` has no timeout by default here.

**This one function is every named thread in the demo.** `runVendingDemo` ([Harness.swift:98-121](../Sources/ThreadLab/Harness.swift#L98-L121)) calls it five times — once each for `SingleBuyer`, `ComboBuyer`, `RestockDriver`, `CashCollector`, and `Auditor` — passing each one a closure into Member 3's or Member 4's worker-body functions. `PriorityTest.swift` (Member 5) does **not** use `startWorker`: the racers need to test the "QoS never set at all" case, which `startWorker`'s default parameter can't express cleanly for that specific comparison, so Part C creates its threads directly. Good line to have ready if asked "why doesn't Part C reuse this?"

---

## 3. `DispatchGroup` as our `join()` (practice question 12)

Foundation's `Thread` has no `join()` — there's no built-in way to block until a specific thread finishes. `DispatchGroup` fills that gap as a latch:
- `group.enter()` increments an internal counter.
- `group.leave()` decrements it.
- `group.wait()` blocks the calling thread until the counter hits zero.

Every `startWorker` call does one `enter()`/`leave()` pair, so after five calls the counter is 5, and `workerGroup.wait()` on the main thread ([Harness.swift:119](../Sources/ThreadLab/Harness.swift#L119)) blocks until all five have called `leave()`. Two groups are actually in play: `workerGroup` (the four buyers/restocker/collector) and `auditorGroup` (just the Auditor) — the Auditor itself waits on `workerGroup` from inside its own thread (that's how it takes snapshots *during* the run — see Member 4's Section 4), and `main` waits on both.

**Why main must wait at all:** if `main` reaches the end of the program and returns, the whole process exits — any threads still running get killed mid-work, with no cleanup and no guarantee their `print`s even flushed. `group.wait()` is what keeps `main` alive until every worker has genuinely finished.

---

## 4. Proving `group.wait()` actually blocks

The Config comment says the honest way to demonstrate this is to *remove* the wait and show threads getting killed — so that's built into the harness as a CLI flag rather than something we'd edit source live for:

```swift
let skipWait = arguments.contains("--no-wait")
...
if skipWait {
    print(">>> --no-wait: main is NOT waiting. Expect missing 'finished' lines.")
    return
}
workerGroup.wait()
auditorGroup.wait()
```
Run `swift run ThreadLab unsync --no-wait` and compare against a normal run. Captured evidence: [`output-nowait-run1.txt`](../output-nowait-run1.txt) — `main` prints the banner and returns immediately; none of the five `"[Name] finished"` lines ever appear, because the process exits out from under the workers before they get there. A normal run (any `output-unsync-*.txt`) always has all five.

**Talking point:** this is the cleanest possible demonstration that `Thread` has no automatic lifetime management tied to `main` — unlike, say, a `Task` under structured concurrency, an OS thread just keeps running (or gets killed with the process) independent of whoever created it, unless something explicitly waits.

---

## 5. Output banners and per-thread start/work/finish

`runUnsynchronized` / `runSynchronized` / `runPriorityMode` ([Harness.swift:123-133](../Sources/ThreadLab/Harness.swift#L123-L133), [157-161](../Sources/ThreadLab/Harness.swift#L157-L161)) each print the required banner pair:
```
=== UNSYNCHRONIZED RUN ===
...
=== UNSYNCHRONIZED RUN COMPLETE ===
```
and the same for `SYNCHRONIZED RUN` / `PRIORITY TEST`. The per-thread `"started"` / `"finished"` prints live inside `startWorker` itself (section 2 above), so every worker gets them for free just by going through `startWorker` — nobody writing a worker body has to remember to add them.

---

## 6. Practice-question answers for this section

**Q12. Swift `Thread` has no `join()`. How does our main thread wait for workers?**
A `DispatchGroup`: `enter()` before each thread starts, `leave()` unconditionally at the end of its closure, `wait()` on the main thread blocks until the count returns to zero. See Section 3 above.

**Q2 (partial — the mechanism, not the data). What does main do if a thread forgets to call `leave()`?**
`group.wait()` blocks forever — there's no default timeout on the plain `wait()` overload we use for `main`. (The Auditor uses `wait(timeout:)` instead, specifically so it *can* time out repeatedly and take snapshots — see Member 4's section.)

---

## Sources to cite
- `NSThread.h` in the macOS SDK: `qualityOfService` "read-only after the thread is started."
- Apple Developer Documentation: `Thread`, `DispatchGroup`.
- `Sources/ThreadLab/main.swift`, `Sources/ThreadLab/Harness.swift`.
- `output-nowait-run1.txt` — captured evidence that `group.wait()` is load-bearing.
