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

| File | Mode | Build | Mac | Result |
|---|---|---|---|---|
| | `unsync` | | | |
| | `sync` | | | |

## Priority results

Results table from Member 5 (at least 5 runs per configuration): *to be added.*

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
  | Sarah Rae & Calli | Section 2, thread creation (Stephen's) and Section 3, unsynchronized mode (Ella's) |
  | Stephen | Section 4, synchronized mode (Georgia's) |
  | Ella | Sections 1 and 7, threading model and pros/cons (Sarah Rae & Calli's) |
  | Georgia | Section 5, priority (Sarah Rae & Calli's) |

- Every member worked through all 18 practice questions in the brief.
- Each member walked through code they didn't write: thread creation, the shared class, the critical sections, and the QoS settings.

## AI tools and outside sources

- Claude Code (AI assistant) was used to help draft documentation (`docs/`, this README). The team reviewed, edited, and verified it against the code and Apple's documentation.
- *Add any other AI use or online examples here, and confirm the code was reviewed, adapted, and tested.*
