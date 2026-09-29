import Foundation

// =============================================================================
// VendingMachine — THE shared resource (Part B) · Members 3 and 4
//
// Every worker thread calls into this one object, so this is where "threads
// share the process's memory" turns into a bug.
//
// Every operation exists twice: *Unsafe (Member 3, no lock — the race) and
// *Safe (Member 4, same logic under one NSLock — the fix). Same checks, same
// math, same return values; the lock is the only difference. That is what makes
// the unsync-vs-sync comparison honest. The `Safety` enum picks which set runs.
// =============================================================================

/// The shared resource for Sections 3 and 4 of the demo (Part B).
///
/// `@unchecked Sendable`: we're telling the Swift 6 compiler "trust us, we
/// handle thread safety ourselves" so this instance can be captured by
/// multiple `Thread` closures. In `unsync` mode we deliberately don't
/// actually handle it — that's the bug we're demonstrating. Swift 6 can stop us
/// writing a race by accident, not on purpose.
final class VendingMachine: @unchecked Sendable {

    // MARK: - Shared state (Section 1 — the three counters everything races on)
    //
    // `x += 1` looks atomic in source but compiles to load / add / store, and
    // the scheduler can preempt between any two of those instructions.

    var itemsInStock: Int          // inventory — buyers decrement, restocker increments
    var coinBoxCents: Int          // money in the machine, emptied by the collector
    var cashCollectedCents: Int    // money already banked

    // MARK: - Configuration
    // Agreed shape, not final values — adjust together if the demo needs different numbers.
    // All `let`, so they're safe to read unlocked; only the three vars above can race.

    let itemPriceCents: Int      // whole cents, so totals compare exactly
    let comboSize: Int           // items per combo — what makes ComboBuyer a distinct task
    let restockThreshold: Int    // restocker only acts below this
    let restockTraySize: Int     // items per tray loaded

    // MARK: - Synchronization (Member 4 wires this up in the Safe methods below)
    //
    // ONE lock for the whole object, not one per counter: a purchase touches
    // stock and the coin box together, and collection touches both money
    // counters. Per-counter locks would let a thread see a half-done transaction.

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
    // All four follow read -> sched_yield() -> write. The yield hands the CPU to
    // another thread mid-operation, widening the window for a stale write. It
    // EXPOSES the race, it doesn't create it — remove it and the bug is rarer,
    // not gone. No prints in here: print() locks stdout and would serialize the
    // threads, hiding the race.

    /// If stock > 0, take 1 item and add its price to the coin box.
    /// LOST UPDATE: two threads read 100, both write 99 — two sold, stock down one.
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
    /// CHECK-THEN-ACT: the guard was true when we looked, but the world moved.
    /// This is what drives stock negative — the machine selling items it lacks.
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
    /// Lost update in reverse: an overwritten tray means stock that was counted
    /// but never appeared.
    @discardableResult
    func restockUnsafe() -> Bool {
        guard itemsInStock < restockThreshold else { return false }
        let currentStock = itemsInStock            // READ
        sched_yield()                              // widen the window (another restock landing here gets overwritten)
        itemsInStock = currentStock + restockTraySize  // WRITE
        return true
    }

    /// Read coinBoxCents, add it to cashCollectedCents, reset the box to 0.
    /// Why invariant 2 fails: a purchase landing in the gap adds cash that the
    /// `= 0` then discards, so it is banked nowhere. Money simply vanishes.
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
    // What the lock buys, in the brief's terms: MUTUAL EXCLUSION yes — one
    // thread inside at a time, so read-modify-write is effectively atomic and
    // check-then-act is safe. ORDERING between threads NO — NSLock says nothing
    // about who wins it next, so per-thread counts still vary run to run. The
    // lock makes the program correct, not deterministic.

    /// Safe counterpart of buyOneUnsafe().
    @discardableResult
    func buyOneSafe() -> Bool {
        lock.lock()
        defer { lock.unlock() }            // runs on every exit, including the early return
        guard itemsInStock > 0 else { return false }
        itemsInStock -= 1
        coinBoxCents += itemPriceCents     // both counters updated in one critical section
        return true
    }

    /// Safe counterpart of buyComboUnsafe().
    /// Guard and subtraction are now in one critical section, so the
    /// check-then-act gap is closed and stock can't go negative.
    @discardableResult
    func buyComboSafe() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard itemsInStock >= comboSize else { return false }
        itemsInStock -= comboSize
        coinBoxCents += comboSize * itemPriceCents
        return true
    }

    /// Safe counterpart of restockUnsafe(). No tray can be overwritten.
    @discardableResult
    func restockSafe() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard itemsInStock < restockThreshold else { return false }
        itemsInStock += restockTraySize
        return true
    }

    /// Safe counterpart of collectCashUnsafe(). Every cent is banked exactly once.
    func collectCashSafe() {
        lock.lock()
        defer { lock.unlock() }
        let collected = coinBoxCents
        coinBoxCents = 0
        cashCollectedCents += collected
    }

    /// Reads all three counters under the lock, for the Auditor's mid-run
    /// snapshots. Reading the properties directly while workers are writing
    /// is itself a data race, even in sync mode (ThreadSanitizer flagged it) —
    /// an unlocked read racing a locked write is still undefined behavior.
    /// One tuple under one acquisition also keeps the three values consistent.
    func snapshot() -> (stock: Int, coinBox: Int, cash: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (itemsInStock, coinBoxCents, cashCollectedCents)
    }
}
