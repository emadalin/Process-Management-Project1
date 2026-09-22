import Foundation

// =============================================================================
// main.swift — the CLI mode switch, and nothing else · Member 2
//
// Top-level statements are legal ONLY in a file named main.swift; every other
// file in an executable target may contain declarations only. That is the entire
// reason this file exists.
//
// Start the code walkthrough here: this is the program's entry point, and it is
// deliberately short enough to read in one breath. Everything it calls lives in
// exactly one other file, one per team member:
//
//   Harness.swift       Member 2   Config, Safety, startWorker, the run functions
//   Workers.swift       Member 3   the four worker thread bodies
//   Auditor.swift       Member 4   the Auditor thread and the invariant report
//   PriorityTest.swift  Member 5   the PickerRobot racers
//   Tallies.swift       shared     the tally store the Auditor reads
//   VendingMachine.swift  M3 + M4  the shared resource
//
// All one module (ThreadLab), so these files see each other with no imports.
// That split also answers the brief's "multiple types/functions, not one giant
// main.swift" requirement, and it let five people work without merge conflicts.
//
// Usage:
//   swift run ThreadLab unsync      Part A + B, no locking   -> MISMATCH expected
//   swift run ThreadLab sync        Part A + B, NSLock       -> OK expected
//   swift run ThreadLab priority    Part C, QoS racers
//   swift run ThreadLab all         all three, in order
//   swift run ThreadLab unsync --no-wait   the "does wait() matter?" experiment
// =============================================================================

// dropFirst() discards argv[0] — the executable's own path, which every C-family
// program receives as its first argument and which is never a user flag.
let arguments = CommandLine.arguments.dropFirst()

/// Demo switch for the "does group.wait() actually block?" experiment — lets us
/// show threads being killed when main exits, without editing the source live.
///
/// Why it proves something: when main returns, the PROCESS exits, and the OS
/// tears down every thread in it whether or not it has finished. Threads are not
/// independent programs; they live and die with their process. Skipping the
/// waits makes the "[X] finished" lines disappear, which is that fact on screen.
let skipWait = arguments.contains("--no-wait")

/// First non-flag argument is the mode. Defaulting to "all" means a bare
/// `swift run ThreadLab` still demonstrates the whole assignment.
let mode = arguments.first(where: { !$0.hasPrefix("--") }) ?? "all"

// No-op now that Config.realWorkerBodiesReady is true; kept so a half-finished
// checkout explains itself instead of silently printing zeros.
warnIfWorkerBodiesNotReady(mode: mode)

// The mode switch itself. Each case is one labeled demonstration from the brief;
// `all` runs them in assignment order so a single capture covers Parts A, B and C.
switch mode {
case "unsync":
    runUnsynchronized(skipWait: skipWait)
case "sync":
    runSynchronized(skipWait: skipWait)
case "priority":
    runPriorityMode()
case "all":
    // Order matters for the story: show the bug first, then the fix, then the
    // separate scheduling investigation.
    runUnsynchronized(skipWait: skipWait)
    runSynchronized(skipWait: skipWait)
    runPriorityMode()
default:
    print("usage: ThreadLab [unsync|sync|priority|all] [--no-wait]")
    exit(1)   // non-zero status: a mistyped mode is a failure, not a silent no-op
}
