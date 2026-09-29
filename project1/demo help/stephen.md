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
- **Where:** declared once in VendingMachine.swift (line 48) and taken in all four Safe methods (`buyOneSafe`, `buyComboSafe`, `restockSafe`, `collectCashSafe`) plus `snapshot()`, which the Auditor uses.
- **Pattern:** `lock.lock()` then `defer { lock.unlock() }` at the top of each method. The logic is the same as the Unsafe version; the `sched_yield()` is gone because there's no gap left.
- **What it controls:** mutual exclusion. At most one thread is inside any Safe method at a time. It does **not** control order: it doesn't choose which waiting thread goes next.
- **Why it fixes the bug:** the math was never wrong. The problem was another thread running between the read and the write. With the lock held, the whole read-change-write is one unbroken block from every other thread's point of view.
- **One lock, not one per counter:** a purchase changes stock and money together. One lock keeps them consistent, and there's no deadlock risk from taking two locks in different orders.
- **Result:** both invariants are OK with drift 0 on every run (Georgia ran it 10 times).

### Code to walk through

**[`VendingMachine.swift`](../../Sources/ThreadLab/VendingMachine.swift#L2-L48) · lines 2–48**

```swift
/*   2 */ 
/*  14 */ 
/*  48 */     private let lock = NSLock()
```

*(Comments elided for space — the line numbers above are exact.)*

**What to say:**

- The one lock. It's private, so only VendingMachine's own methods can use it.

**[`VendingMachine.swift`](../../Sources/ThreadLab/VendingMachine.swift#L2-L142) · lines 2–142**

```swift
/*   2 */ 
/*  74 */     @discardableResult
/* 135 */     func buyOneSafe() -> Bool {
/* 136 */         lock.lock()
/* 137 */         defer { lock.unlock() }            // runs on every exit, including the early return
/* 138 */         guard itemsInStock > 0 else { return false }
/* 139 */         itemsInStock -= 1
/* 140 */         coinBoxCents += itemPriceCents     // both counters updated in one critical section
/* 141 */         return true
/* 142 */     }
```

*(Comments elided for space — the line numbers above are exact.)*

**What to say:**

- Compare with buyOneUnsafe: same guard, same math, same return. Only lines 136 and 137 are new.
- Line 137: `defer` runs the unlock however the function exits, including the early `return false` on line 138. Without it, that return would leave the lock held forever and every other thread would get stuck.

**[`VendingMachine.swift`](../../Sources/ThreadLab/VendingMachine.swift#L2-L174) · lines 2–174**

```swift
/*   2 */ 
/* 168 */     func collectCashSafe() {
/* 169 */         lock.lock()
/* 170 */         defer { lock.unlock() }
/* 171 */         let collected = coinBoxCents
/* 172 */         coinBoxCents = 0
/* 173 */         cashCollectedCents += collected
/* 174 */     }
```

*(Comments elided for space — the line numbers above are exact.)*

**What to say:**

- The collector's read-then-reset is now one block, so no purchase can land between reading the box and zeroing it. The vanished money from Section 3 can't happen.

**[`VendingMachine.swift`](../../Sources/ThreadLab/VendingMachine.swift#L2-L185) · lines 2–185**

```swift
/*   2 */ 
/*  14 */ 
/*  23 */ 
/* 181 */     func snapshot() -> (stock: Int, coinBox: Int, cash: Int) {
/* 182 */         lock.lock()
/* 183 */         defer { lock.unlock() }
/* 184 */         return (itemsInStock, coinBoxCents, cashCollectedCents)
/* 185 */     }
```

*(Comments elided for space — the line numbers above are exact.)*

**What to say:**

- **The bug we found in sync mode.** Totals were OK, but ThreadSanitizer reported 5 data races: the Auditor read the three counters directly, without the lock, while workers were writing them.
- The fix: this locked `snapshot()`. After it, sync mode ran with 0 races on 4 runs in a row.
- Lesson: a lock only protects data if **every** access uses it, reads included. Correct final numbers don't prove there's no race.

**[`Auditor.swift`](../../Sources/ThreadLab/Auditor.swift#L20-L37) · lines 20–37**

```swift
/*  20 */ func runAuditor(_ machine: VendingMachine,
/*  21 */                 tallies: WorkerTallies,
/*  22 */                 waitingOn workerGroup: DispatchGroup) {
/*  23 */     // wait(timeout:) instead of a bare wait() — that's what lets us snapshot
/*  24 */     // DURING the run and still stop exactly when the workers are done. It
/*  28 */     var snapshots = 0
/*  29 */     while workerGroup.wait(timeout: .now() + Config.auditSnapshotInterval) == .timedOut {
/*  30 */         snapshots += 1
/*  31 */         // Locked read: the workers are still writing, so reading the
/*  32 */         // properties directly here would be a data race of its own.
/*  33 */         let s = machine.snapshot()
/*  34 */         print("[Auditor] snapshot \(snapshots): stock=\(s.stock) "
/*  35 */               + "coinBox=\(s.coinBox)c cash=\(s.cash)c")
/*  36 */     }
/*  37 */ 
```

*(Comments elided for space — the line numbers above are exact.)*

**What to say:**

- Line 29: `wait(timeout:)` instead of `wait()`. It returns every 0.25 s while workers are still running, so the Auditor can print snapshots during the run, then stops exactly when they finish.
- Line 33: the snapshot uses the locked `snapshot()` method.

**[`Auditor.swift`](../../Sources/ThreadLab/Auditor.swift#L39-L65) · lines 39–65**

```swift
/*  39 */     let t = tallies.current
/*  40 */     print("[Auditor] all workers done — final report")
/*  41 */     print("  tallies: single=\(t.singleItemsSold) items, "
/*  42 */           + "combo=\(t.comboPurchases) purchases/\(t.comboItemsSold) items, "
/*  43 */           + "restock=\(t.restockPasses) passes, collections=\(t.cashCollections)")
/*  44 */ 
/*  45 */     // Invariant 1: itemsInStock == startingStock + restocked - sold
/*  46 */     // Conservation of inventory. Drift means updates were lost — either sales or
/*  47 */     // trays that the workers counted but that never landed.
/*  50 */     let restocked = t.restockPasses * machine.restockTraySize
/*  51 */     let expectedStock = Config.startingStock + restocked - t.totalItemsSold
/*  52 */     let actualStock = machine.itemsInStock
/*  53 */     let stockDrift = actualStock - expectedStock
/*  54 */     print("  invariant 1 (stock): expected=\(expectedStock) actual=\(actualStock) "
/*  55 */           + "drift=\(stockDrift) \(stockDrift == 0 ? "OK" : "MISMATCH")")
/*  56 */ 
/*  57 */     // Invariant 2: itemsSold * price == coinBoxCents + cashCollectedCents
/*  60 */     let expectedMoney = t.totalItemsSold * machine.itemPriceCents
/*  61 */     let actualMoney = machine.coinBoxCents + machine.cashCollectedCents
/*  62 */     let drift = actualMoney - expectedMoney
/*  63 */     print("  invariant 2 (money): expected=\(expectedMoney)c actual=\(actualMoney)c "
/*  64 */           + "drift=\(drift)c \(drift == 0 ? "OK" : "MISMATCH")")
/*  65 */ }
```

*(Comments elided for space — the line numbers above are exact.)*

**What to say:**

- The final report compares the tallies (what threads say they did) with the shared counters (what survived).
- Invariant 1 (lines 45 to 55) checks stock; invariant 2 (lines 57 to 64) checks money. Drift 0 prints OK, anything else prints MISMATCH.

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