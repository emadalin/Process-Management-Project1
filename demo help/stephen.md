# Stephen: Section 4 (Synchronized Behavior)

*ThreadLab · C335 Project 1 · demo prep*

| | |
|---|---|
| **When** | You follow Sarah Rae's Section 3 and hand off to Georgia's Section 5. |
| **Time** | about 5 min |
| **Background** | Georgia wrote this part. Her notes: [`section4-synchronized-mode-auditor.md`](../../docs/section4-synchronized-mode-auditor.md). |

> [!IMPORTANT]
> Hit every item in the checklist, then open the files in your editor and walk through the code below. Walking through your own code is how our demo covers Section 6 (Code Walkthrough).

## Section 4 · Synchronized Behavior

> [!NOTE]
> **The requirement asks you to cover:**
> - [ ] What synchronization mechanism you used
> - [ ] Where it appears in the code
> - [ ] What behavior it controls
> - [ ] Why the synchronized version behaves differently from the unsynchronized version
> - [ ] A small sample of synchronized output and an explanation of what it shows

### Key points to say

- **Mechanism:** one `NSLock`, Foundation's mutual-exclusion lock.
- **Where:** declared once in VendingMachine.swift (line 27) and taken in all four Safe methods (`buyOneSafe`, `buyComboSafe`, `restockSafe`, `collectCashSafe`) plus `snapshot()`, which the Auditor uses.
- **Pattern:** `lock.lock()` then `defer { lock.unlock() }` at the top of each method. The logic is the same as the Unsafe version; the `sched_yield()` is gone because there's no gap left.
- **What it controls:** mutual exclusion. At most one thread is inside any Safe method at a time. It does **not** control order: it doesn't choose which waiting thread goes next.
- **Why it fixes the bug:** the math was never wrong. The problem was another thread running between the read and the write. With the lock held, the whole read-change-write is one unbroken block from every other thread's point of view.
- **One lock, not one per counter:** a purchase changes stock and money together. One lock keeps them consistent, and there's no deadlock risk from taking two locks in different orders.
- **Result:** both invariants are OK with drift 0 on every run (Georgia ran it 10 times).

### Code to walk through

