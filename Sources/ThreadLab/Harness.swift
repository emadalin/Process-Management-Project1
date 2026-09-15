import Foundation

// =============================================================================
// Section 2 — Thread Creation Harness (Part A) · Member 2
//
// Everything here is about *creating and coordinating* threads. The shared-state
// logic lives in VendingMachine.swift (Members 3 and 4).
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
    static let realWorkerBodiesReady = false

    /// VendingMachine doesn't expose its starting stock after init, and the
    /// Auditor needs it for invariant 1 — so we hold the value here and
    /// construct the machine with it explicitly.
    static let startingStock = 10_000

    // Buyers and the restocker run the same number of passes on purpose: a
    // restocker that finishes early leaves the buyers failing their stock check
    // for the rest of the run, which makes the race boring. Re-tune these WITH
    // Member 3 once the real methods land and we can see actual sell-through.
    static let buyerIterations = 10_000
    static let restockIterations = 10_000
    static let collectorIterations = 200

    static let auditSnapshotInterval = 0.25 // Member 4's knob
}

/// Which set of VendingMachine methods a worker should call.
enum Safety {
    case unsafe   // unsync mode — Member 3's methods
    case safe     // sync mode   — Member 4's methods
}

// MARK: - The harness itself
//
// Foundation's `Thread` has no join(), so a DispatchGroup stands in as a latch:
// enter() increments a counter, leave() decrements it, wait() blocks until it
// reaches zero.

/// Creates, names, prioritizes and starts one worker thread, and registers it
/// with `group` so the main thread can wait for it.
func startWorker(_ name: String,
                 group: DispatchGroup,
                 qos: QualityOfService = .default,
                 task: @escaping @Sendable () -> Void) {
    // enter() must happen BEFORE start(), on THIS thread. If it went inside the
    // closure, main could reach wait() before the thread body ran, see a count
    // of zero, and return immediately.
    group.enter()

    let thread = Thread {
        print("[\(name)] started")
        task()
        print("[\(name)] finished")
        group.leave()   // unconditional and last — a missed leave() hangs main forever
    }

    thread.name = name
    thread.qualityOfService = qos   // MUST be set before start(); ignored afterwards
    thread.start()
}

// MARK: - Modes

/// Starts the standard five named workers against `machine` and blocks until
/// every one of them has finished. This is the shape both unsync and sync use —
/// same threads, same coordination, only the methods they call differ.
///
/// The worker bodies themselves belong to Members 3, 4 and 5 and currently live
/// in main.swift; they move to Workers.swift / Auditor.swift / PriorityTest.swift
/// whenever those members are ready. Same module, so no imports are needed.
func runVendingDemo(_ safety: Safety, skipWait: Bool) {
    let machine = VendingMachine(startingStock: Config.startingStock)
    let tallies = WorkerTallies()

    // Two latches: the Auditor waits on the first, main waits on both.
    let workerGroup = DispatchGroup()
    let auditorGroup = DispatchGroup()

    startWorker("SingleBuyer", group: workerGroup) { runSingleBuyer(machine, safety, tallies) }
    startWorker("ComboBuyer", group: workerGroup) { runComboBuyer(machine, safety, tallies) }
    startWorker("RestockDriver", group: workerGroup) { runRestockDriver(machine, safety, tallies) }
    startWorker("CashCollector", group: workerGroup) { runCashCollector(machine, safety, tallies) }
    startWorker("Auditor", group: auditorGroup) {
        runAuditor(machine, tallies: tallies, waitingOn: workerGroup)
    }

    if skipWait {
        print(">>> --no-wait: main is NOT waiting. Expect missing 'finished' lines.")
        return
    }

    workerGroup.wait()
    auditorGroup.wait()
}

func runUnsynchronized(skipWait: Bool) {
    print("\n=== UNSYNCHRONIZED RUN ===")
    runVendingDemo(.unsafe, skipWait: skipWait)
    print("=== UNSYNCHRONIZED RUN COMPLETE ===")
}

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
// all" case that startWorker can't express. This wrapper only supplies the
// banner pair, which is Member 2's to own.
//
// Note: --no-wait applies to unsync/sync only. PriorityTest.run() does its own
// group.wait() internally, so there is nothing here to skip.
func runPriorityMode() {
    print("\n=== PRIORITY TEST ===")
    runPriorityTest()
    print("=== PRIORITY TEST COMPLETE ===")
}
