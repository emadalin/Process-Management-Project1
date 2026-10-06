# Demo Section 1: Language & Memory Model (3 min)

Owner: Member 1 (Sarah Rae). Someone who did not write it should be able to present it — see the rehearsal note at the end.

**One-sentence version:** Four layers each own part of memory — our code decides the *shape*, the Swift compiler and ARC decide *when objects die*, libmalloc decides *where bytes come from and whether they go back*, and the macOS kernel decides *what the process gets at all* — and "the system handles it" is the one answer that gets no credit.

---

## 1. Who is responsible for what

| Layer | Owns | In our program |
|---|---|---|
| **Our code** | `struct` vs `class`; strong / `weak` / `unowned`; buffer sizes; whether to `reserveCapacity` | `Song` and `Playlist` are classes; `Song.delegate` is `weak`; the buffer is 4096 bytes |
| **Swift compiler + runtime (ARC)** | Inserting retain/release; freeing an object the instant its strong count hits 0; running `deinit` | Every `deinit` line the heap demo prints |
| **libmalloc** (Apple's allocator) | Handing out heap blocks; *keeping* freed blocks to reuse rather than returning them to the OS | Why `deinit` firing does not shrink the process's memory number |
| **macOS kernel** | Virtual memory pages; each thread's stack; what RSS actually measures | 16 KB pages on Apple Silicon; the 8 MB main-thread stack |

The rubric specifically calls "the system handles memory" a weak answer. The fix is to name the layer: *ARC* released the object, *libmalloc* kept the space, the *kernel* never saw either event.

**The key consequence, and the one to say out loud:** these layers are independent. An object can be freed (ARC) while the process's memory usage stays flat (libmalloc reuses the block) and the kernel's page count never changes. All three statements are true at once. Most confusion about memory comes from assuming they move together.

## 2. Stack vs heap, as our program uses them

**The stack** is per-thread and automatic. Each call pushes a frame holding parameters, locals, the return address and saved registers; returning pops it. Last in, first out. It is fast because allocation is just moving a pointer, and it is small and fixed: **8 MB on the main thread, 512 KB on secondary threads** (Apple's Threading Programming Guide). Overflow it and there is no exception to catch — the thread hits the guard page and traps.

**The heap** is process-wide and manual-ish. It holds anything that outlives the call that made it or whose size isn't known at compile time. It is flexible and large, slower to allocate, and someone has to decide when space can be reused — in Swift, ARC.

**The sentence that ties them together, using our own code:**

```swift
let songs: [Song] = playlist.songs
```

That one line touches both, three times over:
- `songs` is a local — an `Array` struct, about 8 bytes, **on the stack**
- its element storage is a **heap buffer** holding 8 pointers
- each pointer targets a **`Song` object elsewhere on the heap**

So "is this local variable on the stack?" has no single answer, and that is the point. The *variable* is; the *storage* isn't; the *objects* aren't.

## 3. Value types vs reference types

| | Value types | Reference types |
|---|---|---|
| Examples | `struct`, `enum`, `Int`, `Array`, `String` | `class`, closures, `actor` |
| Copying | Makes an independent copy | Copies the *reference*; both names point at one object |
| Identity | None — two equal values are interchangeable | Has identity; `===` distinguishes instances |
| Lifetime | Ends with its scope | Ends when the last strong reference goes |
| Reference counted | No | Yes |

**Why `Song` and `Playlist` are classes.** This is a design decision we made deliberately, and expect to be asked about. A `struct Song` would be *copied* into the array, would have no identity, could not be referred to from two places, would not be reference counted — and so could not have a `deinit` to observe, and could not form a retain cycle. Every single thing demo section 3 shows depends on `Song` being a class.

**The trap in the table:** `Array` is a *value type* whose storage is on the *heap*. Value/reference and stack/heap are two different questions. Arrays use copy-on-write: copying one copies a small struct and bumps a reference count on the shared buffer; the buffer is only duplicated if someone writes to it while it is shared. Our merge sort moves 8 pointers around and never duplicates a `Song`.

## 4. ARC is not garbage collection

| | ARC (Swift) | Tracing GC (Java, Go, C#) |
|---|---|---|
| When memory is freed | **Immediately** when the strong count hits 0 | Whenever the collector next runs |
| Who decides | The compiler, at compile time | A runtime collector, during execution |
| Cost shows up as | Retain/release traffic spread through the code | Pauses when the collector runs |
| Destructor timing | Deterministic — `deinit` runs at an exact, predictable point | Non-deterministic; finalizers may run late or never |
| Cycles | **Leak.** ARC cannot detect them; the programmer breaks them with `weak`/`unowned` | Collected automatically — a tracing GC finds unreachable cycles |

That last row is the honest trade. Determinism is what lets our heap demo print `deinit` at an exact moment and *prove* something; the price is that a retain cycle is a real, permanent leak, which is exactly what demo section 3 shows.

**Say "strong reference count," not "reference count."** `weak` and `unowned` references exist and are not counted — that distinction is the entire mechanism of the fix.

## 5. Practice-question answers for this section

**"What does ARC do that the OS doesn't?"**
ARC tracks *ownership of individual objects* and runs `deinit` at a precise moment. The kernel knows nothing about objects — it deals in pages of virtual memory for the whole process. Between them sits libmalloc, which knows about blocks but not about meaning or lifetime. Three different vocabularies: objects, blocks, pages.

**"Is this local variable the object itself or a reference to it?"**
If its type is a class, it is a reference — the variable sits on the stack and holds an address of a heap object. If its type is a struct or enum, the value is in the frame itself. `Array`, `String` and `Dictionary` are the awkward middle: struct on the stack, elements on the heap.

**"Does leaving this function free the object?"**
Only if the function held the *last strong reference*. Leaving the scope destroys that one reference and decrements the count; if anything else still holds the object — another array, a closure, a delegate — it lives on. Scope and lifetime are different things, which is why the heap demo uses `var x: T? = ...; x = nil` to control the moment exactly rather than relying on scope exit.

**"Why isn't a `deinit` print enough to prove memory was freed?"**
It proves ARC released the *object*. libmalloc typically keeps that block on a free list for reuse, and the kernel's page count is unchanged, so process-level tools can show no movement at all. Different layer, different measurement.

---

## Rehearsal note

This section is the one most likely to be re-presented by someone who did not write it, because it is all explanation and no code. The three things a presenter must be able to do cold: name the four layers, explain why `[Song]` touches stack and heap at once, and state the ARC-vs-GC trade in both directions (determinism gained, cycle collection lost).

## Sources to cite

- *The Swift Programming Language* — "Automatic Reference Counting" (strong/weak/unowned, cycles)
- *The Swift Programming Language* — "Structures and Classes" (value vs reference semantics, identity)
- Apple Developer Documentation — "Threading Programming Guide," thread stack sizes (8 MB main / 512 KB secondary)
- `man malloc`, `man malloc_zone_malloc` — libmalloc behaviour and free-list reuse
- Apple Developer Documentation — "Gathering information about memory use" (what RSS and footprint mean)
