# Documentation Sources Used

Owner: Member 1 (Sarah Rae). Canvas deliverable 5.

Built from what is actually cited in our code and write-ups, then confirmed by each member.
Stephen's and Calli's own entries are the only ones still outstanding; everything below is
confirmed.

## Swift language and standard library

| Source | Used for | Used by |
|---|---|---|
| *The Swift Programming Language* — "Automatic Reference Counting" | strong / `weak` / `unowned`, reference counting, retain cycles, why `deinit` timing is deterministic | Stephen, Sarah |
| *The Swift Programming Language* — "Structures and Classes" | value vs reference semantics, identity, why `Song` had to be a class | Sarah |
| *The Swift Programming Language* — "Memory Safety" | exclusive access to memory; background for the shared-model decisions | Sarah |
| Swift standard library — `Array` | copy-on-write, `capacity` vs `count`, `reserveCapacity(_:)`, and the fact that the growth strategy is **unspecified** | Georgia |
| Swift standard library — `ContiguousArray`, `withUnsafeBufferPointer(_:)` | reasoning about where element storage actually lives | Calli |
| Swift Evolution SE-0412 / Swift 6 concurrency notes — `nonisolated(unsafe)` | why `DemoLog`'s mutable global needs it, and what it switches off | Sarah |

## Apple platform documentation

| Source | Used for | Used by |
|---|---|---|
| Apple Developer Documentation — `InputStream` (`read(_:maxLength:)`) | chunked reads, the meaning of the return value, and that `0` means end and `< 0` means error | Calli |
| Apple Developer Documentation — `FileManager`, `temporaryDirectory` | generating and locating the `.raw` song files | Calli |
| Apple Developer Documentation — `Thread.callStackSymbols` | printing the live call stack at the deepest recursion | Ella |
| Apple Threading Programming Guide | thread stack sizes: 8 MB main thread, 512 KB secondary threads | Ella, Sarah |
| Apple Developer Documentation — "Gathering information about memory use" | what RSS and memory footprint actually measure | Georgia, Sarah |
| Xcode Help — Memory Graph Debugger | finding retain cycles and inspecting who references what | Georgia |
| Instruments Help — Allocations instrument | allocation counts and total bytes | Georgia |

## Command-line tools (man pages)

| Source | Used for |
|---|---|
| `man malloc`, `man malloc_zone_malloc` | libmalloc behaviour: free-list reuse, why freed memory is usually not returned to the OS |
| `man leaks` | leak detection from the command line |
| `man heap` | per-process heap contents by class |
| `man vmmap` | virtual memory regions, and how pages differ from allocations |
| `man footprint` | process memory footprint as macOS accounts for it |
| `/usr/bin/time -l` | max RSS, and why it is page-granular rather than object-granular |
| `man leaks` | `--atExit` and `--outputGraph` to save a `.memgraph` that Xcode's Memory Graph viewer opens |
| `xcrun xctrace help record` | recording the Instruments Allocations template from the terminal |
| `man codesign` | re-signing the release binary with `get-task-allow` so Instruments can attach |

## AI assistants

Commits where an assistant helped carry a `Co-Authored-By: Claude …` line in `git log`.

| Tool | Used for | Used by |
|---|---|---|
| Claude Code (Claude Sonnet 5) | Implementing `StackDemo.swift` — the recursive merge sort trace, the `Thread.callStackSymbols` dump, `Stack<Song>` — and drafting the stack section of the README | Ella |
| Claude Code (Claude Opus 5.5) | Finding and fixing the early `deinit Playlist 'Road Trip'` in the stack demo, regenerating `output-stack-run1.txt`, the steps for capturing the Xcode call-stack screenshot, and committing it | Ella |
| Claude Code (Claude Opus 5.5) | Recording the Instruments Allocations traces and the `leaks` memory graph, guiding the Xcode/Instruments screenshots, re-running the comparison measurements, and drafting `docs/compare-results.md` and the README comparison and IDE tools sections | Georgia |
| Claude (claude.ai and Claude Code) | The project debrief and task split; scaffolding the Swift package and `Models.swift`; drafting the section 1 and 7 write-ups and the README; the demo slide deck; and the study and rehearsal materials | Sarah Rae |
| Claude Code (Claude Opus 5.5) | Implementing `BufferDemo.swift` — `.raw` song generation, chunked playback through one reused 4096-byte buffer, the FNV-1a checksum, the deliberate `buffer[0..<n]` bug and the read-error case — and correcting two claims in the buffer write-up (with Sarah Rae's OK) | Calli |

## Still to add

- [x] **Ella** — anything used for merge sort, recursion depth, or the breakpoint/call-stack view: nothing beyond Claude Code (table above) and the two Apple entries already listed
- [ ] **Stephen** — anything used for delegate patterns or closure capture semantics
- [ ] **Calli** — anything used for stream buffering or checksums
- [x] **Georgia** — the Apple entries above plus `leaks`, `xctrace` and `codesign` man pages; Claude Code in the table above
- [ ] **Stephen and Calli** — AI assistants used, and for what. Everyone else's are in the table
      above. Project 1 disclosed this in its README under "AI tools and outside sources"; we
      should match that.
