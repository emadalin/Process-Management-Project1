# Practice Questions — Team Answer Sheet

Owner: Member 1 (Sarah Rae). Source: `projectDebrief.md` section 7.

The grading is on **depth of understanding, not code that runs**, and any member may be asked
about any part. So this sheet is deliberately not organised by who wrote what — it is the
rehearsal script for explaining sections you did not write.

Answers marked **_needs Georgia_** depend on the comparison demo and cannot be finalised yet.

---

## Stack

**"What is on the call stack right now in this example?"**
At the deepest point of our merge sort: `main` → `runStackDemo()` → `mergeSort(depth 0)` →
`mergeSort(depth 1)` → `mergeSort(depth 2)` → `mergeSort(depth 3)`. Four `mergeSort` frames,
because 8 songs halve three times. Each frame holds that call's `lo`, `hi`, `depth`, the array
parameter, the return address and saved registers. The `Thread.callStackSymbols` dump in the
output shows exactly this, and the repeated identical symbol with the same offset (`+ 808`) is
the recursive call site appearing once per level.

**"Is this local variable the object itself or a reference to it?"**
In `let songs = playlist.songs`, `songs` is an `Array` struct in the stack frame — roughly 8
bytes, a pointer to its storage. The storage is a heap buffer of 8 pointers. Each of those
points to a `Song` object elsewhere on the heap. So: the variable is on the stack, its elements
are not, and the objects are somewhere else again. Three different places from one line.

**"Why doesn't sorting copy the songs?"**
Because `[Song]` holds references. Merge sort moves 8 pointers between arrays; no `Song` is
duplicated and no `deinit` fires during the sort. If `Song` were a struct, every merge step
would copy whole song values.

**"What's the difference between the call stack and your `Stack<Song>`?"**
The call stack is created by the OS for the thread, managed by the CPU and runtime, holds call
frames, and we never allocate it. `Stack<Song>` is a data structure we wrote with push/pop; its
storage is a heap buffer. They share a LIFO discipline and nothing else. Our "recently played"
history is the second kind.

**"What happens with deep recursion?"**
Each call consumes a frame, and the stack is fixed: 8 MB on the main thread, 512 KB on secondary
threads. Swift has **no recursion limit** — unlike Python, which raises `RecursionError` — so
there is no exception to catch. The thread runs into the guard page and traps with
`EXC_BAD_ACCESS`. Merge sort is depth log₂(n), so 8 songs is 3 levels and a million songs would
be 20; a shuffle recursing once per song would be depth n, and that is the version that is
dangerous. We describe this rather than crashing it.

**"Scope vs lifetime?"**
Scope is where a name is visible — a compile-time, textual property. Lifetime is how long the
object exists at runtime. For a class instance they are independent: leaving a function ends
the local reference's scope and decrements the count, but the object lives on if anything else
holds it strongly.

## Heap

**"Where does allocation happen, and what ends the object's lifetime?"**
`Song(title:...)` allocates on the heap via libmalloc and returns a reference with a strong
count of 1. The lifetime ends when that count reaches 0 — not when the function returns, not at
a collection pass. The heap demo controls this explicitly with `song = nil` so the moment is
visible.

**"Does leaving this function free the object? Why or why not?"**
Only if the function held the last strong reference. Any other strong holder — an array, a
delegate, a closure capture — keeps it alive. This is why our leaky example sets the playlist to
`nil` and *still* gets no `deinit`: the two objects hold each other.

**"What does ARC do that the OS doesn't?"**
ARC tracks ownership of individual objects and runs `deinit` at a precise moment. The kernel has
no concept of an object; it manages pages for the whole process. libmalloc sits between, dealing
in blocks. Objects, blocks, pages — three vocabularies, three layers.

**"Why does the protocol need `: AnyObject`?"**
`weak` is a reference-counting mechanism, and only classes are reference counted. Without the
constraint, `weak var delegate: PlaybackDelegate?` does not compile: *"'weak' must not be
applied to non-class-bound protocol."* A struct could conform otherwise, and there would be
nothing to zero out.

