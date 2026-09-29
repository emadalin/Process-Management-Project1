import Foundation

// =============================================================================
// CompareDemo.swift — two ways to fill an array · Member 5
//
// Demo sections 4 (comparison half) and 5 (IDE tools). Fill in
// runCompareDemo(); the stub below is scaffolding, not a design. Checklist
// (teamTask.md):
//
//   [ ] A: build samples: [Float] by appending one at a time
//   [ ] B: the same work, with samples.reserveCapacity(total) first
//   [ ] Verify samplesA == samplesB — same results, or the comparison is void
//   [ ] Log every capacity change in A (that count IS the reallocation count);
//       print final capacity vs count for both
//   [ ] Large input (5-50 million samples), `swift run -c release`, 5 runs each
//   [ ] Instruments -> Allocations on A and B, with screenshots
//   [ ] Write-up: Xcode version, built-in vs separate tool, what each shows and
//       what it can't establish
//
// Label every claim (shared rules). The honest split:
//
//   MEASURED   reallocation count, final capacity vs count, total bytes
//              allocated and allocation count from Instruments
//   INFERRED   that A's peak memory is higher — during each regrowth the old
//              and new storage both exist while elements are copied, but we
//              are reasoning about it, not watching it
//   NOT OURS   the exact growth factor. Swift doesn't promise one. Report what
//              you observed and say that's what it is.
//
// Two traps: debug builds make this measurement meaningless, so use release.
// And faster is not the same as less memory — don't let a timing number stand
// in for an allocation number.
// =============================================================================

func runCompareDemo() {
    DemoLog.begin("MEMORY COMPARISON")
    DemoLog.say("not implemented yet — Member 5 owns CompareDemo.swift")
}
