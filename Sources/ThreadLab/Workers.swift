import Foundation

// =============================================================================
// Section 3 — the four worker thread bodies (Part B) · Member 3
//
// Each worker counts into a local, then publishes once at the end. Prints stay
// OUT of the loops: printing inside serializes the threads on stdout and hides
// the very race we're demonstrating.
//
// The `sched_yield()` in the not-ready branch is placeholder busywork ONLY — it
// is not the read -> sched_yield() -> write pattern from Member 3's checklist.
// That one goes INSIDE the VendingMachine methods, between the read and the
// write. Don't copy it from here.
// =============================================================================

func runSingleBuyer(_ machine: VendingMachine, _ safety: Safety, _ tallies: WorkerTallies) {
    var itemsBought = 0
    for _ in 0..<Config.buyerIterations {
        if Config.realWorkerBodiesReady {
            let sold = (safety == .unsafe) ? machine.buyOneUnsafe() : machine.buyOneSafe()
            if sold { itemsBought += 1 }
        } else {
            sched_yield()
        }
    }
    tallies.publish { $0.singleItemsSold = itemsBought }
    print("[SingleBuyer] sold \(itemsBought) items")
}

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
    let items = combosBought * machine.comboSize
    tallies.publish {
        $0.comboPurchases = combosBought
        $0.comboItemsSold = items
    }
    print("[ComboBuyer] sold \(combosBought) combos = \(items) items")
}

func runRestockDriver(_ machine: VendingMachine, _ safety: Safety, _ tallies: WorkerTallies) {
    var traysLoaded = 0
    for _ in 0..<Config.restockIterations {
        if Config.realWorkerBodiesReady {
            let loaded = (safety == .unsafe) ? machine.restockUnsafe() : machine.restockSafe()
            if loaded { traysLoaded += 1 }
        } else {
            sched_yield()
        }
    }
    tallies.publish { $0.restockPasses = traysLoaded }
    print("[RestockDriver] loaded \(traysLoaded) trays of \(machine.restockTraySize)")
}

func runCashCollector(_ machine: VendingMachine, _ safety: Safety, _ tallies: WorkerTallies) {
    var collections = 0
    for _ in 0..<Config.collectorIterations {
        if Config.realWorkerBodiesReady {
            if safety == .unsafe { machine.collectCashUnsafe() } else { machine.collectCashSafe() }
            collections += 1
        } else {
            sched_yield()
        }
    }
    tallies.publish { $0.cashCollections = collections }
    print("[CashCollector] emptied the coin box \(collections) times")
}
