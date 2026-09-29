# Demo Section 4: Synchronized Mode & Auditor (Part B, second half) (5 min)

Owner: Member 4 (Georgia). Presented at rehearsal by Stephen.

**One-sentence version:** the Safe methods run the exact same logic as the Unsafe ones from Section 3, just with an `NSLock` held around the whole critical section, and the Auditor's expected-vs-actual report is what turns "the numbers look different" into hard proof.

---

## 1. The Safe methods — identical logic, one lock ([VendingMachine.swift:95-134](../Sources/ThreadLab/VendingMachine.swift#L95-L134))

```swift
@discardableResult
func buyOneSafe() -> Bool {
    lock.lock()
    defer { lock.unlock() }
    guard itemsInStock > 0 else { return false }
    itemsInStock -= 1
    coinBoxCents += itemPriceCents
    return true
}
```
Compare this line-for-line against Member 3's `buyOneUnsafe()`: same guard, same math, same return value. The only two additions are `lock.lock()` at the top and `defer { lock.unlock() }` right after — and the `sched_yield()` calls are simply gone, because there's no longer a gap for another thread to land in. `buyComboSafe()`, `restockSafe()`, and `collectCashSafe()` follow the identical pattern. **Talking point if asked "why does this fix it?":** the bug in Section 3 was never about the *math* being wrong — it was about another thread being able to run *between* steps of the math. `lock.lock()`/`unlock()` makes the whole method one uninterruptible block from every other thread's point of view; nothing else touching `itemsInStock`, `coinBoxCents`, or `cashCollectedCents` can run until this method returns.

**Why `defer`:** `defer { lock.unlock() }` runs no matter how the function exits — including the early `return false` from a failed guard. Without `defer`, that early return would leave the lock held forever, and every other Safe method would block on `lock.lock()` permanently. This is the single most important line to point at if asked to explain the fix.

