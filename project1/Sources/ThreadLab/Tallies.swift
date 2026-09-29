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
// Note this store is locked in BOTH modes. That isn't cheating: the race we are
// demonstrating is on the VendingMachine's counters, not on the bookkeeping. If
// the tallies were racy, "expected" would be untrustworthy and the invariant
// check would prove nothing.
// =============================================================================

/// One picture of what the four workers reported. A struct, so reading it out
/// of the lock hands back a copy the Auditor can use without holding the lock.
struct TallySnapshot {
    var singleItemsSold = 0
    var comboPurchases = 0
    var comboItemsSold = 0      // comboPurchases * comboSize — invariants need ITEMS, not purchases
    var restockPasses = 0        // trays actually loaded (restockUnsafe/Safe return Bool), not passes attempted
    var cashCollections = 0

    /// Both invariants are stated in items, so a combo of 3 counts as 3 here.
    var totalItemsSold: Int { singleItemsSold + comboItemsSold }
}

/// Thread-safe box around one TallySnapshot. A class, because every worker must
/// see the same instance; @unchecked Sendable, and here the lock keeps the promise.
final class WorkerTallies: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot = TallySnapshot()

    /// Called once per worker, after its loop. Takes a closure so a caller can
    /// update several fields in one critical section (ComboBuyer writes two).
    func publish(_ mutate: (inout TallySnapshot) -> Void) {
        lock.lock()
        defer { lock.unlock() }   // runs on every exit path, so the lock is never leaked
        mutate(&snapshot)
    }

    /// Locked read, returning a copy.
    var current: TallySnapshot {
        lock.lock()
        defer { lock.unlock() }
        return snapshot
    }
}
