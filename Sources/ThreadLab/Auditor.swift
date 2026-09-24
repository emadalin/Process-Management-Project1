import Foundation

// =============================================================================
// Section 4 — the Auditor thread (Part B, second half) · Member 4
//
// The fifth thread, and the one that makes the demo provable: without an
// independent checker you can't tell a racy total from a correct one by eye.
// Two jobs — periodic snapshots DURING the run (which sometimes catch stock
// negative), and an expected-vs-actual report after it. Identical code in both
// modes; only the numbers change.
// =============================================================================

/// The fifth distinct task: coordination, not more counting. Takes periodic
/// snapshots while the other four run, then reports expected vs. actual once
/// they finish.
///
/// - Parameter workerGroup: the latch the four WORKERS report into. The Auditor
///   is in a separate group, because a thread can't wait on a group it belongs
///   to — it would be waiting for itself.
func runAuditor(_ machine: VendingMachine,
                tallies: WorkerTallies,
                waitingOn workerGroup: DispatchGroup) {
    // wait(timeout:) instead of a bare wait() — that's what lets us snapshot
    // DURING the run and still stop exactly when the workers are done. It
    // returns .timedOut while work is outstanding and .success the moment the
    // group empties, so both behaviors are one expression: no polling flag, and
    // no stray snapshot printing after the final report.
    var snapshots = 0
    while workerGroup.wait(timeout: .now() + Config.auditSnapshotInterval) == .timedOut {
        snapshots += 1
        // Locked read: the workers are still writing, so reading the
        // properties directly here would be a data race of its own.
        let s = machine.snapshot()
        print("[Auditor] snapshot \(snapshots): stock=\(s.stock) "
              + "coinBox=\(s.coinBox)c cash=\(s.cash)c")
    }

    // Past here every worker has returned, so these numbers are stable.
    let t = tallies.current
    print("[Auditor] all workers done — final report")
    print("  tallies: single=\(t.singleItemsSold) items, "
          + "combo=\(t.comboPurchases) purchases/\(t.comboItemsSold) items, "
          + "restock=\(t.restockPasses) passes, collections=\(t.cashCollections)")

    // Invariant 1: itemsInStock == startingStock + restocked - sold
    // Conservation of inventory. Drift means updates were lost — either sales or
    // trays that the workers counted but that never landed.
    // restockSafe/Unsafe now return whether a tray was actually loaded, so
    // t.restockPasses is trays loaded (not passes attempted) — see Workers.swift.
    let restocked = t.restockPasses * machine.restockTraySize
    let expectedStock = Config.startingStock + restocked - t.totalItemsSold
    let actualStock = machine.itemsInStock
    let stockDrift = actualStock - expectedStock
    print("  invariant 1 (stock): expected=\(expectedStock) actual=\(actualStock) "
          + "drift=\(stockDrift) \(stockDrift == 0 ? "OK" : "MISMATCH")")

    // Invariant 2: itemsSold * price == coinBoxCents + cashCollectedCents
    // Conservation of money. Drift is usually negative: collectCashUnsafe()'s
    // reset erases purchases made during its window, so that cash is banked nowhere.
    let expectedMoney = t.totalItemsSold * machine.itemPriceCents
    let actualMoney = machine.coinBoxCents + machine.cashCollectedCents
    let drift = actualMoney - expectedMoney
    print("  invariant 2 (money): expected=\(expectedMoney)c actual=\(actualMoney)c "
          + "drift=\(drift)c \(drift == 0 ? "OK" : "MISMATCH")")
}
