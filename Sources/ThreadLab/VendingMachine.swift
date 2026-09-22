import Foundation

// =============================================================================
// VendingMachine — THE shared resource (Part B) · Members 3 and 4
//
// This is the heart of the whole assignment. Every one of the four worker
// threads calls into this one object, so this is where "threads share the
// process's memory" stops being a definition and starts being a bug.
//
// Deliberate design: every operation exists TWICE.
//   *Unsafe methods (Member 3) — no lock. The race.
//   *Safe   methods (Member 4) — same logic, wrapped in one NSLock. The fix.
// Same checks, same arithmetic, same return values. The ONLY difference is the
// lock. That is what makes the unsync-vs-sync comparison honest: if the two
// versions did different work, a difference in output would prove nothing.
//
// Which set gets called is decided at runtime by the `Safety` enum, so the demo
// can show both from a single binary in a single run.
// =============================================================================

/// The shared resource for Sections 3 and 4 of the demo (Part B).
///
/// `@unchecked Sendable`: we're telling the Swift 6 compiler "trust us, we
/// handle thread safety ourselves" so this instance can be captured by
/// multiple `Thread` closures. In `unsync` mode we deliberately don't
/// actually handle it — that's the bug we're demonstrating.
///
/// Worth stating in the demo: the compiler would normally REFUSE to let a
/// mutable class be captured by several threads. `@unchecked` is the escape
/// hatch that lets us opt out of that check. Swift 6 can't stop us from writing
/// a race — it can only stop us from writing one *by accident*.
final class VendingMachine: @unchecked Sendable {

    // MARK: - Shared state (Section 1 — the three counters everything races on)
    //
    // `var` + shared by five threads = the only ingredients a data race needs.
    // Note none of these is an "unusual" type: Int increments look atomic in
    // source, but `x += 1` compiles to load / add / store, and the scheduler can
    // preempt between any two of those machine instructions.

    var itemsInStock: Int          // inventory — buyers decrement, restocker increments
    var coinBoxCents: Int          // money sitting in the machine, emptied by the collector
    var cashCollectedCents: Int    // money already banked, only ever grows

    // MARK: - Configuration
    // Agreed shape, not final values — adjust together if the demo needs different numbers.
    //
    // All `let`: immutable after init, so they are safe to read from any thread
    // without a lock. Only the three `var`s above can race.

    let itemPriceCents: Int      // price of one item, in cents (integers avoid float rounding noise)
    let comboSize: Int           // items per combo purchase — makes ComboBuyer a genuinely different task
    let restockThreshold: Int    // restocker only acts when stock drops below this
    let restockTraySize: Int     // items added per tray loaded

    // MARK: - Synchronization (Member 4 wires this up in the Safe methods below)
    //
    // ONE lock for the whole object, not one per counter. That matters: a
    // purchase touches itemsInStock AND coinBoxCents together, and cash
    // collection touches coinBoxCents AND cashCollectedCents together. Separate
    // locks would let another thread observe the machine halfway through a
    // transaction — the counters would each be individually "safe" while the
    // invariants across them still broke.

    private let lock = NSLock()

    init(startingStock: Int = 10_000,
         itemPriceCents: Int = 150,
         comboSize: Int = 3,
         restockThreshold: Int = 500,
         restockTraySize: Int = 50) {
        self.itemsInStock = startingStock
        self.coinBoxCents = 0
        self.cashCollectedCents = 0
        self.itemPriceCents = itemPriceCents
        self.comboSize = comboSize
        self.restockThreshold = restockThreshold
        self.restockTraySize = restockTraySize
    }

    // MARK: - Unsynchronized methods (Member 3, Part B first half)
    //
    // The pattern in all four: read -> sched_yield() -> write.
    //
    // sched_yield() asks the kernel to hand the CPU to another runnable thread
    // right now. Putting it BETWEEN the read and the write widens the window in
    // which another thread can slip in with stale data. Say this clearly in the
    // demo: the yield does not CREATE the bug — remove it and the race is still
    // there, it just surfaces rarely and unpredictably. It makes an intermittent
    // bug reproducible, which is the difference between a demo and a coin flip.
    //
    // No printing in these methods on purpose: print() takes a lock on stdout,
    // which would serialize the threads and accidentally hide the very race we
    // are trying to show.

    /// If stock > 0, take 1 item and add its price to the coin box.
    ///
    /// The classic LOST UPDATE. Two threads both read stock = 100, both compute
    /// 99, both store 99 — two items sold, stock dropped by one. Multiply that by
    /// four million iterations and the drift is enormous.
    @discardableResult
    func buyOneUnsafe() -> Bool {
        guard itemsInStock > 0 else { return false }
        let currentStock = itemsInStock    // READ
        sched_yield()                      // widen the timing window (exposes the bug, doesn't create it)
        itemsInStock = currentStock - 1    // WRITE (may overwrite another thread's update)
        coinBoxCents += itemPriceCents     // also not atomic
        return true
    }

