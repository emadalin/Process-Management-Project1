import Foundation

// =============================================================================
// HeapDemo.swift — ARC, and the one way it can be defeated · Member 3
//
// Demo section 3. Fill in runHeapDemo(); the stub below is scaffolding, not a
// design. Checklist (teamTask.md):
//
//   [ ] Show allocation -> use -> drop the last reference -> deinit output
//       (the deinit prints already live on Song/Playlist in Models.swift)
//   [ ] LEAKY version: a LeakySong whose `delegate` is STRONG. Set the playlist
//       to nil and show that NO deinit prints. That silence is the evidence.
//   [ ] FIXED version: the real Song's `weak var delegate`. Every deinit prints.
//   [ ] Memory Graph Debugger screenshot of the leak (-> Member 5)
//   [ ] Explain ARC, strong / weak / unowned, and why PlaybackDelegate has to
//       be `: AnyObject` for `weak` to compile at all
//   [ ] Explain what the deinit output proves (ARC released the object) and
//       what it does NOT prove (that the process's memory number went down —
//       libmalloc usually keeps freed space to reuse)
//
// LeakySong belongs in THIS file, not Models.swift: the shared model is the
// correct one, and the broken copy is a prop for this section.
//
// Watch for: `weak` alone does not make the leak. The cycle needs both
// directions strong. Build the leak deliberately, and use `var` locals set to
// nil (not just scope exit) so the demo controls exactly when release happens.
// =============================================================================

func runHeapDemo() {
    DemoLog.begin("HEAP DEMO")
    DemoLog.say("not implemented yet — Member 3 owns HeapDemo.swift")
}
