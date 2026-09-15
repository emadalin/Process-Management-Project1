# Team Machine Details

Owner: Member 1. Member 5 references this for every priority run.

Each person: run the commands below in Terminal and send the output to Member 1 (or fill in your own row).

```bash
sw_vers
uname -m
sysctl -n hw.ncpu
sysctl hw.perflevel0.physicalcpu hw.perflevel1.physicalcpu   # Apple Silicon only (P-cores / E-cores)
sysctl -n machdep.cpu.brand_string                            # chip name, e.g. "Apple M2"
swift --version
```

| Name (Member #) | macOS (`sw_vers`) | Chip (`uname -m` / brand) | Cores (`hw.ncpu`) | P / E cores | Swift (`swift --version`) |
|---|---|---|---|---|---|
| Sarah Rae (1, 5) | 15.7.4 (24G517) | arm64 (Apple Silicon) | 8 | 4 / 4 | 6.2.1 (swiftlang-6.2.1.4.8) |
| Calli (1, 5) | | | | | |
| Stephen (2) | | | | | |
| Ella (3) | | | | | |
| Georgia (4) | | | | | |

**Why this matters:** Part C results depend on core count and P-core vs. E-core layout, and race frequency in Part B varies by hardware and build type. Results from different Macs aren't directly comparable, so every saved output and every row in the priority results table should say which Mac produced it.
