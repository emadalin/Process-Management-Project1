import Foundation

// =============================================================================
// Section 2 — Thread Creation Harness (Part A) · Member 2
//
// Everything here is about *creating and coordinating* threads. The shared-state
// logic lives in VendingMachine.swift (Members 3 and 4).
//
// Part A's requirements, all answered in this file:
//   5+ Thread objects       -> runVendingDemo starts five
//   each one named          -> startWorker sets thread.name
//   start/work/finish shown -> startWorker's bracketing prints
//   main waits for all      -> DispatchGroup, since Thread has no join()
//
// Member 2 also owns main.swift, which holds nothing but the CLI mode switch —
// top-level statements are only legal in that file, so it stays thin and calls
// into the run functions below.
// =============================================================================

// MARK: - Configuration
//
// These live inside a type, not at file scope: in Swift 6 top-level `let`s in
// main.swift are implicitly @MainActor-isolated, which our Thread closures
// cannot touch. Keeping them in an enum here sidesteps that entirely and gives
// every member one place to tune numbers.

enum Config {
    /// Flip to `true` once Members 3 and 4 have implemented the VendingMachine
    /// methods. Until then the workers spin without touching shared state, so
    /// the harness itself (naming, QoS, DispatchGroup) can be tested end to end
    /// without tripping their `fatalError` placeholders.
    static let realWorkerBodiesReady = true

    /// VendingMachine doesn't expose its starting stock after init, and the
    /// Auditor needs it for invariant 1 — so we hold the value here and
    /// construct the machine with it explicitly.
    static let startingStock = 10_000

    // Buyers and the restocker run the same number of passes on purpose: a
    // restocker that finishes early leaves the buyers failing their stock check
    // for the rest of the run, which makes the race boring.
    //
    // Retuned by Member 3 from 10_000: at that size the run finished inside one
    // auditSnapshotInterval (so no mid-run snapshots), and RestockDriver used up
    // its cheap no-op passes before stock ever fell below the threshold, so
    // `unsync` never restocked. At 4_000_000 the run still takes under a second,
    // restocking happens, and snapshots sometimes catch stock negative.
    //
    // The count is not cosmetic: a race needs enough overlapping attempts to be
    // visible at all.
    static let buyerIterations = 4_000_000
    static let restockIterations = 4_000_000
    static let collectorIterations = 200   // deliberately tiny — see runCashCollector

    static let auditSnapshotInterval = 0.25 // Member 4's knob
}

/// Which set of VendingMachine methods a worker should call. Passing this as a
/// parameter is what lets one worker implementation serve both modes, and lets
/// `all` run unsync and sync back to back in one process.
enum Safety {
    case unsafe   // unsync mode — Member 3's methods
    case safe     // sync mode   — Member 4's methods
}

// MARK: - The harness itself
//
// Foundation's `Thread` has no join(), so a DispatchGroup stands in as a latch:
// enter() increments a counter, leave() decrements it, wait() blocks until it
// reaches zero. Where pthreads or Java would join each thread individually, the
// macOS answer is to wait on a count reaching zero.

/// Creates, names, prioritizes and starts one worker thread, and registers it
/// with `group` so the main thread can wait for it. One helper for all five, so
/// naming, QoS and the enter/leave pairing can't be got wrong per-thread.
func startWorker(_ name: String,
                 group: DispatchGroup,
                 qos: QualityOfService = .default,
                 task: @escaping @Sendable () -> Void) {
    // enter() must happen BEFORE start(), on THIS thread. If it went inside the
    // closure, main could reach wait() before the thread body ran, see a count
    // of zero, and return immediately — an intermittent bug that would look like
    // "the program sometimes exits early for no reason."
    group.enter()

    // Thread{} creates it suspended; nothing runs until start(). The closure
    // captures machine/tallies by reference — that shared capture is how five
    // threads end up on one object.
    let thread = Thread {
        print("[\(name)] started")
        task()
        print("[\(name)] finished")
        group.leave()   // unconditional and last — a missed leave() hangs main forever
    }

    thread.name = name              // Part A requirement; also shows in the debugger
    thread.qualityOfService = qos   // MUST be set before start(); ignored afterwards
    thread.start()
}

