import Foundation

// =============================================================================
// Section 2 — Thread Creation Harness (Part A) · Member 2
//
// Everything here is about *creating and coordinating* threads. The shared-state
// logic lives in VendingMachine.swift (Members 3 and 4).
//
// This file answers Part A's four requirements in one place:
//   - 5+ Thread objects           -> runVendingDemo starts exactly five
//   - each one NAMED              -> startWorker sets thread.name
//   - start / work / finish shown -> startWorker prints the bracketing lines
//   - main WAITS for all of them  -> DispatchGroup, since Foundation's Thread
//                                    has no join()
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
//
// `enum` with only static members is the standard Swift idiom for a namespace
// that cannot be instantiated — there is no such thing as "a Config".

enum Config {
    /// Flip to `true` once Members 3 and 4 have implemented the VendingMachine
    /// methods. Until then the workers spin without touching shared state, so
    /// the harness itself (naming, QoS, DispatchGroup) can be tested end to end
    /// without tripping their `fatalError` placeholders.
    ///
    /// Kept in the code as evidence of how the team worked in parallel: Part A
    /// was testable before Part B existed.
    static let realWorkerBodiesReady = true

    /// VendingMachine doesn't expose its starting stock after init, and the
    /// Auditor needs it for invariant 1 — so we hold the value here and
    /// construct the machine with it explicitly.
    static let startingStock = 10_000

    // Buyers and the restocker run the same number of passes on purpose: a
    // restocker that finishes early leaves the buyers failing their stock check
    // for the rest of the run, which makes the race boring.
    //
    // Retuned by Member 3 (from 10_000) once the real methods landed: at 10_000
    // the whole run finished in well under one auditSnapshotInterval, so the
    // Auditor never got to print a mid-run snapshot, and RestockDriver — same
    // iteration count as the buyers, but each unsafe pass is cheap when it
    // no-ops — blew through all its passes before stock ever dropped below
    // restockThreshold, so `unsync` never restocked at all. At 4_000_000 the run
    // takes under a second, restocking actually happens (hundreds of thousands
    // of trays loaded), and snapshots occasionally catch itemsInStock negative
    // (e.g. -3) from the check-then-act race. Flagging for Member 2 to confirm
    // this doesn't fight anything else Section 2 depends on these numbers for.
    //
    // Presentation point: iteration count is not cosmetic. A race needs enough
    // overlapping attempts to be visible at all — this number IS the difference
    // between "no drift, seems fine" and a drift of thousands.
    static let buyerIterations = 4_000_000
    static let restockIterations = 4_000_000
    /// Deliberately tiny next to the buyers — see runCashCollector. A few
    /// collections against millions of purchases is already enough to lose cash.
    static let collectorIterations = 200

    static let auditSnapshotInterval = 0.25 // Member 4's knob
}

/// Which set of VendingMachine methods a worker should call.
///
/// Passing this through as a parameter (instead of, say, compiling two binaries
/// or flipping a global) is what lets ONE worker implementation serve both
/// modes — and lets `all` run unsync and sync back to back in one process.
enum Safety {
    case unsafe   // unsync mode — Member 3's methods
    case safe     // sync mode   — Member 4's methods
}

// MARK: - The harness itself
//
// Foundation's `Thread` has no join(), so a DispatchGroup stands in as a latch:
// enter() increments a counter, leave() decrements it, wait() blocks until it
// reaches zero.
//
// This is a genuine API difference worth naming in the demo. In C/pthreads or
// Java you would call join() on each thread. Foundation's Thread just doesn't
// offer it, so the standard macOS answer is a counting latch from Dispatch.
// Same effect, different shape: we wait on a COUNT reaching zero rather than on
// each thread individually.

