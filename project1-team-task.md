# Project 1: Team Task Breakdown

**Scenario:** Vending Machine inventory (the inventory umbrella we picked, with money added as a second shared resource)
**Stack:** Swift on macOS · Foundation `Thread` + `DispatchGroup` + `NSLock`
**Deliverable:** one program, three labeled modes — `unsync`, `sync`, `priority` (plus `all`)

Fill in names below. Five members, five owned areas. Everything in Section 6 is shared.

---

## 1. Shared Resource & Threads

One `VendingMachine` class, marked `@unchecked Sendable`, holding three plain `Int` properties:

- `itemsInStock` (starts at 10,000)
- `coinBoxCents` (money sitting in the machine)
- `cashCollectedCents` (money emptied out of the machine)

Prices are whole cents (`150`, not `1.50`) so expected-vs-actual comparisons stay exact. No arrays or dictionaries for stock — racing on those can crash instead of producing wrong numbers.

Each worker also keeps a **private tally** of what it did. Only that thread touches its own tally, so there is no race on it, and the Auditor uses the tallies to compute the expected totals.

---

## 2. Thread → Assignment Section Map

| Thread name | Task | Part A (creation) | Part B (the bug it causes) | Part C |
|---|---|---|---|---|
| `SingleBuyer` | If stock > 0, take 1 item, add price to coin box | Distinct task #1 | Lost updates on stock *and* money; two buyers can both get the "last" item | — |
| `ComboBuyer` | If stock ≥ 3, take 3 items, add 3× price | Distinct task #2 | Check-then-act: both threads pass the check, stock goes negative (overselling) | — |
| `RestockDriver` | When stock drops below a threshold, load a tray of 50 | Distinct task #3 | A whole tray gets overwritten and vanishes — big, visible wrong total | — |
| `CashCollector` | Read `coinBoxCents`, add it to `cashCollectedCents`, reset box to 0 | Distinct task #4 | Any purchase landing between the read and the reset is erased — money disappears | — |
| `Auditor` | Waits for the other four, then prints expected vs. actual for stock and money | Distinct task #5 (coordination, not more counting) | Reports the drift; proves the bug with numbers | Prints the results table |
| `PickerRobot1/2/3` | Identical CPU-bound vend loop for a fixed 2 seconds | — | — | The 3+ racer threads |

**Two invariants the Auditor checks:**

1. `itemsInStock == startingStock + restocked − sold`
2. `itemsSold × price == coinBoxCents + cashCollectedCents`

In `sync` mode both hold on every run. In `unsync` mode both usually drift.

**Requirements coverage check:**

- Part A: 5 named threads, 5 distinct tasks, start/work/finish output, main waits via `DispatchGroup` ✓
- Part B: shared resource ✓, real problem (lost updates, overselling, vanished money) ✓, `NSLock` fix ✓, expected-vs-actual output ✓
- Part C: 3 identical CPU-bound threads ✓, default vs. modified QoS ✓, 5+ runs per config ✓

---

## 3. Owned Areas

### Member 1 — Research & Threading Model · `Sarah Rae & Calli`
Owns demo sections 1 and 7, plus repo setup.

- [x] Create the Swift package (`Package.swift` + `Sources/ThreadLab/`), push it, confirm it builds on all five Macs
- [x] Write notes on: Foundation `Thread` = 1:1 kernel threads vs. GCD's managed pool vs. Swift Concurrency `Task`s
- [x] Write notes on `@unchecked Sendable` — what it means and why our race demo needs it
- [x] Prepare the Pros/Cons/Limitations section: lock overhead and contention, results varying by Mac hardware, and the "rewrite `VendingMachine` as an `actor`" improvement
- [ ] Record everyone's machine details: `sw_vers`, `uname -m`, `sysctl -n hw.ncpu`, `swift --version`
- [x] Own the README and the team contribution statement
- [x] Schedule the rehearsal and confirm each person is explaining a section they did not write

### Member 2 — Thread Creation Harness (Part A) · `Stephen`
Owns demo section 2.

- [x] Write `startWorker(_:group:qos:task:)` — sets `thread.name`, sets `qualityOfService` **before** `start()`, calls `group.enter()` / `group.leave()`
- [x] Write the `main.swift` CLI mode switch: `unsync`, `sync`, `priority`, `all`
- [x] Add the output banners: `=== UNSYNCHRONIZED RUN ===`, `=== SYNCHRONIZED RUN ===`, `=== PRIORITY TEST ===`
- [x] Make sure every thread prints when it starts, what it does, and when it finishes
- [x] Confirm `group.wait()` on the main thread actually blocks — test by removing it and showing threads get killed when `main` exits
- [ ] Be ready to explain why `Thread` has no `join()` and how `DispatchGroup` works as a latch

