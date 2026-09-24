import Foundation

// =============================================================================
// main.swift — the CLI mode switch, and nothing else · Member 2
//
// Top-level statements are legal ONLY in a file named main.swift; every other
// file in an executable target may contain declarations only. That is the entire
// reason this file exists — and why it's the place to start a code walkthrough.
//
//   Harness.swift       Member 2   Config, Safety, startWorker, the run functions
//   Workers.swift       Member 3   the four worker thread bodies
//   Auditor.swift       Member 4   the Auditor thread and the invariant report
//   PriorityTest.swift  Member 5   the PickerRobot racers
//   Tallies.swift       shared     the tally store the Auditor reads
//   VendingMachine.swift  M3 + M4  the shared resource
//
// All one module (ThreadLab), so these files see each other with no imports.
// The split also answers the brief's "not one giant main.swift" requirement and
// let five people work without merge conflicts.
//
//   swift run ThreadLab unsync            Parts A+B, no locking -> MISMATCH
//   swift run ThreadLab sync              Parts A+B, NSLock     -> OK
//   swift run ThreadLab priority          Part C, QoS racers
//   swift run ThreadLab all               all three, in order
//   swift run ThreadLab unsync --no-wait  the "does wait() matter?" experiment
// =============================================================================

// dropFirst() discards argv[0], the executable's own path.
let arguments = CommandLine.arguments.dropFirst()

/// Demo switch for the "does group.wait() actually block?" experiment — lets us
/// show threads being killed when main exits, without editing the source live.
/// When main returns the process exits, and the OS tears down every thread in
/// it, finished or not: threads live and die with their process.
let skipWait = arguments.contains("--no-wait")

/// First non-flag argument. Defaulting to "all" means a bare `swift run` still
/// demonstrates the whole assignment.
let mode = arguments.first(where: { !$0.hasPrefix("--") }) ?? "all"

// No-op now that the worker bodies are ready; kept so a half-finished checkout
// explains itself instead of silently printing zeros.
warnIfWorkerBodiesNotReady(mode: mode)

// Each case is one labeled demonstration from the brief.
switch mode {
case "unsync":
    runUnsynchronized(skipWait: skipWait)
case "sync":
    runSynchronized(skipWait: skipWait)
case "priority":
    runPriorityMode()
case "all":
    // Bug first, then the fix, then the separate scheduling investigation.
    runUnsynchronized(skipWait: skipWait)
    runSynchronized(skipWait: skipWait)
    runPriorityMode()
default:
    print("usage: ThreadLab [unsync|sync|priority|all] [--no-wait]")
    exit(1)   // non-zero: a mistyped mode is a failure, not a silent no-op
}
