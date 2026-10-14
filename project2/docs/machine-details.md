# Team Machine Details

Owner: Member 1 (Sarah Rae). Member 5 (Georgia) references this for every measurement run.

Each person: run **`./verify.sh`** from the `project2` directory. It confirms the package
builds and every mode runs on your Mac, then prints your row ready to paste back — which
covers two of Member 1's collection items in one command.

```bash
cd project2 && ./verify.sh
```

If you would rather gather it by hand, the row comes from:

```bash
sw_vers                                    # macOS version + build
uname -m                                   # arm64 (Apple Silicon) or x86_64 (Intel)
sysctl -n machdep.cpu.brand_string         # chip name, e.g. "Apple M2"
sysctl -n hw.memsize                       # installed RAM, in bytes
pagesize                                   # virtual memory page size, in bytes
swift --version                            # toolchain
xcodebuild -version                        # Xcode (needed for Instruments)
```

**Re-run it near the deadline.** These values drift — Sarah's macOS went from 15.7.4 to 15.8.1
inside a week without anyone noticing, and the toolchain version is the one field that can
invalidate a measurement.

| Name (Member #) | macOS (`sw_vers`) | Chip | RAM | Page size | Swift | Xcode |
|---|---|---|---|---|---|---|
| Sarah Rae (1) | 15.8.1 (24H32) | Apple M2 (arm64) | 24 GB | 16384 B | 6.2.1 (swiftlang-6.2.1.4.8) | 26.1.1 (17B100) |
| Ella (2) | 26.5.1 (25F80) | Apple M5 Pro (arm64) | 48 GB | 16384 B | 6.3.3 (swiftlang-6.3.3.1.3) | 26.6 (17F113) |
| Stephen (3) | 26.5.2 (25F84) | Apple M4 Max (arm64) | 64 GB | 16384 B | 6.3.2 (swiftlang-6.3.2.1.108) | 26.5 (17F42) |
| Calli (4) | 26.6.2 (25G83) † | Apple M3 Pro (arm64) † | not recorded | 16384 B ‡ | 6.2.3 (swiftlang-6.2.3.3.21) † | not recorded |
| Georgia (5) | 26.6.2 (25G83) | Apple M1 (arm64) | 16 GB | 16384 B | 6.4 (swiftlang-6.4.0.34.1) | 27.0 (27A266a) |

**† Carried over from project 1** (`../../project1/docs/machine-details.md`, collected
September 2026) because Calli did not send fresh numbers for project 2. Treat this as
provisional: Sarah's own macOS moved from 15.7.4 to 15.8.1 between the two projects, so a
carried-over row can be stale. It is credible anyway because Ella's and Georgia's self-reported
project 2 rows match their project 1 entries exactly on macOS, chip and toolchain, and Calli's
machine did not produce any number in this report. Stephen's row above is fresh — captured this
session via `./verify.sh` on his actual machine, not carried over.

**‡ Page size is not measured, it is architectural.** Both machines are `arm64`, and every
Apple Silicon Mac uses 16 KB pages.

**RAM and Xcode version were never collected for project 1**, so they are genuinely unknown
here for Calli rather than carried over. Nothing in the report depends on them: RAM matters only
as a sanity bound on the 10M/50M-sample arrays, and the Xcode version matters only for whoever
drove Instruments, which was Georgia.

## Why this matters for a memory project

**Toolchain version is the big one.** Project 1's results varied with core count; here the
variable is the Swift version, because the thing Member 5 measures — how `Array` grows when
you `append` without reserving — is an *implementation detail* of the standard library. Swift
does not promise a growth factor, so a different toolchain may legitimately produce a different
reallocation count for identical code. The team's toolchains span **6.2.1 to 6.4**, so
**every comparison number in the report comes from one machine** — Georgia's M1 — and the README
says so.

This is not hypothetical. The same `compare` code, 10 million samples, gave array A three
different final capacities:

| Where | Toolchain | A's final capacity | A's reallocations |
|---|---|---|---|
| Georgia's M1, earlier session | Swift 6.4 | 10,010,616 | 21 |
| Georgia's M1, reported session | Swift 6.4 | 12,582,904 | 22 |
| Sarah's M2 | Swift 6.2.1 | 16,777,208 | 22 |

Same code, three answers. Numbers from two different Macs are not a comparison.

**Page size** (16 KB on Apple Silicon, 4 KB on Intel) is the granularity at which the kernel
hands memory to the process. It explains why process-level tools like `/usr/bin/time -l` move
in steps rather than tracking individual allocations — useful when Member 5 explains what a
tool can and cannot show.

**RAM** matters only as a sanity bound: the comparison demo builds an array of 5–50 million
`Float`s (20–200 MB), which must fit comfortably or the machine starts swapping and the timing
numbers become meaningless.

**Chip and macOS version** are recorded for completeness and because Instruments output differs
slightly between Xcode versions, which matters when Member 5's screenshots are compared against
someone else's live run during the demo.

## Which machine produced the report's numbers

**Georgia's M1 is the reference machine** — Apple M1 (arm64), macOS 26.6.2 (25G83), Swift 6.4,
Xcode 27.0 (27A266a). Every comparison number and every memory screenshot came from it, in one
session on 2026-10-14, which is what makes the figures comparable to each other.

| Artefact | Machine | Files |
|---|---|---|
| Comparison measurements, all 5 runs, A and B | Georgia's M1 | [`compare-results.md`](compare-results.md), `../output-compare-run1.txt` |
| Instruments Allocations screenshots | Georgia's M1 | `instruments-alloc-a.png`, `instruments-alloc-b.png` |
| Memory Graph Debugger screenshot | Georgia's M1 | `heap-memory-graph-leak.png` |
| Xcode call-stack screenshot | Ella's M5 Pro, macOS 26.5.1, Xcode 26.6 | `stack-call-stack-xcode.png` |

The call-stack screenshot is the one artefact from a different Mac, and that is fine: it shows
the *shape* of the call stack, which is a property of the code, not a measurement. Nothing in
the report compares it against a number from anywhere else.
