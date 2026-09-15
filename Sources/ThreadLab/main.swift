import Foundation

// =============================================================================
// main.swift — the CLI mode switch, and nothing else · Member 2
//
// Top-level statements are legal ONLY in a file named main.swift; every other
// file in an executable target may contain declarations only. That is the entire
// reason this file exists.
//
//   Harness.swift       Member 2   Config, Safety, startWorker, the run functions
//   Workers.swift       Member 3   the four worker thread bodies
//   Auditor.swift       Member 4   the Auditor thread and the invariant report
//   PriorityTest.swift  Member 5   the PickerRobot racers
//   Tallies.swift       shared     the tally store the Auditor reads
//   VendingMachine.swift  M3 + M4  the shared resource
//
// All one module (ThreadLab), so these files see each other with no imports.
// =============================================================================

let arguments = CommandLine.arguments.dropFirst()

/// Demo switch for the "does group.wait() actually block?" experiment — lets us
/// show threads being killed when main exits, without editing the source live.
let skipWait = arguments.contains("--no-wait")
let mode = arguments.first(where: { !$0.hasPrefix("--") }) ?? "all"

warnIfWorkerBodiesNotReady(mode: mode)

switch mode {
case "unsync":
    runUnsynchronized(skipWait: skipWait)
case "sync":
    runSynchronized(skipWait: skipWait)
case "priority":
    runPriorityMode()
case "all":
    runUnsynchronized(skipWait: skipWait)
    runSynchronized(skipWait: skipWait)
    runPriorityMode()
default:
    print("usage: ThreadLab [unsync|sync|priority|all] [--no-wait]")
    exit(1)
}