// MARK: - Modes

/// Starts the standard five named workers against `machine` and blocks until
/// every one of them has finished. This is the shape both unsync and sync use —
/// same threads, same coordination, only the methods they call differ.
///
/// A fresh machine and tallies per call, so `all` gives sync a clean slate.
func runVendingDemo(_ safety: Safety, skipWait: Bool) {
    let machine = VendingMachine(startingStock: Config.startingStock)
    let tallies = WorkerTallies()

    // Two latches: the Auditor waits on the first, main waits on both. They must
    // be separate — the Auditor's job is to wait for the workers, so if it were
    // in their group that group could never empty. Self-deadlock.
    let workerGroup = DispatchGroup()
    let auditorGroup = DispatchGroup()

    // The five threads of Part A: four do work, the fifth observes.
    startWorker("SingleBuyer", group: workerGroup) { runSingleBuyer(machine, safety, tallies) }
    startWorker("ComboBuyer", group: workerGroup) { runComboBuyer(machine, safety, tallies) }
    startWorker("RestockDriver", group: workerGroup) { runRestockDriver(machine, safety, tallies) }
    startWorker("CashCollector", group: workerGroup) { runCashCollector(machine, safety, tallies) }
    startWorker("Auditor", group: auditorGroup) {
        runAuditor(machine, tallies: tallies, waitingOn: workerGroup)
    }

    // Skipping the waits lets main fall off the end, exiting the process and
    // killing the still-running threads — so the "finished" lines never print.
    // That's the live proof that wait() is doing real work.
    if skipWait {
        print(">>> --no-wait: main is NOT waiting. Expect missing 'finished' lines.")
        return
    }

    workerGroup.wait()    // until all four workers have left
    auditorGroup.wait()   // then until the Auditor has reported
}

/// Part B first half: five threads, no locking. Expect MISMATCH.
func runUnsynchronized(skipWait: Bool) {
    print("\n=== UNSYNCHRONIZED RUN ===")
    runVendingDemo(.unsafe, skipWait: skipWait)
    print("=== UNSYNCHRONIZED RUN COMPLETE ===")
}

/// Part B second half: identical work under NSLock. Expect OK, every time.
func runSynchronized(skipWait: Bool) {
    print("\n=== SYNCHRONIZED RUN ===")
    runVendingDemo(.safe, skipWait: skipWait)
    print("=== SYNCHRONIZED RUN COMPLETE ===")
}

/// Warns that unsync/sync will report all-zero tallies while the VendingMachine
/// methods are still unimplemented. Lives here rather than in main.swift so that
/// file stays nothing but the mode switch.
func warnIfWorkerBodiesNotReady(mode: String) {
    guard !Config.realWorkerBodiesReady,
          mode == "unsync" || mode == "sync" || mode == "all" else { return }
    print("""
        NOTE: VendingMachine methods are not implemented yet, so the workers spin \
        without touching shared state and every tally reads 0. Set \
        Config.realWorkerBodiesReady = true once Members 3 and 4 have landed theirs.
        """)
}

// MARK: - Priority mode banner
//
// Part C itself belongs to Member 5 in PriorityTest.swift — including its own
// thread creation, since their racers need the "never set qualityOfService at
// all" case that startWorker can't express (its qos parameter defaults to
// .default, which is still an explicit assignment). This wrapper only supplies
// the banner pair, which is Member 2's to own.
//
// Note: --no-wait applies to unsync/sync only. PriorityTest.run() does its own
// group.wait() internally, so there is nothing here to skip.
func runPriorityMode() {
    print("\n=== PRIORITY TEST ===")
    runPriorityTest()
    print("=== PRIORITY TEST COMPLETE ===")
}
