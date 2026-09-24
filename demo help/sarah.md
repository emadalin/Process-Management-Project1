# Sarah Rae: Section 3 (Unsynchronized Behavior)

*ThreadLab · C335 Project 1 · demo prep*

| | |
|---|---|
| **When** | You follow Calli's Section 2 and hand off to Stephen's Section 4. |
| **Time** | about 5 min |
| **Background** | Ella wrote this part. Her notes: [`section3-unsynchronized-mode.md`](../../docs/section3-unsynchronized-mode.md). |

> [!IMPORTANT]
> Hit every item in the checklist, then open the files in your editor and walk through the code below. Walking through your own code is how our demo covers Section 6 (Code Walkthrough).

## Section 3 · Unsynchronized Behavior

> [!NOTE]
> **The requirement asks you to cover:**
> - [ ] What shared resource or ordering problem exists
> - [ ] What incorrect, random, or nondeterministic behavior appears
> - [ ] Why that behavior occurs
> - [ ] A small sample of unsynchronized output and an explanation of what it shows

### Key points to say

- **Shared resource:** one VendingMachine object with three plain Int counters: `itemsInStock` (starts at 10,000), `coinBoxCents` (money in the machine) and `cashCollectedCents` (money taken out). Prices are whole cents so totals compare exactly.
- **How we detect a problem:** the Auditor checks two invariants. (1) Stock = 10,000 + restocked − sold. (2) Coin box + collected cash = items sold × price. The expected side comes from each thread's private tally; the actual side comes from the shared machine.
- **What goes wrong:** lost updates (sales and restocks overwritten), overselling (stock went negative, −3), and vanished cash. Both invariants say MISMATCH.
- **Why:** `stock = stock − 1` looks like one step but is three: read, change, write. The kernel can switch threads between any of them. If another thread changes the value in that gap, our write puts back an old number and erases their change.
- **Nondeterministic:** the amount of drift is different every run because the thread switches happen at different moments. We ran it 10 times per build: both invariants broke in 10 out of 10 runs, every time by a different amount.
- **About sched_yield():** it asks the scheduler to switch threads right at that spot. It exposes the race, it doesn't create it. Without it the gap still exists; the bug just shows up less often.

### Code to walk through (VendingMachine.swift)

