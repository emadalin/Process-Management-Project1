import Foundation

// =============================================================================
// CompareDemo.swift — two ways to fill an array · Member 5
//
// Demo sections 4 (comparison half) and 5 (IDE tools). Checklist (teamTask.md):
//
//   [x] A: build samples: [Float] by appending one at a time
//   [x] B: the same work, with samples.reserveCapacity(total) first
//   [x] Verify samplesA == samplesB — same results, or the comparison is void
//   [x] Log every capacity change in A (that count IS the reallocation count);
//       print final capacity vs count for both
//   [x] Large input (5-50 million samples), `swift run -c release`, 5 runs each
//       (numbers in docs/compare-results.md)
//   [x] Instruments -> Allocations on A and B, with screenshots
//   [x] Write-up: Xcode version, built-in vs separate tool, what each shows and
//       what it can't establish
//
// Label every claim (shared rules). The honest split:
//
//   MEASURED   reallocation count, final capacity vs count, total bytes
//              allocated and allocation count from Instruments
//   MEASURED   peak footprint (/usr/bin/time -l). We expected old + new
//              storage coexisting during regrowth to push A's peak far above
//              B's; it didn't. The gap is A's unused doubled capacity
//              (docs/compare-results.md)
//   NOT OURS   the exact growth factor. Swift doesn't promise one. Report what
//              you observed and say that's what it is.
//
// Two traps: debug builds make this measurement meaningless, so use release.
// And faster is not the same as less memory — don't let a timing number stand
// in for an allocation number.
//
// Who does what here (shared rules):
//
//   OUR CODE    decides whether to reserve, and how much (the file size)
//   SWIFT       Array grows its storage when count would pass capacity:
//               allocate bigger, copy every element over, free the old block
//   LIBMALLOC   hands out each new block and takes back each old one
//   MACOS       backs those blocks with pages; big ones come straight from
//               the kernel via mmap
//
//   swift run -c release PlaylistStreamer compare                  (A and B)
//   swift run -c release PlaylistStreamer compare --samples=50000000
//   swift run -c release PlaylistStreamer compare --only=a         (Instruments)
// =============================================================================

/// 10 million: inside the 5-50M range the checklist asks for, and big enough
/// that A regrows ~20+ times. Override with --samples=N.
let defaultSampleCount = 10_000_000

// MARK: - Building the samples

/// What one fill of the array produced, plus what it cost.
struct FillResult {
    let samples: [Float]
    /// Every capacity A's storage passed through, in order. Starts with the
    /// empty array's capacity, so `reallocations` is one less than this count.
    let capacities: [Int]
    let duration: Duration

    var reallocations: Int { capacities.count - 1 }
}

/// Plays `song` through Member 4's buffer and turns each byte into one Float
/// sample in 0...1.
///
/// A and B are this same function, so the only difference between them is the
/// `reserveCapacity` call. Both loops check capacity after every append, even
/// though B's never changes — that way the check costs the same in both and
/// doesn't skew the timing.
func fillSamples(from song: Song, reserve: Bool) throws -> FillResult {
    var samples: [Float] = []

    // B's whole difference. The file size is known before reading, so we can
    // ask for every slot up front: one allocation, no copies. `total` is the
    // byte count because each byte becomes exactly one sample.
    if reserve {
        samples.reserveCapacity(song.byteCount)
    }

    var capacities = [samples.capacity]
    let clock = ContinuousClock()
    let start = clock.now

    try playSong(song) { _, valid, _ in
        // The slice is only valid during this call (the next read overwrites
        // the buffer), so each byte is converted and COPIED into samples here.
        for byte in valid {
            samples.append(Float(byte) / 255)
            // A capacity change means Swift just moved the whole array to a
            // new, bigger heap block. Logging every one is how we COUNT
            // reallocations rather than guess at them.
            if samples.capacity != capacities[capacities.count - 1] {
                capacities.append(samples.capacity)
            }
        }
    }

    return FillResult(samples: samples, capacities: capacities,
                      duration: start.duration(to: clock.now))
}

// MARK: - Demo

