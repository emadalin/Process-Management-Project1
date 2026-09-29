# ThreadLab: Process Management Project 1

Threads, synchronization, and scheduling in **Swift on macOS**, demonstrated with a vending machine whose stock and money are shared by several threads.

**Team:** Sarah Rae · Calli · Stephen · Ella · Georgia

---

## What the program demonstrates

One program with three labeled modes:

| Mode | Assignment part | What it shows |
|---|---|---|
| `unsync` | A + B | Five named threads (`SingleBuyer`, `ComboBuyer`, `RestockDriver`, `CashCollector`, `Auditor`) share one `VendingMachine` with no locking. Expected vs. actual totals drift: lost updates, overselling, vanished trays and cash. |
| `sync` | A + B | Same threads and work, with every critical section protected by `NSLock`. Expected and actual totals match. |
| `priority` | C | Three identical CPU-bound `PickerRobot` threads run for a fixed 2 seconds, first with all-`.default` QoS and then with `.userInteractive` / `.utility` / `.background`. Compares work done. |
| `all` | A + B + C | Runs all three in order. |

The Auditor checks two invariants:
1. `itemsInStock == startingStock + restocked − sold`
2. `itemsSold × price == coinBoxCents + cashCollectedCents`

---

## Requirements

- macOS 13 or later
- Swift 6.0 or later (Xcode 16+ or the Command Line Tools)

```bash
xcode-select --install   # only if `swift` isn't found
swift --version
```

## Build & run

```bash
swift run ThreadLab all                  # debug build, all modes
swift run -c release ThreadLab all       # optimized build
swift run ThreadLab unsync               # one mode: unsync | sync | priority
```

**Race detection (Thread Sanitizer):**
```bash
swift run --sanitize=thread ThreadLab unsync   # expect data race reports
swift run --sanitize=thread ThreadLab sync     # expect a clean run
```

**Save output for submission:**
```bash
swift run ThreadLab unsync | tee output-unsync-run1.txt
swift run ThreadLab sync   | tee output-sync-run1.txt
```

---

## Project layout

```
Package.swift                      swift-tools-version 6.0 (Swift 6 language mode)
Sources/ThreadLab/
  main.swift                       mode switch, thread harness, banners   (Member 2)
  VendingMachine.swift             shared resource: Unsafe + Safe methods (Members 3 & 4)
  PriorityTest.swift               Part C: PickerRobot racers, QoS comparison   (Member 5)
docs/
  section1-threading-model.md      Thread vs. GCD vs. Task, @unchecked Sendable
  section5-priority-scheduling.md  QoS vs. threadPriority, P/E cores, results
  section7-pros-cons-limitations.md
  machine-details.md               every team Mac's OS, chip, cores, Swift version
project1-threads-brief.md          assignment brief
project1-team-task.md              task breakdown and progress checklist
```

---

## Machine details

Every captured run must record macOS version, chip, core counts, Swift version, and debug vs. release. See [`docs/machine-details.md`](docs/machine-details.md).

## Sample output

Machine column is "not recorded" where the captured file itself doesn't print which Mac ran it — only the `priority` mode banner reports machine info per run (see [Priority results](#priority-results) below).

| File | Mode | Build | Mac | Result |
|---|---|---|---|---|
| [`output-unsync-run1.txt`](output-unsync-run1.txt) | `unsync` | debug | not recorded | Invariant 1 off by 16,167; invariant 2 off by $2,548.50 — both MISMATCH |
| [`output-unsync-ella-run1.txt`](output-unsync-ella-run1.txt), [`run2.txt`](output-unsync-ella-run2.txt) | `unsync` | debug | not recorded | Both invariants off by tens of millions in stock / over $1M in cents |
| [`output-unsync-negative-stock.txt`](output-unsync-negative-stock.txt) | `unsync` | debug | not recorded | `itemsInStock` observed at **-3** mid-run (overselling) |
| [`output-nowait-run1.txt`](output-nowait-run1.txt) | `unsync --no-wait` | debug | not recorded | Main exits before workers print `finished` — proves `group.wait()` is load-bearing |
| [`output-sync-run1.txt`](output-sync-run1.txt) | `sync` | release | not recorded | Both invariants `OK`, drift = 0 |
| [`output-tsan-unsync.txt`](output-tsan-unsync.txt) | `unsync` (ThreadSanitizer) | debug | Apple M2 (Sarah Rae) | 13 data race warnings |
| [`output-tsan-sync-before-fix.txt`](output-tsan-sync-before-fix.txt) | `sync` (ThreadSanitizer) | debug | Apple M2 (Sarah Rae) | 5 warnings, all from the Auditor's snapshots reading without the lock (fixed with a locked `VendingMachine.snapshot()`) |
| [`output-tsan-sync.txt`](output-tsan-sync.txt) | `sync` (ThreadSanitizer) | debug | Apple M2 (Sarah Rae) | 0 warnings after the fix, confirmed on 4 runs |
| [`output-unsync-debug-10runs.txt`](output-unsync-debug-10runs.txt) | `unsync` ×10 | debug | Apple M2 (Sarah Rae) | Both invariants MISMATCH in 10/10 runs; avg $798,198.45 lost (6.59% of revenue) |
| [`output-unsync-release-10runs.txt`](output-unsync-release-10runs.txt) | `unsync` ×10 | release | Apple M2 (Sarah Rae) | Both invariants MISMATCH in 10/10 runs; avg $2,173.50 lost (0.84% of revenue) |

