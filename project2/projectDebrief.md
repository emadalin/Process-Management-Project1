# Project 2 Debrief: Memory Management (Stacks, Heaps, Buffers)

**Team language / OS:** Swift on macOS (same as Project 1)
**Time budget:** ~6 hours total
**Demo:** 30 minutes, whole team, any member can be asked about any part
**Grading focus:** depth of understanding, not just code that runs

---

## 1. The three ideas in plain words

### Stack: the to-do pile for function calls
Every time a function is called, the program puts a "note card" (a **call frame**) on top of a pile. The card holds that function's parameters, its local variables, and where to go back to when it finishes. When the function returns, its card comes off the top. Last in, first out.

- Automatic and very fast
- Small and fixed in size. Main thread gets 8 MB, other threads default to 512 KB
- Too many cards (runaway recursion) = **stack overflow** = crash

### Heap: the storage warehouse
A big area for data that needs to live longer than one function call, or whose size isn't known ahead of time. You ask for space, you get a spot in the warehouse, and you hold onto an **address (reference)** to find it again.

- Flexible and can be large
- Slower than the stack
- Someone has to decide when the space can be reused. In Swift, **ARC** does that

### Buffer: a bucket for moving data in pieces
Not a separate place in memory. It's a **way of using** memory. A buffer is a temporary holding area, like carrying water with a bucket instead of trying to lift the whole lake. You fill it, process it, empty it, and repeat.

- Has a **capacity** (how big the bucket is) and a **count** (how much valid data is in it right now)
- The last fill is usually partial, and that edge case must be handled correctly
- In Swift, a buffer like `[UInt8]` has its storage on the **heap**

### One-sentence version for the demo
> The stack tracks *which functions are running*, the heap holds *data that outlives a single function*, and a buffer is *a chunk of memory used to move data in pieces*.

---

## 2. How Swift + macOS actually does it