func runCompareDemo() {
    DemoLog.begin("MEMORY COMPARISON")

    let sampleCount = flagValue("--samples").flatMap(Int.init) ?? defaultSampleCount
    // --only=a / --only=b run one side alone, so an Instruments Allocations
    // trace shows just that side's allocations.
    let only = flagValue("--only")?.lowercased()

    #if DEBUG
    DemoLog.say("⚠ debug build — timings here are meaningless. Use: swift run -c release PlaylistStreamer compare")
    #endif

    // The input is one big song file, played through the same 4096-byte buffer
    // as the buffer demo. One byte in = one Float sample out.
    let song = Song(title: "Compare Input", durationSeconds: 0, byteCount: sampleCount)
    do {
        try writeSongFile(for: song)
    } catch {
        DemoLog.say("✗ could not write the input file: \(error)")
        return
    }
    DemoLog.say("input: \(sampleCount) samples (\(sampleCount) bytes on disk → \(sampleCount * MemoryLayout<Float>.stride) bytes as [Float])")

    do {
        var a: FillResult?
        var b: FillResult?

        if only != "b" {
            DemoLog.say("")
            DemoLog.say("── A: append one at a time, no reserve ──")
            let result = try fillSamples(from: song, reserve: false)
            for (i, capacity) in result.capacities.enumerated().dropFirst() {
                DemoLog.say("  realloc #\(i): capacity \(result.capacities[i - 1]) → \(capacity)")
            }
            report(result)
            a = result
        }

        if only != "a" {
            DemoLog.say("")
            DemoLog.say("── B: reserveCapacity(\(sampleCount)) first ──")
            let result = try fillSamples(from: song, reserve: true)
            DemoLog.say("  reserved capacity \(result.capacities[0]) before the first append")
            report(result)
            b = result
        }

        guard let a, let b else { return }

        DemoLog.say("")
        DemoLog.say("── A vs B ──")
        // Same elements in the same order. If this fails, the two sides did
        // different work and nothing below means anything.
        let same = a.samples == b.samples
        DemoLog.say("  samplesA == samplesB: \(same ? "✓ identical" : "✗ DIFFERENT — comparison is void")")
        DemoLog.say("  reallocations: A \(a.reallocations), B \(b.reallocations)  (measured)")
        DemoLog.say("  final capacity / count: A \(a.samples.capacity) / \(a.samples.count), B \(b.samples.capacity) / \(b.samples.count)  (measured)")
        DemoLog.say("  growth factors A went through: \(growthFactors(a.capacities))  (observed, not promised by Swift)")
        DemoLog.say("  time: A \(a.duration), B \(b.duration)  (measured, one run — includes file reads, which both sides pay)")
        let unused = a.samples.capacity - b.samples.capacity
        DemoLog.say("  A holds \(unused) more slots than B (\(unused * MemoryLayout<Float>.stride) bytes) — doubling overshot the count  (measured)")
        DemoLog.say("  A's abandoned blocks: see Instruments total bytes, not this program  (measured there, not here)")
    } catch {
        DemoLog.say("✗ \(error)")
    }
}

private func report(_ result: FillResult) {
    let bytes = result.samples.capacity * MemoryLayout<Float>.stride
    DemoLog.say("  count \(result.samples.count), capacity \(result.samples.capacity) (\(bytes) bytes of storage), \(result.reallocations) reallocation(s), \(result.duration)")
}

/// Ratio between each pair of consecutive capacities, e.g. "2.0, 2.0, 1.5".
/// Skips the step out of capacity 0, which has no ratio.
private func growthFactors(_ capacities: [Int]) -> String {
    let ratios = zip(capacities, capacities.dropFirst())
        .filter { $0.0 > 0 }
        .map { String(format: "%.2f", Double($0.1) / Double($0.0)) }
    return ratios.isEmpty ? "none" : ratios.joined(separator: ", ")
}

/// Value of a `--name=value` command-line flag, if present.
private func flagValue(_ name: String) -> String? {
    CommandLine.arguments
        .first { $0.hasPrefix(name + "=") }
        .map { String($0.dropFirst(name.count + 1)) }
}
