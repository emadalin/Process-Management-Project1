import Foundation

// =============================================================================
// StackDemo.swift — the call stack, seen from the outside · Member 2
//
// Demo section 2. Fill in runStackDemo(); the stub below is scaffolding, not a
// design. Checklist (teamTask.md):
//
//   [ ] Recursive merge sort of Playlist.sampleEight(), by title or duration
//   [ ] Indented enter/return output with depth:
//           -> mergeSort depth 2 [songs 2...3]
//           <- return  depth 2
//   [ ] Print Thread.callStackSymbols at the DEEPEST call
//   [ ] Xcode breakpoint screenshot of the call-stack view there (-> Member 5)
//   [ ] A small Stack<Song> ("recently played") to contrast with the call stack
//   [ ] Explain: call stack vs Stack<Song>; the [Song] parameter vs the heap
//       buffer behind it vs each Song reference; scope vs lifetime
//   [ ] Explain the deep-recursion risk WITHOUT crashing it: a shuffle that
//       recurses once per song is depth n, not log n. Swift has no recursion
//       limit (Python does) — it just runs off the end of the stack and traps
//       with EXC_BAD_ACCESS. Main thread gets 8 MB, secondary threads 512 KB.
//
// Why merge sort and not the shuffle: depth log2(8) = 3 is readable on one
// screen, and the enter/return pattern is symmetric, so the output makes the
// last-in-first-out shape obvious. Keep the shuffle as the thing you *describe*
// as risky.
// =============================================================================

func runStackDemo() {
    DemoLog.begin("STACK DEMO")
    DemoLog.say("not implemented yet — Member 2 owns StackDemo.swift")
}
