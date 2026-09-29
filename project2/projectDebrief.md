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
1. **Project theme / scenario.** One story that ties all parts together (like the ThreadLab vending machine). *To brainstorm.*
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