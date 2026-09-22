import Foundation

// =============================================================================
// Section 3 — the four worker thread bodies (Part B) · Member 3
//
// These four functions are the "distinct task" requirement from Part A. Each one
// becomes the body of one named Thread (see startWorker in Harness.swift), and
// each hits the shared VendingMachine in a genuinely different way:
//
//   SingleBuyer     one item at a time         -> lost-update race
//   ComboBuyer      three items at a time      -> check-then-act race (negative stock)
//   RestockDriver   adds stock back            -> lost-update race in reverse
//   CashCollector   empties the coin box       -> money-loss race across two counters
//
// They are four different tasks, not four copies of one, and that is on purpose:
// different access patterns produce different FAILURE MODES, which is what makes
// the unsync output interesting rather than just "a number is a bit off."
//
// Shape shared by all four:
//   1. count into a LOCAL var (untouched by other threads, no contention)
//   2. run the loop with no printing inside it
//   3. publish the local to the shared tally store ONCE, at the end
//   4. print one summary line
//
// Each worker counts into a local, then publishes once at the end. Prints stay
// OUT of the loops: printing inside serializes the threads on stdout and hides
// the very race we're demonstrating.
//
// Why the same function serves both modes: the `safety` parameter picks Unsafe
// or Safe methods per call. One code path, two behaviors — so nobody can claim
// the sync run "passed" because it was secretly doing less work.
//
// The `sched_yield()` in the not-ready branch is placeholder busywork ONLY — it
// is not the read -> sched_yield() -> write pattern from Member 3's checklist.
// That one goes INSIDE the VendingMachine methods, between the read and the
// write. Don't copy it from here.
// =============================================================================

/// Buys one item per iteration. The simplest possible consumer, so it isolates
/// the plain read-modify-write race with nothing else mixed in.
func runSingleBuyer(_ machine: VendingMachine, _ safety: Safety, _ tallies: WorkerTallies) {
    var itemsBought = 0
    for _ in 0..<Config.buyerIterations {
        if Config.realWorkerBodiesReady {
            // The one line where unsync and sync actually diverge.
            let sold = (safety == .unsafe) ? machine.buyOneUnsafe() : machine.buyOneSafe()
            // Only count a sale the machine said it made — a refused purchase
            // (stock exhausted) must not inflate the Auditor's expected totals.
            if sold { itemsBought += 1 }
        } else {
            sched_yield()
        }
    }
    // Publish once, after the loop. During the loop this count was private to
    // this thread, so the race being demonstrated is purely the machine's.
    tallies.publish { $0.singleItemsSold = itemsBought }
    print("[SingleBuyer] sold \(itemsBought) items")
}

/// Buys a combo (comboSize items) per iteration. Different from SingleBuyer in
/// the way that matters: it CHECKS stock, then ACTS on it. Unsynchronized, that
/// gap is what lets stock go negative.
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
    // Convert purchases to ITEMS. The invariants are stated in items, and a
    // combo moves comboSize of them — conflating the two units was an early bug.
    let items = combosBought * machine.comboSize
    // Both fields written in one publish() call, so the Auditor can never see
    // purchases updated without the matching item count.
    tallies.publish {
        $0.comboPurchases = combosBought
        $0.comboItemsSold = items
    }
    print("[ComboBuyer] sold \(combosBought) combos = \(items) items")
}

/// Pushes stock back up. A producer against the two consumers above, which is
/// what keeps the run interesting: without it the buyers would drain stock early
/// and then spend the rest of the run failing their guard, racing over nothing.
func runRestockDriver(_ machine: VendingMachine, _ safety: Safety, _ tallies: WorkerTallies) {
    var traysLoaded = 0
    for _ in 0..<Config.restockIterations {
        if Config.realWorkerBodiesReady {
            // restock*() returns false when stock is still above the threshold,
            // so most passes legitimately do nothing.
            let loaded = (safety == .unsafe) ? machine.restockUnsafe() : machine.restockSafe()
            if loaded { traysLoaded += 1 }
        } else {
            sched_yield()
        }
    }
    // Trays actually LOADED, not passes attempted — invariant 1 multiplies this
    // by restockTraySize, so counting attempts here would break the math.
    tallies.publish { $0.restockPasses = traysLoaded }
    print("[RestockDriver] loaded \(traysLoaded) trays of \(machine.restockTraySize)")
}

/// Empties the coin box into the banked total. The only worker that touches the
/// money counters together, and the only reason invariant 2 can fail.
///
/// Far fewer iterations than the others (Config.collectorIterations) on purpose:
/// collection is a rare, heavyweight event in a real machine, and each unsafe
/// pass can erase a large amount of concurrently-added cash — a handful of
/// collections is enough to blow invariant 2 wide open.
func runCashCollector(_ machine: VendingMachine, _ safety: Safety, _ tallies: WorkerTallies) {
    var collections = 0
    for _ in 0..<Config.collectorIterations {
        if Config.realWorkerBodiesReady {
            // No Bool here: collecting always "succeeds", even if the box was
            // empty. There is no guard to fail.
            if safety == .unsafe { machine.collectCashUnsafe() } else { machine.collectCashSafe() }
            collections += 1
        } else {
            sched_yield()
        }
    }
    tallies.publish { $0.cashCollections = collections }
    print("[CashCollector] emptied the coin box \(collections) times")
}
