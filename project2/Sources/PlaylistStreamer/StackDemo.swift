import Foundation

// =============================================================================
// StackDemo.swift — the call stack, seen from the outside · Member 2
//
// Demo section 2. Fill in runStackDemo(); the stub below is scaffolding, not a
// design. Checklist (teamTask.md):
//
//   [ ] Recursive merge sort of Playlist.sampleEight(), by title or duration
//   [ ] Indented enter/return output with depth:
//           -> mergeSort depth 2 [songs 2...3]
//           <- return  depth 2
//   [ ] Print Thread.callStackSymbols at the DEEPEST call
//   [ ] Xcode breakpoint screenshot of the call-stack view there (-> Member 5)
//   [ ] A small Stack<Song> ("recently played") to contrast with the call stack
//   [ ] Explain: call stack vs Stack<Song>; the [Song] parameter vs the heap
//       buffer behind it vs each Song reference; scope vs lifetime
//   [ ] Explain the deep-recursion risk WITHOUT crashing it: a shuffle that
//       recurses once per song is depth n, not log n. Swift has no recursion
//       limit (Python does) — it just runs off the end of the stack and traps
//       with EXC_BAD_ACCESS. Main thread gets 8 MB, secondary threads 512 KB.
//
// Why merge sort and not the shuffle: depth log2(8) = 3 is readable on one
// screen, and the enter/return pattern is symmetric, so the output makes the
// last-in-first-out shape obvious. Keep the shuffle as the thing you *describe*
// as risky.
// =============================================================================

func runStackDemo() {
    DemoLog.begin("STACK DEMO")
    let songs = Playlist.sampleEight().songs
    let sorted = mergeSort(songs, lo: 0, hi: songs.count - 1, depth: 0) {
        $0.durationSeconds < $1.durationSeconds
    }
    DemoLog.say("sorted by duration: \(sorted.map(\.title))")

    DemoLog.say("")
    DemoLog.say("recently played — Stack<Song>, a data structure we chose, not the call stack:")
    var recentlyPlayed = Stack<Song>()
    for song in songs {
        recentlyPlayed.push(song)
        DemoLog.say("  pushed '\(song.title)' -> top is now '\(recentlyPlayed.top!.title)'")
    }
    DemoLog.say("  popping back off, most-recently-played first:")
    while let song = recentlyPlayed.pop() {
        DemoLog.say("  popped '\(song.title)'")
    }
}

/// A LIFO stack of values we chose to keep, used here as "recently played"
/// history. The contrast with the call stack above is the point of this type:
///
///   - The call stack grows and shrinks on its own, driven by function calls
///     and returns; the runtime manages it and we never see its storage.
///   - This Stack grows and shrinks only when OUR code calls push/pop. We own
///     its storage (the `elements` array, a heap buffer this struct wraps)
///     and decide what goes on it and when it comes off.
///
/// Same LIFO shape, two different reasons something ends up on top.
struct Stack<Element> {
    private var elements: [Element] = []

    var isEmpty: Bool { elements.isEmpty }
    var top: Element? { elements.last }

    mutating func push(_ element: Element) {
        elements.append(element)
    }

    @discardableResult
    mutating func pop() -> Element? {
        elements.popLast()
    }
}

/// `nonisolated(unsafe)` for the same reason as `DemoLog.section`: this
/// program is single-threaded, so the lack of compiler race-checking here is
/// honest, not a shortcut.
nonisolated(unsafe) private var didPrintDeepestStack = false

/// Recursively splits `songs[lo...hi]` in half, sorts each half, and merges.
/// Takes index bounds into the ORIGINAL array (not a sliced copy) purely so
/// the trace output can print the real `[songs lo...hi]` range at every level.
private func mergeSort(_ songs: [Song], lo: Int, hi: Int, depth: Int,
                        by areInOrder: (Song, Song) -> Bool) -> [Song] {
    let indent = String(repeating: "  ", count: depth)
    DemoLog.say("\(indent)-> mergeSort depth \(depth) [songs \(lo)...\(hi)]")

    guard hi > lo else {
        // Base case: one song. With 8 songs this is always depth 3 (log2 8),
        // so every leaf is equally "deepest" — print once, at whichever gets here first.
        if !didPrintDeepestStack {
            didPrintDeepestStack = true
            DemoLog.say("\(indent)   deepest call — Thread.callStackSymbols:")
            for symbol in Thread.callStackSymbols {
                DemoLog.say("\(indent)   \(symbol)")
            }
        }
        DemoLog.say("\(indent)<- return  depth \(depth)")
        return [songs[lo]]
    }

    let mid = (lo + hi) / 2
    let left = mergeSort(songs, lo: lo, hi: mid, depth: depth + 1, by: areInOrder)
    let right = mergeSort(songs, lo: mid + 1, hi: hi, depth: depth + 1, by: areInOrder)
    let merged = merge(left, right, by: areInOrder)

    DemoLog.say("\(indent)<- return  depth \(depth)")
    return merged
}

/// Standard merge-sort combine step: walk both sorted halves once, taking the
/// smaller front element each time. O(n), and it's the only place comparisons
/// happen outside the trivial one-element base case.
private func merge(_ left: [Song], _ right: [Song], by areInOrder: (Song, Song) -> Bool) -> [Song] {
    var result: [Song] = []
    var i = 0, j = 0
    while i < left.count && j < right.count {
        if areInOrder(left[i], right[j]) {
            result.append(left[i]); i += 1
        } else {
            result.append(right[j]); j += 1
        }
    }
    result.append(contentsOf: left[i...])
    result.append(contentsOf: right[j...])
    return result
}