**"Why `weak` rather than `unowned`?"**
`unowned` also avoids counting, but assumes the target always outlives the reference and traps
if it does not. A playlist can legitimately be freed while a song still exists, so that
assumption is false here. `weak` is the correct choice, at the cost of being Optional.

**"What does the deinit output prove — and not prove?"**
It proves ARC released the object, at an exact and repeatable moment. It does **not** prove the
process's memory went down: libmalloc usually keeps the block on a free list for reuse, and the
kernel's page count is unchanged. Different layer, different measurement.

**"How would you find a leak you didn't already know about?"**
The Memory Graph Debugger: pause and look for objects that should be gone, and at who still
references them. A `deinit` print only helps when you already suspect the object.

## Buffer

**"What happens when the input doesn't fit in the buffer?"**
Nothing special — that is the normal case. The loop reads 4096 bytes at a time until `read`
returns 0. A 10,000-byte song takes three passes. Memory stays flat regardless of file size,
which is the entire point of buffering.

**"How does the code handle the last partial chunk?"**
`read` returns `n`, the count of valid bytes, which is less than capacity on the final pass.
Only `buffer[0..<n]` is processed. The rest of the buffer still holds bytes from the previous
chunk — they are not cleared, just not read.

**"What if you processed the whole buffer instead?"**
We show it. The 10,000-byte song replays 12,288 bytes and the checksum fails; the 100-byte song
replays 4096 and fails. But the 8,192-byte song **still passes**, because its final read fills
the buffer exactly and leaves no stale bytes. That is why the exact-fit size is in the suite.

**"Where does the buffer live?"**
`[UInt8](repeating: 0, count: 4096)` is an `Array` — a struct on the stack whose 4096 bytes of
storage are a heap buffer. One allocation, reused on every chunk, which the output demonstrates
by printing the same storage address every time.

**"Capacity vs count?"**
Capacity is how much the buffer can hold (4096, fixed). Count is how much is valid right now
(`n`, varying). They are equal on every chunk except the last.

**"Does one chunk mean one disk read?"**
No — and this is a limit of what we show. Our chunk count measures calls *we* made into
`InputStream`. The file system cache and any buffering inside Foundation sit underneath, so we
cannot claim anything about actual storage access.

## Comparison and tools

**"What evidence supports the efficiency claim?"** — **_needs Georgia_**
Measured: reallocation count, final capacity vs count, and Instruments' total bytes and
allocation count. Inferred: that peak memory is higher without reserving, because old and new
storage coexist during each copy — we reason it, we did not sample it. Unspecified: the growth
factor itself, which Swift does not promise.

**"What does this tool measure, and what can't it tell you?"** — **_needs Georgia_**
The Memory Graph Debugger shows live objects and who references them, so it finds cycles — but
it is a snapshot, and shows nothing about stack memory or about history. Instruments Allocations
counts allocations and bytes over time, but attributes them to call sites, not to meaning.
`/usr/bin/time -l` max RSS is whole-process and page-granular (16 KB), so it cannot confirm an
object-level claim at all.

**"Why must all the comparison numbers come from one machine?"**
Array growth is a standard-library implementation detail with no promised growth factor, and the
team's toolchains differ. Two machines produce two different experiments, not a comparison.

**"Isn't faster the same as less memory?"**
No, and we are careful not to let a timing number stand in for an allocation number. Reserving
capacity reduces reallocations, which usually helps speed, but the claim we are making is about
allocation behaviour and is measured as such.

## Judgement questions

**"What's one limitation of your implementation?"**
The honest one: our peak-memory claim is inferred rather than measured. Also worth naming — we
demonstrate exactly one heap risk, and a cycle through a closure capturing `self` is more common
in practice than our delegate cycle.

**"What would you do differently with more time?"**
Memory-map the file as a third strategy. It is the only addition that brings the **kernel** into
a demo that currently stops at libmalloc, and it would give us a case where chunked buffering is
the wrong tool rather than always the better one.

**"Who handles memory in your program?"**
Never "the system." Our code chooses the shapes; the Swift compiler and ARC decide when objects
die; libmalloc decides where bytes come from and whether they go back; the macOS kernel decides
what the process gets at all. The layers are independent — an object can be freed while the
process's memory number never moves.