**[`VendingMachine.swift`](../../Sources/ThreadLab/VendingMachine.swift#L25-L27) · lines 25–27**

```swift
/*  25 */     // MARK: - Synchronization (Member 4 wires this up in the Safe methods below)
/*  26 */ 
/*  27 */     private let lock = NSLock()
```

**What to say:**

- The one lock. It's private, so only VendingMachine's own methods can use it.

**[`VendingMachine.swift`](../../Sources/ThreadLab/VendingMachine.swift#L95-L104) · lines 95–104**

```swift
/*  95 */     /// Safe counterpart of buyOneUnsafe().
/*  96 */     @discardableResult
/*  97 */     func buyOneSafe() -> Bool {
/*  98 */         lock.lock()
/*  99 */         defer { lock.unlock() }
/* 100 */         guard itemsInStock > 0 else { return false }
/* 101 */         itemsInStock -= 1
/* 102 */         coinBoxCents += itemPriceCents
/* 103 */         return true
/* 104 */     }
```

**What to say:**

- Compare with buyOneUnsafe: same guard, same math, same return. Only lines 98 and 99 are new.
- Line 99: `defer` runs the unlock however the function exits, including the early `return false` on line 100. Without it, that return would leave the lock held forever and every other thread would get stuck.

**[`VendingMachine.swift`](../../Sources/ThreadLab/VendingMachine.swift#L127-L134) · lines 127–134**

```swift
/* 127 */     /// Safe counterpart of collectCashUnsafe().
/* 128 */     func collectCashSafe() {
/* 129 */         lock.lock()
/* 130 */         defer { lock.unlock() }
/* 131 */         let collected = coinBoxCents
/* 132 */         coinBoxCents = 0
/* 133 */         cashCollectedCents += collected
/* 134 */     }
```

**What to say:**

- The collector's read-then-reset is now one block, so no purchase can land between reading the box and zeroing it. The vanished money from Section 3 can't happen.

**[`VendingMachine.swift`](../../Sources/ThreadLab/VendingMachine.swift#L136-L143) · lines 136–143**

```swift
/* 136 */     /// Reads all three counters under the lock, for the Auditor's mid-run
/* 137 */     /// snapshots. Reading the properties directly while workers are writing
/* 138 */     /// is itself a data race, even in sync mode (ThreadSanitizer flagged it).
/* 139 */     func snapshot() -> (stock: Int, coinBox: Int, cash: Int) {
/* 140 */         lock.lock()
/* 141 */         defer { lock.unlock() }
/* 142 */         return (itemsInStock, coinBoxCents, cashCollectedCents)
/* 143 */     }
```

**What to say:**

- **The bug we found in sync mode.** Totals were OK, but ThreadSanitizer reported 5 data races: the Auditor read the three counters directly, without the lock, while workers were writing them.
- The fix: this locked `snapshot()`. After it, sync mode ran with 0 races on 4 runs in a row.
- Lesson: a lock only protects data if **every** access uses it, reads included. Correct final numbers don't prove there's no race.

**[`Auditor.swift`](../../Sources/ThreadLab/Auditor.swift#L10-L24) · lines 10–24**

```swift
/*  10 */ func runAuditor(_ machine: VendingMachine,
/*  11 */                 tallies: WorkerTallies,
/*  12 */                 waitingOn workerGroup: DispatchGroup) {
/*  13 */     // wait(timeout:) instead of a bare wait() — that's what lets us snapshot
/*  14 */     // DURING the run and still stop exactly when the workers are done.
/*  15 */     var snapshots = 0
/*  16 */     while workerGroup.wait(timeout: .now() + Config.auditSnapshotInterval) == .timedOut {
/*  17 */         snapshots += 1
/*  18 */         // Locked read: the workers are still writing, so reading the
/*  19 */         // properties directly here would be a data race of its own.
/*  20 */         let s = machine.snapshot()
/*  21 */         print("[Auditor] snapshot \(snapshots): stock=\(s.stock) "
/*  22 */               + "coinBox=\(s.coinBox)c cash=\(s.cash)c")
/*  23 */     }
/*  24 */ 
```

**What to say:**

- Line 16: `wait(timeout:)` instead of `wait()`. It returns every 0.25 s while workers are still running, so the Auditor can print snapshots during the run, then stops exactly when they finish.
- Line 20: the snapshot uses the locked `snapshot()` method.

**[`Auditor.swift`](../../Sources/ThreadLab/Auditor.swift#L25-L47) · lines 25–47**

```swift
/*  25 */     let t = tallies.current
/*  26 */     print("[Auditor] all workers done — final report")
/*  27 */     print("  tallies: single=\(t.singleItemsSold) items, "
/*  28 */           + "combo=\(t.comboPurchases) purchases/\(t.comboItemsSold) items, "
/*  29 */           + "restock=\(t.restockPasses) passes, collections=\(t.cashCollections)")
/*  30 */ 
/*  31 */     // Invariant 1: itemsInStock == startingStock + restocked - sold
/*  32 */     // restockSafe/Unsafe now return whether a tray was actually loaded, so
/*  33 */     // t.restockPasses is trays loaded (not passes attempted) — see Workers.swift.
/*  34 */     let restocked = t.restockPasses * machine.restockTraySize
/*  35 */     let expectedStock = Config.startingStock + restocked - t.totalItemsSold
/*  36 */     let actualStock = machine.itemsInStock
/*  37 */     let stockDrift = actualStock - expectedStock
/*  38 */     print("  invariant 1 (stock): expected=\(expectedStock) actual=\(actualStock) "
/*  39 */           + "drift=\(stockDrift) \(stockDrift == 0 ? "OK" : "MISMATCH")")
/*  40 */ 
/*  41 */     // Invariant 2: itemsSold * price == coinBoxCents + cashCollectedCents
/*  42 */     let expectedMoney = t.totalItemsSold * machine.itemPriceCents
/*  43 */     let actualMoney = machine.coinBoxCents + machine.cashCollectedCents
/*  44 */     let drift = actualMoney - expectedMoney
/*  45 */     print("  invariant 2 (money): expected=\(expectedMoney)c actual=\(actualMoney)c "
/*  46 */           + "drift=\(drift)c \(drift == 0 ? "OK" : "MISMATCH")")
/*  47 */ }
```

**What to say:**

- The final report compares the tallies (what threads say they did) with the shared counters (what survived).
- Invariant 1 (lines 31 to 39) checks stock; invariant 2 (lines 41 to 46) checks money. Drift 0 prints OK, anything else prints MISMATCH.

### Output to show

**output-sync-run1.txt (release build)**

```text
[SingleBuyer] sold 3548618 items
[ComboBuyer] sold 2853173 combos = 8559519 items
[RestockDriver] loaded 241973 trays of 50
[Auditor] all workers done — final report
  invariant 1 (stock): expected=513 actual=513 drift=0 OK
  invariant 2 (money): expected=1816220550c actual=1816220550c drift=0c OK
```

**What it shows:**

- Far more work than the unsync sample: over 12 million items sold and 241,973 trays loaded.
- Stock matches to the item (513 = 10,000 + 12,098,650 restocked − 12,108,137 sold), and $18,162,205.50 is on both sides. Drift is 0 on both.
- Same threads, same work as unsync. The only difference is the lock.
- Live: `swift run -c release ThreadLab sync`. Numbers change each run; drift stays 0.

**ThreadSanitizer before and after the snapshot fix**

```text
output-tsan-sync-before-fix.txt   5 warnings (Auditor reading without the lock)
output-tsan-sync.txt              0 warnings, 4 runs
output-tsan-unsync.txt           13 warnings (for comparison)
```

**What it shows:**

- Command: `swift run --sanitize=thread ThreadLab sync`

### If you're asked

<details>
<summary><b>Could this deadlock?</b></summary>

Not as designed: one lock, each Safe method takes it once and releases it with defer, and no Safe method calls another. It would deadlock if one did, because NSLock isn't recursive.

</details>

<details>
<summary><b>Why NSLock?</b></summary>

Simple and readable, and it works on macOS 13. Mutex needs macOS 15; a serial DispatchQueue would mix GCD into a demo about threads.

</details>

<details>
<summary><b>Mutual exclusion, ordering, or both?</b></summary>

Mutual exclusion only. Forcing a turn order would need something like NSConditionLock, which we didn't build.

</details>

<details>
<summary><b>Is sync slower?</b></summary>

It should be, since threads wait on the lock. We didn't time it, so don't quote a number.

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