**Debug vs. release:** the race showed up in **every** run of both builds (10/10 each, both invariants), so the optimizer does not hide it. What changes is the size. In release, each run finishes in about 0.2 s instead of about 1 s, and most of the 4,000,000 loop passes find the stock empty and do nothing, so far fewer purchases actually happen (about 173K items sold per run vs. about 8.1M in debug). Fewer real read-then-write operations means fewer chances to overlap, so release lost 0.84% of revenue on average vs. 6.59% in debug. Release runs are also shorter than the Auditor's 0.25 s snapshot interval, so they print no mid-run snapshots.

## Priority results

Results table from Member 5 (at least 5 runs per configuration). Full raw runs: [`output-priority-run1.txt`](output-priority-run1.txt) (Calli, Apple M3 Pro), [`output-priority-run2.txt`](output-priority-run2.txt) (Sarah Rae, Apple M2). Full per-run numbers are in [`project1-team-task.md`, Section 5](project1-team-task.md#5-results-table).

**Averages (% of the fastest racer in that config):**

| Machine | Config | Picker-1 | Picker-2 | Picker-3 |
|---|---|---|---|---|
| Apple M2 (4P / 4E), run 2 | All `.default` | 86,878,830 (98%) | 87,751,922 (99%) | 88,329,425 (100%) |
| Apple M2 (4P / 4E), run 2 | `.userInteractive` / `.utility` / `.background` | 101,635,936 (100%) | 40,375,553 (39%) | 8,994,427 (8%) |
| Apple M3 Pro (5P / 6E), run 1 | All `.default` | 97,315,196 (99%) | 97,696,332 (99%) | 97,826,963 (100%) |
| Apple M3 Pro (5P / 6E), run 1 | `.userInteractive` / `.utility` / `.background` | 111,829,576 (100%) | 14,393,371 (12%) | 1,958,152 (1%) |

The M3 Pro run (Calli's) had Low Power Mode **on**, so treat it as a hardware comparison, not the primary evidence — the M2 run (Sarah Rae's, Low Power Mode off, plugged in) is the clean official run.

---

## Team contribution statement

| Member | Name | Area | What they built / wrote |
|---|---|---|---|
| 1 | Sarah Rae & Calli | Research & threading model, repo setup, README | Swift package setup; threading-model and `@unchecked Sendable` notes; pros/cons/limitations notes; team machine details; README and this statement |
| 2 | Stephen | Thread creation harness (Part A) | `startWorker` harness with named threads and `DispatchGroup` waiting; `main.swift` mode switch; output banners |
| 3 | Ella | Unsynchronized mode (Part B) | `VendingMachine` skeleton; Unsafe methods; the four worker threads with private tallies; unsync sample output |
| 4 | Georgia | Synchronized mode & Auditor (Part B) | `NSLock` Safe methods; Auditor thread and expected-vs-actual report; repeated sync verification runs |
| 5 | Sarah Rae & Calli | Priority & scheduling (Part C) | `PickerRobot` racer threads; QoS / priority reporting; priority results table; Thread Sanitizer and output capture (with Ella) |

**How we made sure everyone understands the whole project:**
- Each member practiced presenting a section they **did not** write:

  | Presenter | Presents |
  |---|---|
  | Calli | Section 2, thread creation (Stephen's) |
  | Sarah Rae | Section 3, unsynchronized mode (Ella's) |
  | Stephen | Section 4, synchronized mode (Georgia's) |
  | Ella | Sections 1 and 7, threading model and pros/cons (Sarah Rae & Calli's) |
  | Georgia | Section 5, priority (Sarah Rae & Calli's) |

- Every member worked through all 18 practice questions in the brief.
- Each member walked through code they didn't write: thread creation, the shared class, the critical sections, and the QoS settings.

## What we found along the way

Things that surprised us, broke, or blocked us while building and testing. Several of these make good answers if the instructor asks "what went wrong?"

**1. ThreadSanitizer found a race in the *synchronized* mode.**
Both invariants said `OK` in `sync` mode on every run, but `swift run --sanitize=thread ThreadLab sync` reported 5 data races. They came from the Auditor's snapshots during the run: it read `itemsInStock`, `coinBoxCents` and `cashCollectedCents` directly, without the lock, while the workers were writing to them under it. The invariants never caught it because the final report only runs after every worker has finished. We fixed it with a locked `VendingMachine.snapshot()`, and `sync` then ran with 0 warnings on 4 runs. Lesson: correct final numbers don't prove there's no race, and a lock only protects data if **every** access goes through it, reads included. Evidence: [`output-tsan-sync-before-fix.txt`](output-tsan-sync-before-fix.txt) and [`output-tsan-sync.txt`](output-tsan-sync.txt). Details are in [`docs/section4-synchronized-mode-auditor.md`](docs/section4-synchronized-mode-auditor.md).

**2. ThreadSanitizer crashed on one team Mac, which blocked a test.**
On Calli's Apple M3 Pro (macOS 26.6.2), `swift run --sanitize=thread` crashed on startup in both debug and release, with a segfault inside ThreadSanitizer's own setup (`__tsan::InitializePlatform`) before our program printed anything. Plain runs without the sanitizer worked fine on that Mac. The same sanitizer runs worked on Sarah Rae's Apple M2 (macOS 15.7.4), so all of our sanitizer evidence comes from that Mac. We didn't find the cause. This blocked the debug vs. release comparison on Calli's Mac, until we realized the task didn't need the sanitizer at all: plain `unsync` runs are enough to count how often the invariants break. We ran it on the M2 instead.

**3. The race happens in both debug and release builds, but release loses much less.**
In 10 `unsync` runs per build, both invariants broke in 10/10 runs of each. Release lost 0.84% of revenue on average vs. 6.59% in debug. Release runs finish in about 0.2 s, and most loop passes find the stock empty, so far fewer real purchases happen and there are fewer chances to overlap. The optimizer doesn't fix the race. It just gives it fewer chances. See the [Sample output](#sample-output) section.

**4. Low Power Mode quietly affected a priority run.**
The first full priority run (Calli's M3 Pro) printed `Low Power Mode: ON` in its banner. Our noise-reduction rules require it off, so we re-ran on Sarah Rae's M2, plugged in, with Low Power Mode off and heavy apps closed, and used that as the official run. Printing the power and thermal state in the program itself is what caught this.

**5. How much QoS matters depends on the Mac.**
With mixed QoS, the `.utility` racer did 39% of the top racer's work on the M2 (4 performance + 4 efficiency cores) but only 12% on the M3 Pro (5 + 6). The `.background` racer did 8% vs. 1%. The order was the same on both, but the gap was not. The M3 Pro run had Low Power Mode on, so it isn't a clean comparison. It still shows why QoS is a request to the scheduler, not a guarantee.

**6. Invariant 1 couldn't be checked at first.**
`restockUnsafe()` and `restockSafe()` originally returned nothing, so the Auditor couldn't tell a restock that loaded a tray from one that did nothing because stock was above the threshold. Invariant 1 was reported as skipped until the methods were changed to return `Bool`, like the buy methods already did. Sections 3 and 4 depended on each other more than we expected.

**7. The race was always there, but some symptoms were hard to capture.**
Our first `unsync` captures showed vanished cash, but stock ended at exactly 0 and no trays were lost. It took retuning the iteration counts so restocking actually happens to capture `itemsInStock` at -3 mid-run ([`output-unsync-negative-stock.txt`](output-unsync-negative-stock.txt)).

**8. Swift 6 and Git details that tripped us up.**
- In Swift 6, top-level `let` constants in `main.swift` are isolated to the main actor, so our `Thread` closures couldn't use them. We moved the settings into `enum Config` in `Harness.swift`.
- `.build/` (compiler output) was committed early on and caused pull conflicts, so we stopped tracking it and added it to `.gitignore`.

## AI tools and outside sources

**Tool used:** Claude Code, Anthropic's AI coding assistant (Claude Opus 5 and Claude Sonnet 5 models). Every team member used it at some point. Commits where it helped are marked with a `Co-Authored-By: Claude …` line in the Git history (`git log`).

**What it helped with:**
- **Documentation:** drafting the `docs/` talking-point files, this README, the team task list, and machine-details tables.
- **Code:** the Part C priority test (`PriorityTest.swift`), wiring up the real worker bodies, and the fix for the Auditor snapshot race (`VendingMachine.snapshot()`).
- **Testing and evidence:** running the ThreadSanitizer, debug vs. release and priority tests, and summarizing their output into the tables above.
- **Repo housekeeping:** pulling and merging teammates' work, updating the task list, and removing tracked build files.

**How we checked the AI's work:**
- **Code changes were verified by running the program:** builds in debug and release, the Auditor's two invariants, and ThreadSanitizer (`unsync` must report races, `sync` must be clean).
- **Numbers in the docs were checked against the saved output files.** This caught real mistakes. For example, the AI first wrote the debug vs. release dollar amounts 100× too small, and that was fixed before committing.
- **Claims were checked against the code.** One task list note said ThreadSanitizer had worked earlier on Calli's Mac, but the cited output files were actually from Sarah Rae's Mac, so the README says what we actually know.
- **Everyone is responsible for explaining any part of the code**, including AI-assisted parts, per the team rules in [`project1-team-task.md`](project1-team-task.md).

**Other sources:** Apple's documentation for `Thread`, `DispatchGroup`, `NSLock` and `QualityOfService`, and the project brief ([`project1-threads-brief.md`](project1-threads-brief.md)).
