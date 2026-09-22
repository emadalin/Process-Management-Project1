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

**[`VendingMachine.swift`](../../Sources/ThreadLab/VendingMachine.swift#L9-L15) · lines 9–15**

```swift
/*   9 */ final class VendingMachine: @unchecked Sendable {
/*  10 */ 
/*  11 */     // MARK: - Shared state (Section 1 — the three counters everything races on)
/*  12 */ 
/*  13 */     var itemsInStock: Int
/*  14 */     var coinBoxCents: Int
/*  15 */     var cashCollectedCents: Int
```

**What to say:**

- The shared resource: three counters that every worker thread reads and changes.

**[`VendingMachine.swift`](../../Sources/ThreadLab/VendingMachine.swift#L48-L57) · lines 48–57**

```swift
/*  48 */     /// If stock > 0, take 1 item and add its price to the coin box.
/*  49 */     @discardableResult
/*  50 */     func buyOneUnsafe() -> Bool {
/*  51 */         guard itemsInStock > 0 else { return false }
/*  52 */         let currentStock = itemsInStock    // READ
/*  53 */         sched_yield()                      // widen the timing window (exposes the bug, doesn't create it)
/*  54 */         itemsInStock = currentStock - 1    // WRITE (may overwrite another thread's update)
/*  55 */         coinBoxCents += itemPriceCents     // also not atomic
/*  56 */         return true
/*  57 */     }
```

**What to say:**

- **Lost update.** Line 52 reads stock into a local copy. Line 53 yields. Line 54 writes back the copy minus 1.
- If another thread changed the stock during the yield, line 54 overwrites their change with a stale number.
- Line 55 has no yield but is still read-change-write with no lock, so it can lose updates too.

**[`VendingMachine.swift`](../../Sources/ThreadLab/VendingMachine.swift#L59-L67) · lines 59–67**

```swift
/*  59 */     /// If stock >= comboSize, take comboSize items and add comboSize x price.
/*  60 */     @discardableResult
/*  61 */     func buyComboUnsafe() -> Bool {
/*  62 */         guard itemsInStock >= comboSize else { return false }  // CHECK
/*  63 */         sched_yield()                                          // widen the check-then-act gap
/*  64 */         itemsInStock -= comboSize                              // ACT (stock can go negative if another thread already passed the check)
/*  65 */         coinBoxCents += comboSize * itemPriceCents
/*  66 */         return true
/*  67 */     }
```

**What to say:**

- **Check-then-act**, a different bug. Line 62 checks there are at least 3 items, line 63 yields, line 64 subtracts 3.
- Two threads can both pass the check while stock is low, then both subtract, and stock goes **negative**. That's overselling.

**[`VendingMachine.swift`](../../Sources/ThreadLab/VendingMachine.swift#L69-L79) · lines 69–79**

```swift
/*  69 */     /// When stock drops below restockThreshold, load a tray of restockTraySize.
/*  70 */     /// Returns whether a tray was actually loaded, so callers (RestockDriver)
/*  71 */     /// can tally trays loaded instead of passes attempted.
/*  72 */     @discardableResult
/*  73 */     func restockUnsafe() -> Bool {
/*  74 */         guard itemsInStock < restockThreshold else { return false }
/*  75 */         let currentStock = itemsInStock            // READ
/*  76 */         sched_yield()                              // widen the window (another restock landing here gets overwritten)
/*  77 */         itemsInStock = currentStock + restockTraySize  // WRITE
/*  78 */         return true
/*  79 */     }
```

**What to say:**

- Same read-yield-write shape as buyOneUnsafe. A buyer's sale that lands during the yield gets overwritten by old stock + 50.

**[`VendingMachine.swift`](../../Sources/ThreadLab/VendingMachine.swift#L81-L87) · lines 81–87**

```swift
/*  81 */     /// Read coinBoxCents, add it to cashCollectedCents, reset the box to 0.
/*  82 */     func collectCashUnsafe() {
/*  83 */         let collected = coinBoxCents       // READ
/*  84 */         sched_yield()                      // widen the window (a purchase landing here gets erased below)
/*  85 */         cashCollectedCents += collected
/*  86 */         coinBoxCents = 0                   // RESET (wipes out anything added during the yield)
/*  87 */     }
```

**What to say:**

- **Read-then-reset.** Line 83 reads the coin box, line 84 yields, line 86 sets it to 0.
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