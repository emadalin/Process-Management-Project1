import Foundation

// =============================================================================
// Tally store — shared by Members 2, 3 and 4
//
// Section 1 of the task file: "the Auditor uses the tallies to compute the
// expected totals." A tally that stays a local `var` dies with its thread, so
// each worker publishes ONCE, after its loop is finished. The work itself still
// counts into an untouched local, so there is no contention during the run and
// the tally is still genuinely private while the race is happening.
//
// PRESENTATION NOTE — why this file exists at all:
// The whole demo rests on comparing EXPECTED vs. ACTUAL. "Actual" is whatever
// the VendingMachine's counters ended up holding. "Expected" has to be computed
// from what the workers *believe* they did — how many items each one sold, how
// many trays it loaded. Those beliefs live in each worker's own stack, so we
// need one agreed place to collect them where the Auditor can read them back.
// That place is this class.
//
// The subtle point worth saying out loud in the demo: this store is ALWAYS
// locked, in both unsync and sync mode. We are not cheating the experiment. The
// race we are demonstrating is on the VendingMachine's shared counters, not on
// the bookkeeping. If the tallies themselves were racy we could not trust the
// "expected" number, and the invariant check would prove nothing.
// =============================================================================

/// A plain value type (struct = copied, not shared) holding one immutable-ish
/// picture of what the four workers reported. Copying it out of the lock is what
/// lets the Auditor read a consistent set of numbers without holding the lock
/// while it prints.
struct TallySnapshot {
    var singleItemsSold = 0
    var comboPurchases = 0
    var comboItemsSold = 0      // comboPurchases * comboSize — invariants need ITEMS, not purchases
    var restockPasses = 0        // trays actually loaded (restockUnsafe/Safe return Bool), not passes attempted
    var cashCollections = 0

    /// Both invariants are stated in items, so single sales and combo sales have
    /// to be added in the same unit. This is where a combo of 3 becomes 3 items.
    var totalItemsSold: Int { singleItemsSold + comboItemsSold }
}

/// Thread-safe box around one TallySnapshot.
///
/// `final class` (not struct) because every worker thread must see the SAME
/// instance — reference semantics are the point. `@unchecked Sendable` is our
/// promise to the Swift 6 compiler that the internal lock makes cross-thread
/// sharing safe; unlike VendingMachine, here the promise is actually kept.
final class WorkerTallies: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot = TallySnapshot()

    /// Called exactly once per worker, after its loop ends.
    ///
    /// Taking a closure instead of exposing setters means the caller can update
    /// several fields (ComboBuyer writes two) inside ONE critical section, so
    /// the Auditor can never catch the snapshot half-updated. `defer` guarantees
    /// the unlock runs even if the closure throws or returns early — the classic
    /// way to make sure a lock is never leaked.
    func publish(_ mutate: (inout TallySnapshot) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        mutate(&snapshot)
    }

    /// Locked read. Returns a COPY (struct semantics), so the Auditor can take
    /// its time formatting the report without holding the lock or risking the
    /// numbers shifting underneath it mid-sentence.
    var current: TallySnapshot {
        lock.lock()
        defer { lock.unlock() }
        return snapshot
    }
}
