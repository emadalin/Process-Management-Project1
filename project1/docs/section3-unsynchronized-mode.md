# Demo Section 3: Unsynchronized Mode (Part B, first half) (5 min)

Owner: Member 3 (Ella). Presented at rehearsal by Sarah Rae (Members 1/5 split Sections 2 and 3 between them — Sarah Rae takes this one, Calli takes Section 2 — per the team's updated cross-assignment table in Section 6 of the task file, which superseded the original per-Member-number swap once it turned out Members 1 and 5 are the same two people).

**One-sentence version:** every Unsafe method in `VendingMachine.swift` does its read, its `sched_yield()`, and its write as three separate, interruptible steps — the scheduler is free to run another thread in between, and that gap is the entire bug.

---

## 1. The shape of the bug, once, so it doesn't need repeating per method

`x += 1` (or any read-modify-write) is not one CPU instruction. It's three:
1. **READ** the current value into a register.
2. **MODIFY** it.
3. **WRITE** it back.

Preemption can land between any of those steps. If another thread also reads, modifies, and writes the same variable while we're paused, one of the two updates gets silently overwritten — a **lost update**. `sched_yield()` doesn't create that gap; the gap exists in *every* unsynchronized read-modify-write. `sched_yield()` just asks the scheduler to run something else *right now*, which turns a gap that might be a few nanoseconds (and only occasionally hit) into one that (almost) always gets hit. **Talking point:** "If someone asks whether `sched_yield()` is cheating — no. Removing it would make the bug rarer, not impossible. TSan will still catch it with `sched_yield()` removed; we just wouldn't see it as reliably in five minutes of demo time."

---

## 2. Method-by-method: exactly where the gap is

### `buyOneUnsafe()` — [VendingMachine.swift:48-57](../Sources/ThreadLab/VendingMachine.swift#L48-L57)
```swift
guard itemsInStock > 0 else { return false }
let currentStock = itemsInStock    // READ
sched_yield()                      // widen the timing window (exposes the bug, doesn't create it)
itemsInStock = currentStock - 1    // WRITE (may overwrite another thread's update)
coinBoxCents += itemPriceCents     // also not atomic
```
- **The gap:** between the READ on line 52 and the WRITE on line 54. `currentStock` is a snapshot; the WRITE throws that snapshot back at `itemsInStock` no matter what happened to it in between.
- **The failure:** two purchases land in that window → both compute `currentStock - 1` from the *same* starting number → the second WRITE clobbers the first. One sale's decrement vanishes even though the buyer got charged and the item was (logically) taken.
- **Bonus gap:** `coinBoxCents += itemPriceCents` on line 55 has no `sched_yield()` around it at all, but it's still a read-modify-write on shared state — it doesn't need help to race, it's just less likely to get hit in a short demo run. Good answer if asked "is that line safe?": no, nothing here is safe, we only widened the window on the parts we wanted to *guarantee* show up.

### `buyComboUnsafe()` — [VendingMachine.swift:59-67](../Sources/ThreadLab/VendingMachine.swift#L59-L67)
```swift
guard itemsInStock >= comboSize else { return false }  // CHECK
sched_yield()                                          // widen the check-then-act gap
itemsInStock -= comboSize                              // ACT (stock can go negative if another thread already passed the check)
coinBoxCents += comboSize * itemPriceCents
```
- **The gap:** this one is **check-then-act**, not read-modify-write. The CHECK (line 62) and the ACT (line 64) are separated by a `sched_yield()`. Nothing re-validates the check after waking back up.
- **The failure:** two threads (in our design, most realistically `SingleBuyer` and `ComboBuyer` overlapping, since each named worker is a single thread) can both pass the check while stock is borderline, both yield, and both then subtract from whatever `itemsInStock` happens to be *now* — which can walk it below zero. We captured this live: `output-unsync-negative-stock.txt` has an Auditor snapshot reading `stock=-3`.
- **Talking point if asked "how is this different from `buyOneUnsafe`'s bug?":** `buyOneUnsafe` loses an update (wrong number, but plausible-looking). `buyComboUnsafe` oversells (an *impossible* number — negative stock — which is why the task table calls this one out as the visibly worse bug).

### `restockUnsafe()` — [VendingMachine.swift:69-79](../Sources/ThreadLab/VendingMachine.swift#L69-L79)
```swift
guard itemsInStock < restockThreshold else { return false }
let currentStock = itemsInStock            // READ
sched_yield()                              // widen the window (another restock landing here gets overwritten)
itemsInStock = currentStock + restockTraySize  // WRITE
```
- **The gap:** same shape as `buyOneUnsafe` — READ, yield, WRITE, using a stale snapshot.
- **The failure:** if a buyer's decrement lands *during* the yield, the restocker's WRITE overwrites it with `currentStock + 50`, silently erasing whatever the buyer just did. A whole 50-item tray can also just not "count" correctly if two conceptual restocks overlap — in our design there's only one `RestockDriver` thread, so the interesting collision here is specifically restocker-vs-buyer, not restocker-vs-restocker.
- **Evidence:** `output-unsync-ella-run1.txt`/`run2.txt` show hundreds of thousands of trays reported "loaded" by the tally, while invariant 1 (`itemsInStock == startingStock + restocked − sold`, wired up by Georgia in `Auditor.swift` once `restockUnsafe`/`restockSafe` started returning `Bool`) now fails by tens of *millions* — `itemsInStock` sits at `0` while the math says it should be over 40 million. Invariant 2 fails right alongside it, by well over $1M in cents.

### `collectCashUnsafe()` — [VendingMachine.swift:81-86](../Sources/ThreadLab/VendingMachine.swift#L81-L86)
```swift
let collected = coinBoxCents       // READ
sched_yield()                      // widen the window (a purchase landing here gets erased below)
cashCollectedCents += collected
coinBoxCents = 0                   // RESET (wipes out anything added during the yield)
```
- **The gap:** between the READ on the first line and the RESET on the last line. Note there's no guard here — this one always runs its full body.
- **The failure:** this is the "vanished cash" bug specifically. If a buyer's `coinBoxCents += itemPriceCents` executes *during* the yield, that money is real — the buyer already got charged, `coinBoxCents` really did go up — but then `coinBoxCents = 0` throws it away unconditionally, based on the pre-yield `collected` value that never saw it. That cents amount never reaches `cashCollectedCents` either. It's not double-counted, not miscounted — it's just **gone**, permanently, from both places money is supposed to live.
- **Why this is the clean invariant-2 demo:** `itemsSold × price` (computed from private tallies, which are race-free) should equal `coinBoxCents + cashCollectedCents` (the two places money can be). Every captured `unsync` run shows a multi-million-cent negative drift here — money the tallies say was collected but that isn't sitting in either bucket.

---

## 3. If asked to explain the fix without stealing Member 4's section
`NSLock` around each of these bodies (`lock.lock()` / `defer { lock.unlock() }`) turns each method into one atomic critical section — the READ, the yield-widened gap, and the WRITE all happen with no other thread able to touch `itemsInStock`/`coinBoxCents`/`cashCollectedCents` in between. Same logic, same checks, just nobody else allowed in the room while it runs. That's Section 4's material — the point for Section 3 is just: the *bug* is the gap, not the specific numbers, so removing the gap (not changing the math) is what fixes it.

---

## 4. Practice-question answers for this section

**Q3. What exactly goes wrong without synchronization, and why?**
Every Unsafe method does its read (or check) and its write as separate, non-atomic steps. `sched_yield()` between them gives another thread a real chance to run in that gap. Depending on which method, the result is a lost update (`buyOneUnsafe`, `restockUnsafe`), overselling into negative stock (`buyComboUnsafe`), or money that gets read, then erased by an unconditional reset before it's ever counted (`collectCashUnsafe`).

**Q6. What would happen if we removed the lock (i.e., this *is* what happens without it)?**
Exactly what's in `output-unsync-ella-run1.txt`, `run2.txt`, and `output-unsync-negative-stock.txt`: both invariants fail — invariant 1 (stock) off by tens of millions, invariant 2 (money) off by well over $1M in cents — and `itemsInStock` can be observed negative mid-run (`stock=-3`).

**Q9. What is one limitation of our implementation?**
`sched_yield()` is a demo aid, not part of the bug — it just makes a rare-but-real race show up reliably in a few seconds instead of possibly never showing up in a short run. It's honest to say this out loud if asked: TSan (Section 4) still flags every one of these races with `sched_yield()` removed, which is the proof it's not manufacturing anything.

---

## Sources to cite
- Project brief, Section 4.2 (data races are undefined behavior; `sched_yield()` widens, doesn't create, the window) and Section 5 (`sellUnsafe`/`sellSafe` sketch this is modeled on).
- `Sources/ThreadLab/VendingMachine.swift` — the four Unsafe methods.
- `output-unsync-ella-run1.txt`, `output-unsync-ella-run2.txt`, `output-unsync-negative-stock.txt` — captured evidence.
