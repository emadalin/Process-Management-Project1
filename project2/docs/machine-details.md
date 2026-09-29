# Team Machine Details

Owner: Member 1 (Sarah Rae). Member 5 (Georgia) references this for every measurement run.

Each person: run the commands below in Terminal and send the output to Sarah (or fill in your own row).

```bash
sw_vers                                    # macOS version + build
uname -m                                   # arm64 (Apple Silicon) or x86_64 (Intel)
sysctl -n machdep.cpu.brand_string         # chip name, e.g. "Apple M2"
sysctl -n hw.memsize                       # installed RAM, in bytes
pagesize                                   # virtual memory page size, in bytes
swift --version                            # toolchain
xcodebuild -version                        # Xcode (needed for Instruments)
```

| Name (Member #) | macOS (`sw_vers`) | Chip | RAM | Page size | Swift | Xcode |
|---|---|---|---|---|---|---|
| Sarah Rae (1) | 15.7.4 (24G517) | Apple M2 (arm64) | 24 GB | 16384 B | 6.2.1 (swiftlang-6.2.1.4.8) | 26.1.1 (17B100) |
| Ella (2) | | | | | | |
| Stephen (3) | | | | | | |
| Calli (4) | | | | | | |
| Georgia (5) | | | | | | |

## Why this matters for a memory project

**Toolchain version is the big one.** Project 1's results varied with core count; here the
variable is the Swift version, because the thing Member 5 measures — how `Array` grows when
you `append` without reserving — is an *implementation detail* of the standard library. Swift
does not promise a growth factor, so a different toolchain may legitimately produce a different
reallocation count for identical code. In project 1 the team's toolchains spanned 6.2.1 to
6.4.0. If that spread holds here, **every comparison number in the report must come from one
machine**, and the README must say which. Numbers from two different Macs are not a comparison.

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

Fill this in once Member 5 starts measuring, and keep it consistent with the README:

- **Comparison measurements (all 5 runs, A and B):** ______
- **Instruments screenshots:** ______
- **Memory Graph Debugger screenshots:** ______
- **Xcode call-stack screenshot (stack demo):** ______
