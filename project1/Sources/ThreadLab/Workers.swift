import Foundation

// =============================================================================
// Section 3 — the four worker thread bodies (Part B) · Member 3
//
// Part A's "distinct task" requirement. Each becomes one named Thread, and each
// hits the shared machine differently, so each produces a different failure:
//
//   SingleBuyer     one item at a time     -> lost update
//   ComboBuyer      three at a time        -> check-then-act (negative stock)
//   RestockDriver   adds stock back        -> lost update in reverse
//   CashCollector   empties the coin box   -> money lost across two counters
//
// All four: count into a local, loop with no printing, publish once at the end.
// Prints stay OUT of the loops: printing inside serializes the threads on stdout
// and hides the very race we're demonstrating.
//
// The `safety` parameter picks Unsafe or Safe methods, so one implementation
// serves both modes — nobody can claim sync "passed" by doing less work.
//
// The `sched_yield()` in the not-ready branch is placeholder busywork ONLY — it
// is not the read -> sched_yield() -> write pattern from Member 3's checklist.
// That one goes INSIDE the VendingMachine methods, between the read and the
// write. Don't copy it from here.
// =============================================================================

/// Buys one item per iteration — the plain read-modify-write race, isolated.
func runSingleBuyer(_ machine: VendingMachine, _ safety: Safety, _ tallies: WorkerTallies) {
    var itemsBought = 0
    for _ in 0..<Config.buyerIterations {
        if Config.realWorkerBodiesReady {
            // The one line where unsync and sync diverge.
            let sold = (safety == .unsafe) ? machine.buyOneUnsafe() : machine.buyOneSafe()
            if sold { itemsBought += 1 }   // only count sales the machine granted
        } else {
            sched_yield()
        }
    }
    // Published after the loop; private to this thread during it.
    tallies.publish { $0.singleItemsSold = itemsBought }
    print("[SingleBuyer] sold \(itemsBought) items")
}

/// Buys comboSize items per iteration. Unlike SingleBuyer it CHECKS then ACTS,
/// and unsynchronized that gap is what lets stock go negative.
func runComboBuyer(_ machine: VendingMachine, _ safety: Safety, _ tallies: WorkerTallies) {
    var combosBought = 0
    for _ in 0..<Config.buyerIterations {
        if Config.realWorkerBodiesReady {
            let sold = (safety == .unsafe) ? machine.buyComboUnsafe() : machine.buyComboSafe()
            if sold { combosBought += 1 }
        } else {
            sched_yield()
        }
    }
    let items = combosBought * machine.comboSize   // invariants are in items, not purchases
    tallies.publish {                              // both fields in one critical section
        $0.comboPurchases = combosBought
        $0.comboItemsSold = items
    }
    print("[ComboBuyer] sold \(combosBought) combos = \(items) items")
}

/// Pushes stock back up. Without a producer the buyers would drain stock early
/// and spend the rest of the run failing their guard, racing over nothing.
func runRestockDriver(_ machine: VendingMachine, _ safety: Safety, _ tallies: WorkerTallies) {
    var traysLoaded = 0
    for _ in 0..<Config.restockIterations {
        if Config.realWorkerBodiesReady {
            // Returns false while stock is above the threshold, so most passes no-op.
            let loaded = (safety == .unsafe) ? machine.restockUnsafe() : machine.restockSafe()
            if loaded { traysLoaded += 1 }
        } else {
            sched_yield()
        }
    }
    // Trays LOADED, not passes attempted — invariant 1 multiplies this by tray size.
    tallies.publish { $0.restockPasses = traysLoaded }
    print("[RestockDriver] loaded \(traysLoaded) trays of \(machine.restockTraySize)")
}

/// Empties the coin box into the banked total — the only worker touching both
/// money counters, and the only reason invariant 2 can fail.
///
/// Far fewer iterations than the buyers on purpose: each unsafe pass can erase a
/// lot of concurrently-added cash, so a handful is enough to break invariant 2.
func runCashCollector(_ machine: VendingMachine, _ safety: Safety, _ tallies: WorkerTallies) {
    var collections = 0
    for _ in 0..<Config.collectorIterations {
        if Config.realWorkerBodiesReady {
            // No Bool: there's no guard to fail, so collecting always "succeeds".
            if safety == .unsafe { machine.collectCashUnsafe() } else { machine.collectCashSafe() }
            collections += 1
        } else {
            sched_yield()
        }
    }
    tallies.publish { $0.cashCollections = collections }
    print("[CashCollector] emptied the coin box \(collections) times")
}
