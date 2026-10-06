# Documentation Sources Used

Owner: Member 1 (Sarah Rae). Canvas deliverable 5.

Seeded from what is actually cited in our code and write-ups, so the remaining job is for
each member to **add anything they used that is not already here** rather than start from
nothing. Add your name in the "used by" column if you leaned on an entry.

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

## Still to add

- [ ] **Ella** — anything used for merge sort, recursion depth, or the breakpoint/call-stack view
- [ ] **Stephen** — anything used for delegate patterns or closure capture semantics
- [ ] **Calli** — anything used for stream buffering or checksums
- [ ] **Georgia** — Instruments and Memory Graph walkthroughs, plus whatever she uses for the
      measurement methodology; hers is the longest list and the least filled in
- [ ] **Everyone** — AI assistants used, and for what. Project 1 disclosed this in its README
      under "AI tools and outside sources"; we should match that.
