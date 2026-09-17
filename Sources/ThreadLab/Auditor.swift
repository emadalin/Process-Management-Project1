import Foundation

// =============================================================================
// Section 4 — the Auditor thread (Part B, second half) · Member 4
// =============================================================================

/// The fifth distinct task: coordination, not more counting. Takes periodic
/// snapshots while the other four run, then reports expected vs. actual once
/// they finish.
func runAuditor(_ machine: VendingMachine,
                tallies: WorkerTallies,
                waitingOn workerGroup: DispatchGroup) {
    // wait(timeout:) instead of a bare wait() — that's what lets us snapshot
    // DURING the run and still stop exactly when the workers are done.
    var snapshots = 0
    while workerGroup.wait(timeout: .now() + Config.auditSnapshotInterval) == .timedOut {
        snapshots += 1
        print("[Auditor] snapshot \(snapshots): stock=\(machine.itemsInStock) "
              + "coinBox=\(machine.coinBoxCents)c cash=\(machine.cashCollectedCents)c")
    }

    let t = tallies.current
    print("[Auditor] all workers done — final report")
    print("  tallies: single=\(t.singleItemsSold) items, "
          + "combo=\(t.comboPurchases) purchases/\(t.comboItemsSold) items, "
          + "restock=\(t.restockPasses) passes, collections=\(t.cashCollections)")

    // Invariant 1: itemsInStock == startingStock + restocked - sold
    // restockSafe/Unsafe now return whether a tray was actually loaded, so
    // t.restockPasses is trays loaded (not passes attempted) — see Workers.swift.
    let restocked = t.restockPasses * machine.restockTraySize
    let expectedStock = Config.startingStock + restocked - t.totalItemsSold
    let actualStock = machine.itemsInStock
    let stockDrift = actualStock - expectedStock
    print("  invariant 1 (stock): expected=\(expectedStock) actual=\(actualStock) "
          + "drift=\(stockDrift) \(stockDrift == 0 ? "OK" : "MISMATCH")")

    // Invariant 2: itemsSold * price == coinBoxCents + cashCollectedCents
    let expectedMoney = t.totalItemsSold * machine.itemPriceCents
    let actualMoney = machine.coinBoxCents + machine.cashCollectedCents
    let drift = actualMoney - expectedMoney
    print("  invariant 2 (money): expected=\(expectedMoney)c actual=\(actualMoney)c "
          + "drift=\(drift)c \(drift == 0 ? "OK" : "MISMATCH")")
}
