import Foundation

// =============================================================================
// Section 4 — the Auditor thread (Part B, second half) · Member 4
//
// The fifth thread, and the one that satisfies "each thread does a DIFFERENT,
// meaningful task." The other four do work; this one observes and judges. It is
// also what turns the demo from "look, numbers" into "look, provably wrong
// numbers" — without an independent checker, nobody in the audience can tell a
// racy total from a correct one just by looking at it.
//
// Two jobs:
//   1. DURING the run — periodic snapshots, so the audience sees the shared
//      state moving in real time (and, in unsync mode, occasionally catches
//      itemsInStock at a negative value, which is the money shot).
//   2. AFTER the run — compute what the totals SHOULD be from the workers' own
//      tallies, compare against what the machine actually holds, and print the
//      drift.
//
// The same code runs in both modes. We do not have a "lenient" auditor for the
// unsync run: identical arithmetic, identical checks, and the only thing that
// changes is whether the numbers line up.
// =============================================================================

/// The fifth distinct task: coordination, not more counting. Takes periodic
/// snapshots while the other four run, then reports expected vs. actual once
/// they finish.
///
/// - Parameter workerGroup: the latch the FOUR workers report into. The Auditor
///   is registered with a *separate* group (see runVendingDemo), because a
///   thread cannot wait on a group it is itself a member of — it would be
///   waiting for itself and hang forever.
func runAuditor(_ machine: VendingMachine,
                tallies: WorkerTallies,
                waitingOn workerGroup: DispatchGroup) {
    // wait(timeout:) instead of a bare wait() — that's what lets us snapshot
    // DURING the run and still stop exactly when the workers are done.
    //
    // The loop condition is the trick worth pointing out: wait(timeout:) returns
    // .timedOut if the interval elapsed with work still outstanding, or .success
    // the moment the group empties. So "keep snapshotting" and "stop as soon as
    // the last worker finishes" are the same single expression — no polling
    // flag, no sleep-then-check, and no risk of one last snapshot printing after
    // the final report.
    var snapshots = 0
    while workerGroup.wait(timeout: .now() + Config.auditSnapshotInterval) == .timedOut {
        snapshots += 1
        // Locked read: the workers are still writing, so reading the
        // properties directly here would be a data race of its own.
        // (ThreadSanitizer caught exactly this in our first sync run — an
        // unlocked read racing a locked write is still undefined behavior.)
        let s = machine.snapshot()
        print("[Auditor] snapshot \(snapshots): stock=\(s.stock) "
              + "coinBox=\(s.coinBox)c cash=\(s.cash)c")
    }

    // Past this point every worker has returned, so nothing is mutating the
    // machine any more and the numbers below are stable.
    let t = tallies.current
    print("[Auditor] all workers done — final report")
    print("  tallies: single=\(t.singleItemsSold) items, "
          + "combo=\(t.comboPurchases) purchases/\(t.comboItemsSold) items, "
          + "restock=\(t.restockPasses) passes, collections=\(t.cashCollections)")

    // -------------------------------------------------------------------------
    // Invariant 1: itemsInStock == startingStock + restocked - sold
    //
    // Conservation of inventory. Every item is either still in the machine or was
    // sold; trays only ever add. If this drifts, updates were lost — two threads
    // wrote back over each other, so work the workers counted never landed.
    // Drift can go either way: negative if sales were lost, positive if trays were.
    // -------------------------------------------------------------------------
    // restockSafe/Unsafe now return whether a tray was actually loaded, so
    // t.restockPasses is trays loaded (not passes attempted) — see Workers.swift.
    let restocked = t.restockPasses * machine.restockTraySize
    let expectedStock = Config.startingStock + restocked - t.totalItemsSold
    let actualStock = machine.itemsInStock
    let stockDrift = actualStock - expectedStock
    print("  invariant 1 (stock): expected=\(expectedStock) actual=\(actualStock) "
          + "drift=\(stockDrift) \(stockDrift == 0 ? "OK" : "MISMATCH")")

    // -------------------------------------------------------------------------
    // Invariant 2: itemsSold * price == coinBoxCents + cashCollectedCents
    //
    // Conservation of money. Every cent taken in is either still in the coin box
    // or already banked; nothing else can consume it. Drift here is almost always
    // NEGATIVE — collectCashUnsafe()'s `coinBoxCents = 0` erases purchases that
    // landed during its read-modify-reset window, so the cash is banked nowhere.
    // Money that simply vanishes is the most intuitive failure to explain.
    // -------------------------------------------------------------------------
    let expectedMoney = t.totalItemsSold * machine.itemPriceCents
    let actualMoney = machine.coinBoxCents + machine.cashCollectedCents
    let drift = actualMoney - expectedMoney
    print("  invariant 2 (money): expected=\(expectedMoney)c actual=\(actualMoney)c "
          + "drift=\(drift)c \(drift == 0 ? "OK" : "MISMATCH")")
}