**One lock, not four:** all four Safe methods share the same `private let lock = NSLock()` ([VendingMachine.swift:27](../Sources/ThreadLab/VendingMachine.swift#L27)) rather than a lock per counter. That's deliberate — a purchase touches `itemsInStock` *and* `coinBoxCents` together, and locking both under one lock means the Auditor never observes a half-finished purchase (item gone, coins not yet added, or vice versa), *as long as the Auditor takes that same lock too* (see Section 5, where ThreadSanitizer caught it not doing so). A separate lock per field would allow more parallelism but reopen exactly that kind of inconsistency, plus adds a lock-ordering deadlock risk the moment any method needs to hold two locks at once. See Section 7's pros/cons notes for the fuller trade-off discussion.

---

## 2. `NSLock` caveats to have ready

- **Not recursive.** If a Safe method ever called another Safe method while still holding the lock (e.g., `buyOneSafe()` calling `restockSafe()` internally), the second `lock.lock()` on the same thread would **deadlock the thread against itself** — `NSLock` doesn't track "I already own this, let me back through." None of our methods do this; each is a single, self-contained critical section.
- **Must be unlocked on the same thread that locked it.** `NSLock` isn't like a semaphore that any thread can signal — the thread that called `lock()` must be the one that calls `unlock()`. Since every `lock()`/`unlock()` pair in our code is inside one function body, running on one thread, this is automatic here, but it's worth knowing as the reason `NSLock` isn't a drop-in substitute for, say, handing a locked resource off between threads.

## 3. Does our lock give mutual exclusion, ordering, or both? (practice question 5)

**Mutual exclusion only.** `lock.lock()` guarantees at most one thread is inside a Safe method at a time — that's the entire promise. It says nothing about *which* waiting thread gets in next; the kernel/runtime picks. If `SingleBuyer`, `ComboBuyer`, and `RestockDriver` are all waiting on the lock, there's no guarantee they get serviced in the order they arrived, or even fairly over time (in principle one could be starved, though that's not something we've observed or specifically tested for). Forcing a turn order would need something with ordering semantics — `NSConditionLock`, described in the optional bonus below, which we didn't implement — not a plain `NSLock`.

## 4. Could this deadlock? (practice question 10)

**Not as designed.** There is exactly one lock. Every Safe method takes it once, does its work, and releases it via `defer` before returning — no Safe method calls another Safe method while holding the lock, so the "lock twice on one thread" self-deadlock described above can't happen with the current code. The other deadlock risk in this whole program is unrelated to locks: a worker that skipped `group.leave()` in the harness would make `group.wait()` block forever (Member 2's Section 2) — that's a hang, not technically a lock deadlock, but it's the other "why would this get stuck" answer worth having ready.

---

## 5. The Auditor thread ([Auditor.swift](../Sources/ThreadLab/Auditor.swift))

The fifth distinct task, and it's coordination, not more counting — the Auditor never changes `itemsInStock`/`coinBoxCents`/`cashCollectedCents`, it only reads them. But reading while other threads write still needs the lock, which is the bug covered below.

**Periodic snapshots, using `wait(timeout:)` instead of a bare `wait()`:**
```swift
var snapshots = 0
while workerGroup.wait(timeout: .now() + Config.auditSnapshotInterval) == .timedOut {
    snapshots += 1
    let s = machine.snapshot()   // locked read, see below
    print("[Auditor] snapshot \(snapshots): stock=\(s.stock) "
          + "coinBox=\(s.coinBox)c cash=\(s.cash)c")
}
```
This is the same `DispatchGroup` mechanism Member 2's section covers, but used differently: instead of one blocking `wait()`, the Auditor loops on `wait(timeout:)`, which returns `.timedOut` if the four workers aren't all done yet (print a snapshot, loop again) or `.success` the instant they are (exit the loop). That's what lets the Auditor watch the shared counters live, *while the race is happening*, instead of only seeing the final state.

**The race ThreadSanitizer found in `sync` mode (and the fix):** the snapshot line originally read the counters directly: `machine.itemsInStock`, `machine.coinBoxCents`, `machine.cashCollectedCents`. The workers write those under the lock, but the Auditor read them *without* it, so a snapshot could land in the middle of a write. That is a data race inside the "safe" mode. Running `swift run --sanitize=thread ThreadLab sync` reported 5 races, all on the snapshot lines, while both invariants still said `OK` (evidence: [`output-tsan-sync-before-fix.txt`](../output-tsan-sync-before-fix.txt)). The fix is a locked read in `VendingMachine` ([VendingMachine.swift:136-143](../Sources/ThreadLab/VendingMachine.swift#L136-L143)):
```swift
func snapshot() -> (stock: Int, coinBox: Int, cash: Int) {
    lock.lock()
    defer { lock.unlock() }
    return (itemsInStock, coinBoxCents, cashCollectedCents)
}
```
It uses the same `lock` as the Safe methods, and it reads all three counters in one locked block, so a snapshot is also internally consistent (never an item gone with its coins not yet added). After the fix, `sync` under ThreadSanitizer reports 0 warnings ([`output-tsan-sync.txt`](../output-tsan-sync.txt), confirmed on 4 runs). `unsync` still reports its 13 races, because the Unsafe methods never take the lock regardless of what the Auditor does.

**Talking points:**
- *"Why did the invariants pass if there was a race?"* The final report only runs after all four workers have finished, so nothing is writing anymore by then. Only the mid-run snapshots were affected. A correct final number does not prove the absence of a race, which is exactly why we ran the sanitizer.
- *"Does a read really need a lock?"* Yes, whenever another thread may be writing at the same time. Mutual exclusion only works if **every** access to the shared data goes through the lock, readers included.
- *"The final report still reads `machine.itemsInStock` directly. Isn't that the same bug?"* No. By then `workerGroup.wait(timeout:)` has returned `.success`, so every writer thread has finished. There is no concurrent writer, so there is no race, and ThreadSanitizer agrees.

**The two invariants, computed after the loop exits ([Auditor.swift:31-46](../Sources/ThreadLab/Auditor.swift#L31-L46)):**
```swift
let restocked = t.restockPasses * machine.restockTraySize
let expectedStock = Config.startingStock + restocked - t.totalItemsSold
let actualStock = machine.itemsInStock
// invariant 1: expectedStock vs actualStock

let expectedMoney = t.totalItemsSold * machine.itemPriceCents
let actualMoney = machine.coinBoxCents + machine.cashCollectedCents
// invariant 2: expectedMoney vs actualMoney
```
Both sides of each comparison come from different places on purpose: the *expected* side is built entirely from the **private tallies** (`t.restockPasses`, `t.totalItemsSold`) — each worker's own race-free count of what it did — while the *actual* side reads the **live shared counters** straight off `machine`. If synchronization is working, those two independently-derived numbers must agree; if it isn't, they drift, and the size of the drift is the proof.

**Invariant 1 depended on Member 3's work:** `t.restockPasses` only means "trays actually loaded" because `restockUnsafe()`/`restockSafe()` return `Bool` (added after the fact — see Section 3's notes) instead of `Void`. Before that, there was no way to tell an attempted restock pass from a successful one, and invariant 1 had to be skipped entirely. Good detail if asked how Sections 3 and 4 depended on each other.

---

## 6. Evidence: `sync` mode matches every time

Verified over 10 release-build runs; every single one reports both invariants `OK` with zero drift. Four representative examples:
```
invariant 1 (stock): expected=513 actual=513 drift=0 OK
invariant 2 (money): expected=1816220550c actual=1816220550c drift=0c OK

invariant 1 (stock): expected=510 actual=510 drift=0 OK
invariant 2 (money): expected=1619218500c actual=1619218500c drift=0c OK

invariant 1 (stock): expected=511 actual=511 drift=0 OK
invariant 2 (money): expected=1714160850c actual=1714160850c drift=0c OK

invariant 1 (stock): expected=515 actual=515 drift=0 OK
invariant 2 (money): expected=1764725250c actual=1764725250c drift=0c OK
```
Full captured run saved at [`output-sync-run1.txt`](../output-sync-run1.txt). Contrast directly against any `output-unsync-*.txt`, where both invariants routinely miss by tens of millions of stock units or over $1M in cents (see Section 3's docs and evidence). Same threads, same work, same tallying — the only variable between the two modes is whether the methods take the lock.

**ThreadSanitizer evidence:**

| Run | TSan warnings | Invariants | File |
|---|---|---|---|
| `unsync` | 13 (all four Unsafe methods) | Both MISMATCH | [`output-tsan-unsync.txt`](../output-tsan-unsync.txt) |
| `sync`, before the snapshot fix | 5 (Auditor snapshot lines only) | Both OK | [`output-tsan-sync-before-fix.txt`](../output-tsan-sync-before-fix.txt) |
| `sync`, after the snapshot fix | **0** (4 runs) | Both OK | [`output-tsan-sync.txt`](../output-tsan-sync.txt) |

---

## 7. Optional bonus: `NSConditionLock` turnstile (not implemented: the team decided to skip it)

`NSLock` gives mutual exclusion, not ordering — Section 3 above. `NSConditionLock` adds a condition value so threads can lock "when condition == N," forcing a specific hand-off order:
```swift
let turnstile = NSConditionLock(condition: 0)
// thread whose turn is `myTurn`:
turnstile.lock(whenCondition: myTurn)
// ... do work ...
turnstile.unlock(withCondition: myTurn + 1)
```
This would be a nice contrast to show live — "here's mutual exclusion (what we built), here's mutual exclusion *plus* ordering (what this adds)" — but it's optional and not required for the invariants to hold, since none of our correctness properties depend on a specific thread ordering.

---

## Sources to cite
- Project brief, Section 4.3 (`NSLock` notes, caveats, `NSConditionLock`).
- `Sources/ThreadLab/VendingMachine.swift` — the four Safe methods and the locked `snapshot()`.
- `Sources/ThreadLab/Auditor.swift` — snapshots and both invariants.
- `output-sync-run1.txt` — captured clean run; any `output-unsync-*.txt` for contrast.
- `output-tsan-unsync.txt`, `output-tsan-sync-before-fix.txt`, `output-tsan-sync.txt` — ThreadSanitizer runs.