### Who is responsible for what
| Layer | What it does |
|---|---|
| **Our code** | Chooses `struct` (value type) vs `class` (reference type); chooses strong / `weak` / `unowned` references; chooses buffer sizes |
| **Swift runtime + compiler** | ARC: inserts retain/release automatically, frees an object when its last strong reference goes away, runs `deinit` |
| **libmalloc (Apple's allocator)** | Hands out heap memory; keeps freed memory to reuse instead of always returning it to the OS |
| **macOS kernel** | Gives the process virtual memory pages; creates each thread's stack |

**Do not say "the system handles memory."** The rubric explicitly calls that weak.

### Value types vs reference types
- **Value types** (`struct`, `enum`, `Int`, `Array`, `String`): copying makes an independent copy
- **Reference types** (`class`, closures, `actor`): copying copies the *reference*; both variables point to the same object on the heap

### Gotchas the instructor is likely to ask about
1. **A local variable is not always "on the stack."** A `class` local is a reference on the stack pointing to an object on the heap. An `Array` is a small struct whose elements live in a heap buffer (with copy-on-write).
2. **Leaving a function does not necessarily free memory.** If something else still holds a strong reference, the object lives on.
3. **ARC is not garbage collection.** ARC frees an object *immediately* when its strong count hits 0, so `deinit` timing is predictable. A garbage collector frees memory whenever it decides to run.
4. **Freeing an object does not always shrink the process's memory number.** libmalloc usually keeps that space for reuse.
5. **Swift has no recursion limit** (Python does). Deep recursion just crashes with `EXC_BAD_ACCESS`.
6. **The call stack is not a `Stack<T>` we write ourselves.** One is managed by the CPU/runtime for function calls; the other is just a data structure in our program (and its storage is likely on the heap).

### The main heap risk in Swift: retain cycles
If object A strongly holds B and B strongly holds A, neither count ever reaches 0, so neither is freed. That's a **memory leak**. Common causes: parent/child objects, or a closure that captures `self`.
Fix: make one side `weak` (or `unowned`). A `deinit` that prints makes this very easy to show.

---

## 3. What the project requires (checklist)

### Part 1: Stack demo
- [ ] Nested function calls (small bounded recursion is OK)
- [ ] Labeled output showing call order and return order
- [ ] Show the call stack: print `Thread.callStackSymbols` and/or an Xcode breakpoint screenshot
- [ ] Explain: call stack vs a stack data structure
- [ ] Explain: local variables vs references to objects
- [ ] Explain: scope vs lifetime
- [ ] Explain one risk of deep recursion (stack overflow, no recursion limit). No need to actually crash it

### Part 2: Heap demo
- [ ] Show where allocation happens and what's stored
- [ ] Show the data being used
- [ ] Show when it's no longer needed and when it's freed (`deinit` printing)
- [ ] Explain ARC, strong/weak/unowned references
- [ ] Demo one risk (retain cycle is the natural choice) and the fix
- [ ] Explain what the output/tools can and can't prove about lifetime

### Part 3: Buffer demo + comparison
- [ ] Buffer used for file I/O or text processing
- [ ] Show capacity vs valid count
- [ ] Handle the final partial chunk
- [ ] Handle input bigger than the buffer
- [ ] Handle data that gets split across a chunk boundary (e.g. a word cut in half)
- [ ] **Two approaches to the same task on the same input**, same results
- [ ] Explain the memory tradeoff; label which claims are **measured** and which are **inferred**
- [ ] Repeat measurements; note variability

Comparison options the assignment suggests:
- Read the whole file at once vs process in chunks *(most natural)*
- Allocate a new buffer each time vs reuse one buffer
- Grow an array one item at a time vs `reserveCapacity` first

### Part 4: IDE tools investigation
- [ ] Name the IDE and version (Xcode __)
- [ ] Say which features are built in vs extra tools
- [ ] Demo at least one tool on our code, with screenshots
- [ ] Explain what it shows and what it **can't** show

Tools available on our setup:
| Tool | Type | Good for |
|---|---|---|
| Debug navigator memory gauge | Built into Xcode | Whole-process memory over time |
| Memory Graph Debugger | Built into Xcode | Seeing objects and who references them; spots retain cycles |
| Call stack view at a breakpoint | Built into Xcode | Part 1 |
| Malloc Stack Logging (Scheme → Diagnostics) | Built into Xcode | Where each allocation came from |
| Instruments: Allocations, Leaks | Separate app bundled with Xcode | Allocation counts/sizes, leak detection |
| `leaks`, `heap`, `vmmap`, `footprint`, `/usr/bin/time -l` | macOS command-line tools (optional) | Process-level memory numbers |

---

## 4. Required 30-minute demo sections
1. Language and memory model (who does what: our code / runtime / OS)
2. Stack demo
3. Heap demo (plus the risk and the fix)
4. Buffer demo and comparison (including a boundary case and evidence)
5. IDE tools investigation
6. Code walkthrough (important blocks only, not every line)
7. Pros, cons, limitations, and one improvement we'd make with more time

---

## 5. What we turn in (Canvas)
- [ ] Source code + any small input files (or a script that generates them)
- [ ] Build/run instructions: Swift version, macOS version, how to run each mode
- [ ] Labeled sample output: stack, heap, buffer, both comparison approaches, at least one boundary case, each with a short "what this shows"
- [ ] IDE screenshots with explanations
- [ ] List of documentation sources used
- [ ] Team contribution statement (who did what, and how we made sure everyone understands everything)

---

## 6. Decisions to make before we start
1. **Project theme / scenario.** ✅ DECIDED: **Music Playlist Streamer** (see section 9).
2. **One program with modes or several small programs.** Suggestion: one Swift package with modes, e.g. `swift run MemLab stack | heap | buffer | compare | all`.
3. **New repo or add to the Project 1 repo.**
4. **Which heap risk to demo.** Retain cycle is the clearest in Swift.
5. **Which comparison to do.** Whole-file vs chunked is the easiest to explain and measure.
6. **Buffer size and input file sizes.** e.g. 4 KB buffer; test files of a few sizes (small, ~10 MB, ~100 MB); a tiny file whose size isn't a multiple of the buffer size for the boundary case.
7. **How we measure memory.** e.g. `/usr/bin/time -l` max RSS, plus Instruments Allocations. Decide how many runs (e.g. 5 each).
8. **Which IDE tools we show.** At minimum: Memory Graph Debugger + Instruments Allocations.
9. **Who owns what.** Five roles; each person also rehearses explaining a section they didn't write.
10. **Record everyone's setup.** Xcode version, `swift --version`, `sw_vers`, `uname -m` (Apple Silicon vs Intel).

### Suggested roles
| Member | Owns |
|---|---|
| 1 | Memory model research, repo setup, README, pros/cons/limitations (demo sections 1 and 7) |
| 2 | Stack demo |
| 3 | Heap demo + retain-cycle risk and fix |
| 4 | Buffer demo + comparison + measurements |
| 5 | IDE/Instruments investigation + screenshots |

---

## 7. Practice questions (anyone may be asked)
- What is on the call stack right now in this example?
- Is this local variable the object itself or a reference to it?
- Where does allocation happen, and what ends the object's lifetime?
- Does leaving this function free the object? Why or why not?
- What does ARC do that the OS doesn't?
- What happens when the input doesn't fit in the buffer?
- How does the code handle the last partial chunk?
- What evidence supports the efficiency claim?
- What does this tool measure, and what can't it tell us?
- What's one limitation of our implementation?

---

## 8. Sources to start with
- The Swift Programming Language: "Automatic Reference Counting" chapter (docs.swift.org)
- The Swift Programming Language: "Structures and Classes" (value vs reference types)
- Apple Developer Documentation: `Thread.callStackSymbols`, `Thread.stackSize`, `InputStream`, `FileHandle`, `Data`
- Apple Developer Documentation / Xcode Help: "Gathering information about memory use," Memory Graph Debugger, Instruments
- Apple Threading Programming Guide (default stack sizes)
- `man leaks`, `man heap`, `man vmmap`, `man footprint`

---

## 9. Our project: Music Playlist Streamer

**Due:** Thursday, Oct 15, 11:59 pm

The app simulates streaming "audio" as raw bytes. No real sound is played.

| Part | What we build |
|---|---|
| Stack | Recursively sort (or shuffle) the playlist |
| Heap | `Song` and `Playlist` objects, with a delegate-based retain cycle and its fix |
| Buffer | "Play" each song in fixed-size chunks; the last chunk of a song is partial |
| Comparison | Grow a samples array one at a time vs call `reserveCapacity` first |

### Suggested program shape
One Swift package, one executable, run by mode:
```
swift run PlaylistStreamer stack
swift run PlaylistStreamer heap
swift run PlaylistStreamer buffer
swift run -c release PlaylistStreamer compare
swift run PlaylistStreamer all
```
Output labels: `STACK DEMO`, `HEAP DEMO`, `BUFFER DEMO`, `MEMORY COMPARISON`.

### Stack: recursive sort
- **Use merge sort (by title or duration)**, not only shuffle. Merge sort gives a clear enter/return pattern and depth ≈ log₂(n), so 8 songs is only ~3 levels deep and easy to read.
- Print indented enter/return lines, e.g. `→ mergeSort(depth 2, songs 2...3)` / `← return depth 2`.
- Print `Thread.callStackSymbols` at the deepest call, and take an Xcode breakpoint screenshot there.
- Talking points:
  - The `[Song]` parameter is a struct, but its elements live in a heap buffer. Each `Song` inside is a reference to a heap object.
  - A recursive **shuffle** that recurses once per song would be depth n. That's the "deep recursion risk" example: fine for 8 songs, a stack overflow risk for millions. No recursion limit in Swift, just a crash.
  - Also show a tiny `Stack<Song>` struct (e.g. a "recently played" history) to contrast a stack data structure with the call stack.

### Heap: Song, Playlist, delegate retain cycle
```swift
protocol PlaybackDelegate: AnyObject {       // AnyObject is REQUIRED for `weak`
    func songDidFinish(_ song: Song)
}

final class Playlist: PlaybackDelegate {
    var songs: [Song] = []                     // Playlist → Song (strong)
    deinit { print("HEAP DEMO: Playlist '\(name)' deinit") }
}

final class Song {
    weak var delegate: PlaybackDelegate?       // Song → Playlist (weak = no cycle)
    deinit { print("HEAP DEMO: Song '\(title)' deinit") }
}
```
- **Leaky version:** a `LeakySong` class with `var delegate` (strong). Set `playlist = nil` and **no deinit prints**. Show the cycle in the Memory Graph Debugger.
- **Fixed version:** `weak var delegate`, set `playlist = nil`, and all deinits print.
- Gotcha: `weak` only works if the protocol is constrained to `AnyObject`. Someone will likely hit this compile error.
- Talking point: deinit printing proves ARC released the objects; it does **not** prove the process's memory number went down.

### Buffer: playing songs in chunks
- Recommended: write each song's bytes to a `.raw` file first, then "play" it by reading with `InputStream` into one reused buffer. This makes it real file I/O and makes "input bigger than the buffer" natural.
```swift
var buffer = [UInt8](repeating: 0, count: 4096)          // capacity = 4096
while true {
    let n = stream.read(&buffer, maxLength: buffer.count) // n = valid bytes
    if n == 0 { break }                                   // end of song
    if n < 0 { throw stream.streamError! }                // read error
    play(buffer[0..<n])                                   // ONLY the valid bytes
}
```
- Pick song sizes that cover every boundary case:
  | Song | Size | Chunks (4096-byte buffer) |
  |---|---|---|
  | Normal | 10,000 bytes | 4096, 4096, **1808 (partial)** |
  | Exact fit | 8,192 bytes | 4096, 4096 (no partial chunk) |
  | Tiny | 100 bytes | **100** (smaller than the buffer) |
- Correctness check: total bytes played == file size, and a checksum of played bytes == checksum of the original bytes.
- Key bug to avoid: processing `buffer` instead of `buffer[0..<n]` on the last chunk would "play" leftover bytes from the previous chunk.

### Comparison: append one at a time vs reserveCapacity
Task: convert every played byte into a `Float` sample and store it in `samples: [Float]`.
- **A:** `var samples = [Float]()` then `append` each sample.
- **B:** `samples.reserveCapacity(totalBytes)` first, then `append`.
- Verify both arrays are equal (`samplesA == samplesB`).
- Use a large enough input (e.g. 5–50 million samples) so the difference shows up, and build with `-c release`.

**Evidence (label which is which):**
| Claim | Measured or inferred | How |
|---|---|---|
| Number of reallocations | Measured | Log every time `samples.capacity` changes |
| Final capacity vs count (wasted space) | Measured | Print both at the end |
| Total bytes allocated / number of allocations | Measured | Instruments → Allocations |
| Peak memory during growth is higher for A | Inferred | During each regrowth the old and new storage both exist while elements are copied |
| Exact growth factor | Inferred / implementation detail | Swift doesn't promise a growth rule; describe what we observed |

- Tradeoff to discuss: B is only better **when you know the size ahead of time**. Reserving too much wastes memory; for small arrays the difference is negligible.
- Repeat runs (e.g. 5 each) and report variability. Being faster doesn't prove less memory.

### Suggested roles for this theme
| Name | Member | Owns |
|---|---|---|
| Sarah Rae | 1 | Memory model research, package/repo setup, `Song`/`Playlist` shared models, README, sections 1 and 7 |
| Ella | 2 | Stack demo (merge sort + callStackSymbols + `Stack<Song>` contrast) |
| Stephen | 3 | Heap demo (leaky vs weak delegate, deinit output) |
| Calli | 4 | Buffer demo (song files, chunked playback, boundary cases, checksums) |
| Georgia | 5 | Comparison + Instruments/Memory Graph screenshots and measurements |

Members 1, 3, and 4 must agree on the `Song` and `Playlist` class shape first, since everyone's code uses them.