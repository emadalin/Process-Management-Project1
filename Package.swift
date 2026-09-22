// swift-tools-version: 6.0
//
// Swift Package Manager manifest — the build recipe for the whole project.
//
// Why 6.0 matters for a threading demo: tools version 6.0 turns on the Swift 6
// language mode, where the compiler *checks* concurrency at compile time. Any
// value shared across threads must be `Sendable`, or the build fails. That is
// why VendingMachine, WorkerTallies and the PriorityTest helper classes are all
// marked `@unchecked Sendable` — we are explicitly telling the compiler "we take
// responsibility for thread safety here," which is exactly the promise the
// unsync mode deliberately breaks.
//
// Build/run from Terminal:
//   swift run ThreadLab all                 (debug)
//   swift run -c release ThreadLab all      (optimized)
//   swift run --sanitize=thread ThreadLab unsync   (ThreadSanitizer)
import PackageDescription

let package = Package(
    name: "ThreadLab",
    // macOS 13 is the floor for the Foundation/Dispatch APIs we use
    // (Thread, DispatchGroup, NSLock, NSCondition, QualityOfService).
    platforms: [.macOS(.v13)],
    targets: [
        // One executable target = one module. Everything in Sources/ThreadLab
        // can see everything else with no `import`, which is why main.swift can
        // call runUnsynchronized() without importing Harness.swift.
        .executableTarget(
            name: "ThreadLab",
            path: "Sources/ThreadLab"
        )
    ]
)