/// Creates, names, prioritizes and starts one worker thread, and registers it
/// with `group` so the main thread can wait for it.
///
/// One function for all five threads means naming, QoS and the enter/leave
/// pairing are written once and cannot be got wrong per-thread.
func startWorker(_ name: String,
                 group: DispatchGroup,
                 qos: QualityOfService = .default,
                 task: @escaping @Sendable () -> Void) {
    // enter() must happen BEFORE start(), on THIS thread. If it went inside the
    // closure, main could reach wait() before the thread body ran, see a count
    // of zero, and return immediately.
    //
    // That is a real race in the harness itself, and a good one to mention: the
    // bug would be intermittent and would look like "sometimes the program exits
    // early for no reason."
    group.enter()

    // `Thread { ... }` creates the thread suspended; nothing runs until start().
    // The closure is @Sendable and captures `machine`/`tallies` by reference —
    // that shared capture is exactly how five threads end up on one object.
    let thread = Thread {
        print("[\(name)] started")      // Part A: prove the thread started
        task()                          // Part A: the distinct work
        print("[\(name)] finished")     // Part A: prove it finished
        group.leave()   // unconditional and last — a missed leave() hangs main forever
    }

    thread.name = name              // Part A requirement; also what shows up in the debugger
    thread.qualityOfService = qos   // MUST be set before start(); ignored afterwards
    thread.start()                  // hands the thread to the kernel scheduler
}

// MARK: - Modes

/// Starts the standard five named workers against `machine` and blocks until
/// every one of them has finished. This is the shape both unsync and sync use —
/// same threads, same coordination, only the methods they call differ.
///
/// A fresh VendingMachine and fresh tallies per call, so running `all` gives the
/// sync mode a clean slate rather than inheriting the unsync run's corruption.
func runVendingDemo(_ safety: Safety, skipWait: Bool) {
    let machine = VendingMachine(startingStock: Config.startingStock)
    let tallies = WorkerTallies()

    // Two latches: the Auditor waits on the first, main waits on both.
    //
    // Why two and not one: the Auditor's whole job is to wait for the workers.
    // If it were registered in the same group, that group could never reach zero
    // while the Auditor sat waiting on it — a self-deadlock. Splitting them
    // gives a clean two-stage finish: workers empty workerGroup, the Auditor
    // wakes and reports, then auditorGroup empties and main returns.
    let workerGroup = DispatchGroup()
    let auditorGroup = DispatchGroup()

    // The five threads of Part A. Four do work; the fifth observes.
    startWorker("SingleBuyer", group: workerGroup) { runSingleBuyer(machine, safety, tallies) }
    startWorker("ComboBuyer", group: workerGroup) { runComboBuyer(machine, safety, tallies) }
    startWorker("RestockDriver", group: workerGroup) { runRestockDriver(machine, safety, tallies) }
    startWorker("CashCollector", group: workerGroup) { runCashCollector(machine, safety, tallies) }
    startWorker("Auditor", group: auditorGroup) {
        runAuditor(machine, tallies: tallies, waitingOn: workerGroup)
    }

    // The --no-wait experiment: skip the waits and return straight out of the
    // run function. main.swift then falls off the end and the process exits,
    // taking every still-running thread with it — so the "[X] finished" lines
    // never print. This is the live demonstration that wait() is doing real
    // work, rather than us asserting that it is.
    if skipWait {
        print(">>> --no-wait: main is NOT waiting. Expect missing 'finished' lines.")
        return
    }

    workerGroup.wait()    // block main until all four workers have left the group
    auditorGroup.wait()   // then until the Auditor has printed its report
}

/// Part B, first half: the same five threads with NO locking. Expect mismatches.
func runUnsynchronized(skipWait: Bool) {
    print("\n=== UNSYNCHRONIZED RUN ===")   // banner required by the brief
    runVendingDemo(.unsafe, skipWait: skipWait)
    print("=== UNSYNCHRONIZED RUN COMPLETE ===")
}

/// Part B, second half: identical work, every critical section under NSLock.
/// Expect both invariants to read OK, every single time.
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
// all" case that startWorker can't express. (startWorker's `qos` parameter
// defaults to .default, which is an explicit assignment; Part C specifically
// needs to observe what a thread inherits when nothing is set.)
//
// This wrapper only supplies the banner pair, which is Member 2's to own.
//
// Note: --no-wait applies to unsync/sync only. PriorityTest.run() does its own
// group.wait() internally, so there is nothing here to skip.
func runPriorityMode() {
    print("\n=== PRIORITY TEST ===")
    runPriorityTest()
    print("=== PRIORITY TEST COMPLETE ===")
}
