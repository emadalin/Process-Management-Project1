import Foundation

// =============================================================================
// Tally store — shared by Members 2, 3 and 4
//
// Section 1 of the task file: "the Auditor uses the tallies to compute the
// expected totals." A tally that stays a local `var` dies with its thread, so
// each worker publishes ONCE, after its loop is finished. The work itself still
// counts into an untouched local, so there is no contention during the run and
// the tally is still genuinely private while the race is happening.
// =============================================================================

struct TallySnapshot {
    var singleItemsSold = 0
    var comboPurchases = 0
    var comboItemsSold = 0      // comboPurchases * comboSize — invariants need ITEMS, not purchases
    var restockPasses = 0        // trays actually loaded (restockUnsafe/Safe return Bool), not passes attempted
    var cashCollections = 0

    var totalItemsSold: Int { singleItemsSold + comboItemsSold }
}

final class WorkerTallies: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot = TallySnapshot()

    func publish(_ mutate: (inout TallySnapshot) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        mutate(&snapshot)
    }

    var current: TallySnapshot {
        lock.lock()
        defer { lock.unlock() }
        return snapshot
    }
}