### Member 3 — Unsynchronized Mode (Part B, first half) · `Ella`
Owns demo section 3.

- [x] Write the `VendingMachine` class skeleton with the three `Int` properties (coordinate with Member 4 on the shape before either of you codes methods)
- [x] Write the unsafe methods: `buyOneUnsafe()`, `buyComboUnsafe()`, `restockUnsafe()`, `collectCashUnsafe()`
- [x] Use read → `sched_yield()` → write to widen the timing window (be ready to say this *exposes* the bug, it does not create it)
- [x] Write the four worker thread bodies, each with its private tally *(written by Stephen in `Workers.swift` + `Tallies.swift`)*
- [x] Keep `print` out of the hot loops — printing slows threads and hides races
- [x] Capture sample output showing negative stock, lost trays, and vanished cash *(`output-unsync-ella-run1.txt`/`run2.txt` show both invariants failing by tens of millions after retuning Config's iteration counts so restocking actually happens; `output-unsync-negative-stock.txt` catches `itemsInStock` at -3 mid-run; `output-unsync-run1.txt` (Stephen's original, smaller-scale capture) still stands as the first evidence of vanished cash)*
- [ ] Be ready to explain exactly where the read-modify-write gap is in each method

### Member 4 — Synchronized Mode & Auditor (Part B, second half) · `Georgia`
Owns demo section 4.

- [x] Write the safe methods with `NSLock`: `lock.lock()` + `defer { lock.unlock() }`, identical logic otherwise
- [x] Note the `NSLock` caveats for the demo: not recursive (locking twice on one thread deadlocks), must unlock on the locking thread
- [x] Write the `Auditor` thread: periodic snapshots plus the final expected-vs-actual report for both invariants *(Stephen wrote the snapshots + invariant 2 in `Auditor.swift`; Georgia finished invariant 1 once `restockSafe`/`restockUnsafe` started returning whether a tray was actually loaded)*
- [x] Verify `sync` mode matches on every run (run it at least 10 times) *(ran release build 10x, both invariants OK every run; `unsync` still shows real drift for contrast)*
- [ ] Be ready to answer: does our lock give mutual exclusion, ordering, or both? (Mutual exclusion only)
- [ ] Be ready to answer: can this deadlock? Why or why not?
- [ ] **Optional bonus:** `NSConditionLock` turnstile to force ordering, which shows the contrast with a plain lock

### Member 5 — Priority & Scheduling (Part C) · `Sarah Rae & Calli`
Owns demo section 5.

- [x] Write the three `PickerRobot` racer threads: identical CPU-bound loop counting iterations until a 2-second deadline
- [x] Print each thread's `qualityOfService`, `threadPriority`, and `qos_class_self()` (requested vs. actually applied)
- [x] Store racer results in a lock-protected store, print after all racers finish
- [x] Run config 1 (all `.default`) at least 5 times; run config 2 (`.userInteractive` / `.utility` / `.background`) at least 5 times *(Calli: `output-priority-run1.txt` on M3 Pro; Sarah Rae: `output-priority-run2.txt` on M2)*
- [x] Add extra load threads so there are more CPU-bound threads than cores — that is how we create contention, since macOS has no CPU pinning
- [x] Note the chip for every run (`uname -m`); on Apple Silicon check `sysctl hw.perflevel0.physicalcpu hw.perflevel1.physicalcpu`
- [x] Reduce noise: plugged in, Low Power Mode off, heavy apps closed, machine cooled between runs *(met in run 2; run 1 had Low Power Mode on)*
- [x] Measure **work done in a fixed time**, not who prints first — the first thread started gets a head start regardless of QoS
- [ ] Fill in the results table *(done, see Section 5)*; be ready to explain P-core vs. E-core placement and why QoS is a request, not a guarantee

---

## 4. Testing & Evidence (Member 5 leads, Member 3 assists)

- [ ] `swift run --sanitize=thread ThreadLab unsync` → save the data race reports
- [ ] `swift run --sanitize=thread ThreadLab sync` → confirm clean, save that too
- [ ] Run both debug and `-c release`; note any difference in how often the race appears
- [ ] Save outputs: `swift run ThreadLab unsync | tee output-unsync-run1.txt` (at least 2 runs total, more is better) *(1 of 2: Stephen saved `output-unsync-run1.txt`)*
- [ ] Hand the priority results table to Member 1 for the README

---

## 5. Results Table