**[`VendingMachine.swift`](../../Sources/ThreadLab/VendingMachine.swift#L22-L31) · lines 22–31**

```swift
/*  22 */ final class VendingMachine: @unchecked Sendable {
          …
/*  29 */     var itemsInStock: Int          // inventory — buyers decrement, restocker increments
/*  30 */     var coinBoxCents: Int          // money in the machine, emptied by the collector
/*  31 */     var cashCollectedCents: Int    // money already banked
```

*(Comments elided for space — the line numbers above are exact.)*

**What to say:**

- The shared resource: three counters that every worker thread reads and changes.

**[`VendingMachine.swift`](../../Sources/ThreadLab/VendingMachine.swift#L75-L82) · lines 75–82**

```swift
/*  75 */     func buyOneUnsafe() -> Bool {
/*  76 */         guard itemsInStock > 0 else { return false }
/*  77 */         let currentStock = itemsInStock    // READ
/*  78 */         sched_yield()                      // widen the timing window (exposes the bug, doesn't create it)
/*  79 */         itemsInStock = currentStock - 1    // WRITE (may overwrite another thread's update)
/*  80 */         coinBoxCents += itemPriceCents     // also not atomic
/*  81 */         return true
/*  82 */     }
```

**What to say:**

- **Lost update.** Line 77 reads stock into a local copy. Line 78 yields. Line 79 writes back the copy minus 1.
- If another thread changed the stock during the yield, line 79 overwrites their change with a stale number.
- Line 80 has no yield but is still read-change-write with no lock, so it can lose updates too.

**[`VendingMachine.swift`](../../Sources/ThreadLab/VendingMachine.swift#L88-L94) · lines 88–94**

```swift
/*  88 */     func buyComboUnsafe() -> Bool {
/*  89 */         guard itemsInStock >= comboSize else { return false }  // CHECK
/*  90 */         sched_yield()                                          // widen the check-then-act gap
/*  91 */         itemsInStock -= comboSize                              // ACT (stock can go negative if another thread already passed the check)
/*  92 */         coinBoxCents += comboSize * itemPriceCents
/*  93 */         return true
/*  94 */     }
```

**What to say:**

- **Check-then-act**, a different bug. Line 89 checks there are at least 3 items, line 90 yields, line 91 subtracts 3.
- Two threads can both pass the check while stock is low, then both subtract, and stock goes **negative**. That's overselling.

**[`VendingMachine.swift`](../../Sources/ThreadLab/VendingMachine.swift#L102-L108) · lines 102–108**

```swift
/* 102 */     func restockUnsafe() -> Bool {
/* 103 */         guard itemsInStock < restockThreshold else { return false }
/* 104 */         let currentStock = itemsInStock            // READ
/* 105 */         sched_yield()                              // widen the window (another restock landing here gets overwritten)
/* 106 */         itemsInStock = currentStock + restockTraySize  // WRITE
/* 107 */         return true
/* 108 */     }
```

**What to say:**

- Same read-yield-write shape as buyOneUnsafe. A buyer's sale that lands during the yield gets overwritten by old stock + 50.

**[`VendingMachine.swift`](../../Sources/ThreadLab/VendingMachine.swift#L113-L118) · lines 113–118**

```swift
/* 113 */     func collectCashUnsafe() {
/* 114 */         let collected = coinBoxCents       // READ
/* 115 */         sched_yield()                      // widen the window (a purchase landing here gets erased below)
/* 116 */         cashCollectedCents += collected
/* 117 */         coinBoxCents = 0                   // RESET (wipes out anything added during the yield)
/* 118 */     }
```

**What to say:**

- **Read-then-reset.** Line 114 reads the coin box, line 115 yields, line 117 sets it to 0.
- Any purchase that added money during the yield is wiped out by the reset. That's where the vanished dollars come from.

### Output to show

**output-unsync-run1.txt (final report)**

```text
[RestockDriver] loaded 0 trays of 50
[SingleBuyer] sold 6463 items
[ComboBuyer] sold 6568 combos = 19704 items
[Auditor] all workers done — final report
  invariant 1 (stock): expected=-16167 actual=0 drift=16167 MISMATCH
  invariant 2 (money): expected=3925050c actual=3670200c drift=-254850c MISMATCH
```

**What it shows:**

- The buyers' tallies add up to 26,167 items sold, from a machine that held 10,000 and was never restocked. So expected stock is −16,167, which is impossible. The extra sales are decrements that got overwritten, so the same items sold more than once.
- Money: the buyers paid $39,250.50 by their own count, but only $36,702.00 is in the machine plus collected cash. **$2,548.50 vanished**, mostly in the collector's read-then-reset gap.

**output-unsync-negative-stock.txt (an Auditor snapshot mid-run)**

```text
[Auditor] snapshot 6: stock=473 coinBox=299955900c cash=120900c
[Auditor] snapshot 7: stock=-3 coinBox=348987300c cash=120900c
[Auditor] snapshot 8: stock=504 coinBox=400811550c cash=120900c
```

**What it shows:**

- Stock at **−3**: the check-then-act bug caught in the act. A vending machine can't hold negative items.

- **Repeatable (10 runs each, Apple M2):** debug lost about $798,198 per run on average (6.59% of revenue); release lost about $2,174 (0.84%). Both builds broke 10 out of 10 times. Release loses less because it finishes in about 0.2 s and most loop passes find the stock empty, so there are fewer real purchases to collide. The optimizer doesn't fix the race.
- **ThreadSanitizer** (Apple's race detector) reports 13 data races in unsync mode.
- Live: `swift run -c release ThreadLab unsync`. The numbers will differ from the file, which is the point: nondeterministic, but still MISMATCH.

### If you're asked

<details>
<summary><b>Is sched_yield() cheating?</b></summary>

No. It widens a gap that's already there. Remove it and the race is rarer, not gone; ThreadSanitizer still flags it.

</details>

<details>
<summary><b>Why does release lose so much less?</b></summary>

It runs about 0.2 s and sells about 173,000 items vs. about 8.1 million in debug, so far fewer chances to collide.

</details>

<details>
<summary><b>Lost update vs. check-then-act?</b></summary>

Lost update writes back a stale value (a wrong but believable number). Check-then-act acts on a condition that's no longer true (an impossible number, negative stock).

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