    /// If stock >= comboSize, take comboSize items and add comboSize x price.
    ///
    /// The classic CHECK-THEN-ACT (TOCTOU) bug. The guard was true when we looked,
    /// but the world changed before we acted on it. This is what drives stock
    /// NEGATIVE in the output — a vending machine that sold items it never had.
    /// That negative number is the single most convincing line in the unsync run.
    @discardableResult
    func buyComboUnsafe() -> Bool {
        guard itemsInStock >= comboSize else { return false }  // CHECK
        sched_yield()                                          // widen the check-then-act gap
        itemsInStock -= comboSize                              // ACT (stock can go negative if another thread already passed the check)
        coinBoxCents += comboSize * itemPriceCents
        return true
    }

    /// When stock drops below restockThreshold, load a tray of restockTraySize.
    /// Returns whether a tray was actually loaded, so callers (RestockDriver)
    /// can tally trays loaded instead of passes attempted.
    ///
    /// Lost update again, but in the other direction: a tray the restocker
    /// counted as loaded can be erased by a concurrent write, so the Auditor's
    /// expected stock ends up HIGHER than reality — inventory that was paid for
    /// and never appeared.
    @discardableResult
    func restockUnsafe() -> Bool {
        guard itemsInStock < restockThreshold else { return false }
        let currentStock = itemsInStock            // READ
        sched_yield()                              // widen the window (another restock landing here gets overwritten)
        itemsInStock = currentStock + restockTraySize  // WRITE
        return true
    }

    /// Read coinBoxCents, add it to cashCollectedCents, reset the box to 0.
    ///
    /// The money-losing one, and the reason invariant 2 fails. This is a
    /// read-modify-RESET across two counters: any purchase that lands in the gap
    /// adds cash to the coin box that the `= 0` then throws away — banked in
    /// neither place. Cash simply evaporates.
    func collectCashUnsafe() {
        let collected = coinBoxCents       // READ
        sched_yield()                      // widen the window (a purchase landing here gets erased below)
        cashCollectedCents += collected
        coinBoxCents = 0                   // RESET (wipes out anything added during the yield)
    }

    // MARK: - Synchronized methods (Member 4, Part B second half)
    //
    // lock.lock() + defer { lock.unlock() }, identical logic to the Unsafe
    // versions above — same checks, same math, just guarded. NSLock is not
    // recursive (locking twice on one thread deadlocks) and must be unlocked
    // on the same thread that locked it, so each method takes the lock once.
    //
    // What the lock actually buys us, in the assignment's vocabulary:
    //   MUTUAL EXCLUSION — yes. One thread at a time inside the critical section,
    //     so read-modify-write becomes effectively atomic and check-then-act is
    //     safe: nothing can change between the guard and the subtraction.
    //   ORDERING between threads — no. NSLock says nothing about WHICH thread
    //     wins the lock next. Run sync mode twice and the per-thread sold counts
    //     differ; only the TOTALS are guaranteed to be consistent. Never claim
    //     the lock makes the program deterministic — it makes it *correct*.
    //
    // Note the yields are gone. Not because they would break correctness (they
    // wouldn't — the lock is held across them), but because they are no longer
    // needed: there is nothing left to expose.

    /// Safe counterpart of buyOneUnsafe().
    @discardableResult
    func buyOneSafe() -> Bool {
        lock.lock()
        defer { lock.unlock() }            // runs on EVERY exit path, including the early `return false`
        guard itemsInStock > 0 else { return false }
        itemsInStock -= 1
        coinBoxCents += itemPriceCents     // both counters updated inside one critical section
        return true
    }

    /// Safe counterpart of buyComboUnsafe().
    /// The guard and the subtraction are now in the same critical section, so
    /// the check-then-act gap is closed and stock can never go negative.
    @discardableResult
    func buyComboSafe() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard itemsInStock >= comboSize else { return false }
        itemsInStock -= comboSize
        coinBoxCents += comboSize * itemPriceCents
        return true
    }

    /// Safe counterpart of restockUnsafe().
    /// `itemsInStock += restockTraySize` reads and writes in one critical
    /// section, so no tray can be overwritten by a concurrent update.
    @discardableResult
    func restockSafe() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard itemsInStock < restockThreshold else { return false }
        itemsInStock += restockTraySize
        return true
    }

    /// Safe counterpart of collectCashUnsafe().
    /// Read, zero, and bank all happen with no window in between, so every cent
    /// that enters the coin box is banked exactly once.
    func collectCashSafe() {
        lock.lock()
        defer { lock.unlock() }
        let collected = coinBoxCents
        coinBoxCents = 0
        cashCollectedCents += collected
    }

    /// Reads all three counters under the lock, for the Auditor's mid-run
    /// snapshots. Reading the properties directly while workers are writing
    /// is itself a data race, even in sync mode (ThreadSanitizer flagged it).
    ///
    /// Good story for the demo: our first sync run was NOT clean under
    /// ThreadSanitizer, and the culprit wasn't a missing lock on a write — it was
    /// an unlocked READ in the observer. An unsynchronized read racing a
    /// synchronized write is still undefined behavior. Returning all three values
    /// in one tuple, taken under one lock acquisition, also means the snapshot is
    /// internally consistent rather than three counters sampled at three moments.
    func snapshot() -> (stock: Int, coinBox: Int, cash: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (itemsInStock, coinBoxCents, cashCollectedCents)
    }
}