Clean run on Sarah Rae's Mac (plugged in, Low Power Mode off, heavy apps closed, thermal state nominal). Full output: `output-priority-run2.txt`. Every racer's `qos_class_self()` matched the QoS it requested.

| Run | Config | Picker-1 | Picker-2 | Picker-3 | Chip | Build | Notes |
|---|---|---|---|---|---|---|---|
| 1 | All `.default` | 86,009,143 | 85,525,152 | 86,179,471 | Apple M2 | release | +8 load threads, AC power, Low Power Mode off |
| 2 | All `.default` | 87,117,482 | 87,342,800 | 85,358,754 | Apple M2 | release | +8 load threads, AC power, Low Power Mode off |
| 3 | All `.default` | 87,285,531 | 85,710,834 | 86,524,599 | Apple M2 | release | +8 load threads, AC power, Low Power Mode off |
| 4 | All `.default` | 86,684,015 | 85,492,367 | 95,983,137 | Apple M2 | release | +8 load threads, AC power, Low Power Mode off |
| 5 | All `.default` | 87,297,979 | 94,688,459 | 87,601,165 | Apple M2 | release | +8 load threads, AC power, Low Power Mode off |
| 1 | `.userInteractive` / `.utility` / `.background` | 102,171,518 | 42,497,988 | 7,546,914 | Apple M2 | release | +8 load threads, AC power, Low Power Mode off |
| 2 | `.userInteractive` / `.utility` / `.background` | 102,611,424 | 45,802,594 | 9,672,077 | Apple M2 | release | +8 load threads, AC power, Low Power Mode off |
| 3 | `.userInteractive` / `.utility` / `.background` | 103,367,904 | 35,483,978 | 8,358,784 | Apple M2 | release | +8 load threads, AC power, Low Power Mode off |
| 4 | `.userInteractive` / `.utility` / `.background` | 99,916,055 | 37,869,646 | 8,130,092 | Apple M2 | release | +8 load threads, AC power, Low Power Mode off |
| 5 | `.userInteractive` / `.utility` / `.background` | 100,112,780 | 40,223,563 | 11,264,271 | Apple M2 | release | +8 load threads, AC power, Low Power Mode off |

**Averages (% of the fastest racer in that config):**

| Machine | Config | Picker-1 | Picker-2 | Picker-3 |
|---|---|---|---|---|
| Apple M2 (4P / 4E), run 2 | All `.default` | 86,878,830 (98%) | 87,751,922 (99%) | 88,329,425 (100%) |
| Apple M2 (4P / 4E), run 2 | `.userInteractive` / `.utility` / `.background` | 101,635,936 (100%) | 40,375,553 (39%) | 8,994,427 (8%) |
| Apple M3 Pro (5P / 6E), run 1 | All `.default` | 97,315,196 (99%) | 97,696,332 (99%) | 97,826,963 (100%) |
| Apple M3 Pro (5P / 6E), run 1 | `.userInteractive` / `.utility` / `.background` | 111,829,576 (100%) | 14,393,371 (12%) | 1,958,152 (1%) |

The M3 Pro run (Calli's, `output-priority-run1.txt`) had **Low Power Mode ON**, so use it only as a hardware comparison, not as the main evidence.

---

## 6. Everyone, No Exceptions

The instructor can ask any team member about any part.

- [ ] Read all 18 practice questions in the brief and be able to answer every one
- [ ] Be able to walk through code you did not write — thread creation, the shared class, the critical sections, the QoS settings
- [ ] At rehearsal, present a section someone **else** built
- [ ] Never claim priority guarantees execution order

**Cross-assignment for rehearsal** (present someone else's section):

Members 1 and 5 are the same people, so the swap is by person:

| Presenter | Presents |
|---|---|
| Calli | Section 2, thread creation harness (Stephen's) |
| Sarah Rae | Section 3, unsynchronized mode (Ella's) |
| Stephen (Member 2) | Section 4, synchronized mode (Georgia's) |
| Ella (Member 3) | Sections 1 and 7, threading model and pros/cons (Sarah Rae & Calli's) |
| Georgia (Member 4) | Section 5, priority results (Sarah Rae & Calli's) |

Five sections, five presenters, each presenting someone else's work.

---

## 7. Order of Work

1. Member 1 sets up the package and pushes it — nobody else can start until this builds
2. Members 3 and 4 agree on the `VendingMachine` property names and method signatures
3. Member 2 builds the harness; Members 3 and 4 write their method sets in parallel
4. Member 5 builds Part C (independent of Parts A and B, can start any time after step 1)
5. Testing and output capture
6. README and contribution statement
7. Rehearsal
