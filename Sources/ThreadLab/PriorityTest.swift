import Foundation

// =============================================================================
// Section 5 — Priority / Scheduling Investigation (Part C) · Member 5
// Owner: Member 5 (Sarah Rae & Calli)
//
// Three identical CPU-bound PickerRobot racers count loop iterations for a fixed
// 2 seconds. We compare how much work each one gets done with all-default QoS vs.
// .userInteractive / .utility / .background. Extra load threads make sure there are
// more busy threads than cores, because macOS has no CPU pinning.
//
// THE QUESTION THIS ANSWERS: on macOS, what does asking for a higher priority
// actually get you? The brief is explicit that we must never claim priority
// guarantees execution order without documentation AND evidence. So this is
// built as an experiment, not a demonstration of a conclusion we picked first:
//
//   - three racers doing byte-for-byte IDENTICAL work, so any difference in the
//     numbers can only come from scheduling
//   - a fixed time box rather than a fixed workload, so "who got more CPU" is
//     the thing being measured
//   - a start gate, so nobody gets a head start
//   - load threads, so the CPU is genuinely oversubscribed — with idle cores the
//     scheduler has no reason to prefer anyone and all three simply tie
//   - configs alternated and repeated 5 times, so thermal drift and background
//     activity don't masquerade as a priority effect
//   - we record what we REQUESTED, what Thread reports back, and what the kernel
//     actually applied — those three are not always the same, which is itself
//     one of the findings
//
// Vocabulary worth keeping straight in the demo: macOS does not expose raw
// priority numbers to set. You express INTENT via Quality of Service (QoS), and
// the kernel translates that into scheduling decisions however it sees fit,
// including which core type (performance vs. efficiency) a thread lands on.
//
// Entry point for Member 2's mode switch: runPriorityTest()
// =============================================================================

/// Runs every priority configuration `rounds` times, then prints a results table and averages.
/// Thin wrapper so Harness.swift has a plain free function to call.
func runPriorityTest(rounds: Int = PriorityTest.roundsPerConfig) {
    PriorityTest.run(rounds: rounds)
}

/// Namespace enum (never instantiated) holding the whole Part C experiment:
/// settings, result types, the race itself, and all its reporting.
enum PriorityTest {

    // MARK: - Settings

    /// Long enough to average over scheduler noise, short enough to run 10 races
    /// in a demo. Time-boxed, not work-boxed: we measure work done per unit time.
    static let raceDuration: TimeInterval = 2.0
    /// The brief requires at least 5 runs per configuration — a single run of a
    /// scheduling experiment is an anecdote, not evidence.
    static let roundsPerConfig = 5
    /// Pause between races so one race's heat and leftover work don't bleed into the next.
    /// (Sustained 100% CPU makes an Apple Silicon Mac throttle, which would show
    /// up as a steady decline across runs and could be misread as a QoS effect.)
    static let cooldownBetweenRaces: TimeInterval = 1.0
    /// One load thread per logical core, so racers + load threads > cores and everything competes.
    ///
    /// This is the most important knob in the file. macOS gives no way to pin a
    /// thread to a core, so the only way to force the scheduler to actually make
    /// a choice is to demand more CPU than exists. Without these, all three
    /// racers get a core each, finish level, and the experiment shows nothing.
    static let loadThreadCount = ProcessInfo.processInfo.activeProcessorCount

    /// One experimental condition: a label for the output plus the QoS to request
    /// for each of the three racers.
    struct Config: Sendable {
        let label: String
        /// QoS requested for PickerRobot1, 2, 3. `nil` means never set, so the thread keeps macOS's default.
        let racerQoS: [QualityOfService?]
    }

    /// The control condition, then the experimental one. Same three threads, same
    /// work, only the requested QoS differs.
    static let configs = [
        // Control: nothing set at all. Note `nil` is NOT the same as writing
        // `.default` — one leaves the thread's inherited setting untouched, the
        // other is an explicit assignment. Part C asks what the default IS, so we
        // have to avoid overwriting it.
        Config(label: "All `.default`", racerQoS: [nil, nil, nil]),
        // Experiment: the top and bottom of the QoS range, plus a middle. If QoS
        // affects CPU share at all, it should be visible here or nowhere.
        Config(label: "`.userInteractive` / `.utility` / `.background`",
               racerQoS: [.userInteractive, .utility, .background]),
    ]

    // MARK: - Results

    /// What one racer reports back after its 2 seconds.
    ///
    /// Three separate priority readings on purpose — comparing them is a finding
    /// in its own right, because what you ask for, what the object reports, and
    /// what the kernel applies can all differ.
    struct RacerReport: Sendable {
        let name: String
        let requestedQoS: QualityOfService? // what we asked for before start(), nil = never set
        let reportedQoS: QualityOfService   // Thread.current.qualityOfService, read inside the thread
        let threadPriority: Double          // Thread.current.threadPriority, read inside the thread
        let appliedQoSClass: String         // qos_class_self(): what the kernel actually applied
        let iterations: Int                 // the actual measurement: work completed in raceDuration
    }

    /// One complete race: which round, which config, and all three racer reports.
    struct Race: Sendable {
        let round: Int
        let configIndex: Int
        let reports: [RacerReport]
    }

    /// Lock-protected store the racers write into. Nothing is printed until every racer has finished.
    ///
    /// Two reasons for the lock rather than, say, an array indexed by racer:
    /// appending from three threads to a shared Array is a data race (Swift
    /// Arrays are value types with copy-on-write buffers — concurrent appends can
    /// corrupt the buffer outright, not just reorder elements). And keeping the
    /// printing out of the threads means no I/O inside the timed section.
    final class ResultsStore: @unchecked Sendable {
        private let lock = NSLock()
        private var reports: [RacerReport] = []

        func record(_ report: RacerReport) {
            lock.lock()
            defer { lock.unlock() }
            reports.append(report)
        }

        /// Sorted by name so PickerRobot1/2/3 always print in the same order,
        /// regardless of which thread happened to finish recording first.
        func sortedReports() -> [RacerReport] {
            lock.lock()
            defer { lock.unlock() }
            return reports.sorted { $0.name < $1.name }
        }
    }

    /// Holds every thread at the starting line, then releases them all with one shared deadline,
    /// so the thread started first doesn't get a head start (start-order bias).
    ///
    /// Without this, PickerRobot1 — created first — would start counting while
    /// PickerRobot3 was still being spun up, and would win every race for a
    /// reason that has nothing to do with priority. This is the experimental
    /// control that makes the numbers mean anything.
    ///
    /// NSCondition rather than a plain lock because we need to WAIT for a
    /// condition to become true, not just exclude others: a lock plus a wait
    /// queue plus the ability to wake everyone at once.
    final class StartGate: @unchecked Sendable {
        private let condition = NSCondition()
        private var readyCount = 0
        private var deadline: UInt64?   // nil = gate closed; non-nil = open, and this is the finish time

        /// Called by each thread. Blocks until the gate opens, then returns the shared deadline.
        func waitForStart() -> UInt64 {
            condition.lock()
            defer { condition.unlock() }
            readyCount += 1
            condition.broadcast()   // let the main thread see the new ready count
            // The `while` is not optional style: condition variables permit
            // spurious wakeups, so a woken thread must RE-CHECK the condition it
            // was waiting on rather than assume it is now true. wait() atomically
            // releases the lock while sleeping and re-acquires it on waking.
            while true {
                if let deadline { return deadline }
                condition.wait()
            }
        }

        /// Called by the main thread. Waits until every thread is at the gate, then opens it.
        func openWhenReady(threadCount: Int, raceDuration: TimeInterval) {
            condition.lock()
            defer { condition.unlock() }
            while readyCount < threadCount {
                condition.wait()
            }
            // One deadline computed ONCE and shared by every thread. If each
            // thread computed "now + 2s" for itself, a thread that woke late
            // would also finish late and get a longer race — the bias we just
            // eliminated would come straight back in.
            deadline = DispatchTime.now().uptimeNanoseconds + UInt64(raceDuration * 1_000_000_000)
            condition.broadcast()   // wake every waiting thread at once, not one at a time
        }
    }

    // MARK: - Running the races

    /// Top-level driver: print the machine context, run every config `rounds`
    /// times, then summarize.
    static func run(rounds: Int) {
        guard rounds > 0 else { return }
        // Captured with every run because scheduling results are meaningless
        // without the hardware they were measured on — P/E core counts in
        // particular change the story completely.
        let machine = MachineInfo.current()
        printMachineSummary(machine)

        // Alternate configs each round so heat and background activity don't favor one config.
        // (Running all 5 control races and then all 5 experimental ones would
        // have every experimental race take place on a hotter, more throttled
        // machine — a systematic bias, not noise.)
        var races: [Race] = []
        for round in 1...rounds {
            for configIndex in configs.indices {
                let reports = race(configs[configIndex])
                printRace(round: round, config: configs[configIndex], reports: reports)
                races.append(Race(round: round, configIndex: configIndex, reports: reports))
                Thread.sleep(forTimeInterval: cooldownBetweenRaces)
            }
        }

        // Per-run detail is for the report; the aggregate is what supports any claim.
        printResultsTable(races, machine: machine)
        printAverages(races)
    }

    /// One race: start the racers and load threads, hold them at the gate, release them together, wait for all.
    private static func race(_ config: Config) -> [RacerReport] {
        let group = DispatchGroup()   // same latch pattern as Part A's harness
        let gate = StartGate()
        let store = ResultsStore()

        for (index, qos) in config.racerQoS.enumerated() {
            startThread(named: "PickerRobot\(index + 1)", qos: qos, group: group) {
                // Read the priority settings from INSIDE the thread. Reading
                // thread.qualityOfService from outside would report what we set,
                // not what this thread is actually running as.
                let current = Thread.current
                let reportedQoS = current.qualityOfService
                let priority = current.threadPriority
                // qos_class_self() is the low-level C call — the kernel's own
                // view. This is the one that tells us whether our request was
                // honored, downgraded, or ignored.
                let applied = qosClassName(qos_class_self())

                // Everything above happens before the gate, so the setup cost is
                // outside the timed window for all three racers equally.
                let deadline = gate.waitForStart()
                let iterations = countIterations(until: deadline)

                store.record(RacerReport(name: current.name ?? "?",
                                         requestedQoS: qos,
                                         reportedQoS: reportedQoS,
                                         threadPriority: priority,
                                         appliedQoSClass: applied,
                                         iterations: iterations))
            }
        }

        // The oversubscription load. Same work, unnamed in the results, QoS never
        // set — they exist only to keep every core busy so the scheduler has to
        // choose between our three racers.
        for index in 1...loadThreadCount {
            startThread(named: "LoadThread\(index)", qos: nil, group: group) {
                _ = countIterations(until: gate.waitForStart())
            }
        }

        // Main thread blocks here until all racers AND all load threads are
        // parked at the gate, then releases them simultaneously.
        gate.openWhenReady(threadCount: config.racerQoS.count + loadThreadCount, raceDuration: raceDuration)
        group.wait()
        return store.sortedReports()
    }

    /// Creates, names, and starts one thread. QoS is set before start() because NSThread.h marks
    /// qualityOfService "read-only after the thread is started". (Can move to Member 2's startWorker once it exists.)
    ///
    /// Part C needs its own creation helper rather than reusing startWorker: that
    /// one always assigns a QoS (defaulting to `.default`), and the control
    /// condition here requires leaving it genuinely untouched — hence the
    /// optional `qos` and the `if let`.
    private static func startThread(named name: String,
                                    qos: QualityOfService?,
                                    group: DispatchGroup,
                                    body: @escaping @Sendable () -> Void) {
        let thread = Thread {
            body()
            group.leave()
        }
        thread.name = name
        if let qos {
            thread.qualityOfService = qos   // only when requested; nil leaves the inherited value alone
        }
        group.enter()    // before start(), for the same reason as in Harness.swift
        thread.start()
    }

    /// The identical CPU-bound work: count loop iterations until the shared deadline.
    /// No printing, locking, or sleeping inside the loop.
    ///
    /// Why a bare counting loop: it must be pure CPU with no syscalls, no memory
    /// pressure and no I/O, or we would be measuring contention for something
    /// other than the processor. Every racer and load thread runs this exact
    /// function, so iteration counts are directly comparable — the count is a
    /// proxy for "how many CPU time slices did the scheduler hand this thread".
    private static func countIterations(until deadline: UInt64) -> Int {
        var iterations = 0
        while DispatchTime.now().uptimeNanoseconds < deadline {
            iterations += 1
        }
        return iterations
    }

    // MARK: - Output
    //
    // All printing happens on the main thread, after the threads have finished.
    // Nothing below runs while a race is in progress.

    /// Prints the hardware and thermal context. Required for the write-up: the
    /// same code produces different results on Intel vs. Apple Silicon, and on a
    /// throttled machine vs. a cool one.
    private static func printMachineSummary(_ machine: MachineInfo) {
        print("Machine: \(machine.chip) (\(machine.architecture)), macOS \(machine.osVersion)")
        // Apple Silicon splits cores into performance and efficiency types. This
        // matters enormously here: a .background thread may be parked on an
        // E-core, which is a hardware placement decision, not just a time-slice
        // one — and it is the most likely explanation for a large QoS gap.
        if let performance = machine.performanceCores, let efficiency = machine.efficiencyCores {
            print("Cores: \(machine.logicalCores) logical = \(performance) performance + \(efficiency) efficiency")
        } else {
            print("Cores: \(machine.logicalCores) logical (no P/E split reported, likely Intel)")
        }
        // Both of these can silently invalidate a run, so they are recorded
        // rather than assumed: Low Power Mode caps clocks, and a hot machine
        // throttles mid-experiment.
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled ? "ON (turn off for real runs)" : "off"
        print("Build: \(machine.buildConfiguration) · Low Power Mode: \(lowPower) · Thermal state: \(thermalStateName())")
        print("Each race: \(configs[0].racerQoS.count) PickerRobot racers + \(loadThreadCount) load threads, "
              + "\(raceDuration) s, \(cooldownBetweenRaces) s cooldown between races")
    }

    /// Per-race detail: for each racer, what we requested vs. what Thread reports
    /// vs. what the kernel applied, then the iteration count.
    private static func printRace(round: Int, config: Config, reports: [RacerReport]) {
        print("\n[Run \(round)] \(config.label)")
        for report in reports {
            let requested = report.requestedQoS.map(qosName) ?? "not set"
            print("  \(pad(report.name, 14))requested: \(pad(requested, 18))"
                  + "Thread.qualityOfService: \(pad(qosName(report.reportedQoS), 18))"
                  + "threadPriority: \(String(format: "%.2f", report.threadPriority))  "
                  + "qos_class_self(): \(report.appliedQoSClass)")
            print("  \(pad("", 14))iterations in \(raceDuration) s: \(report.iterations.formatted())")
        }
    }

    /// Emits the raw per-run numbers as a Markdown table, so the results can be
    /// pasted straight into docs/section5-priority-scheduling.md. Every run is
    /// shown, including ones that contradict the trend — that is the point of
    /// reporting all five rather than a chosen best.
    private static func printResultsTable(_ races: [Race], machine: MachineInfo) {
        print("\nResults table:")
        print("| Run | Config | Picker-1 | Picker-2 | Picker-3 | Chip | Build | Notes |")
        print("|---|---|---|---|---|---|---|---|")
        // Grouped by config rather than by round, so each condition reads as a
        // block and run-to-run variance within it is easy to eyeball.
        for configIndex in configs.indices {
            for race in races where race.configIndex == configIndex {
                let counts = race.reports.map { $0.iterations.formatted() }.joined(separator: " | ")
                print("| \(race.round) | \(configs[configIndex].label) | \(counts) | \(machine.chip) "
                      + "| \(machine.buildConfiguration) | +\(loadThreadCount) load threads |")
            }
        }
    }

    /// The actual conclusion line. Averages each racer across its runs and
    /// normalizes to the fastest racer in that config.
    ///
    /// Percentages rather than raw counts because absolute iteration counts are
    /// machine- and build-specific and mean nothing on their own; the RATIO
    /// between racers is the finding. Expect roughly 100/100/100 in the control
    /// config — if the control shows a big spread, the experiment is measuring
    /// noise and the second config's numbers can't be trusted either.
    private static func printAverages(_ races: [Race]) {
        print("\nAverage iterations per racer (% of the fastest racer in that config):")
        for (configIndex, config) in configs.enumerated() {
            let runs = races.filter { $0.configIndex == configIndex }
            guard !runs.isEmpty else { continue }
            let averages = config.racerQoS.indices.map { racer in
                runs.map { $0.reports[racer].iterations }.reduce(0, +) / runs.count
            }
            let fastest = max(averages.max() ?? 1, 1)   // max(...,1) guards against dividing by zero
            let cells = averages.enumerated().map { index, average in
                "PickerRobot\(index + 1) \(average.formatted()) (\(average * 100 / fastest)%)"
            }
            print("  \(config.label): " + cells.joined(separator: " · "))
        }
    }

    // --- Small formatting helpers -------------------------------------------

    /// Fixed-width column padding, so the per-race lines align in a terminal
    /// without pulling in a table library.
    private static func pad(_ text: String, _ width: Int) -> String {
        text.padding(toLength: max(width, text.count), withPad: " ", startingAt: 0)
    }

    /// QualityOfService is an Int-backed enum, so it prints as a bare number by
    /// default. Spelling out the case names keeps the captured output readable
    /// in the write-up.
    private static func qosName(_ qos: QualityOfService) -> String {
        switch qos {
        case .userInteractive: return ".userInteractive"
        case .userInitiated: return ".userInitiated"
        case .default: return ".default"
        case .utility: return ".utility"
        case .background: return ".background"
        // Required because QualityOfService is a non-frozen Objective-C enum:
        // Apple may add cases in a future OS, so Swift makes us handle unknowns.
        @unknown default: return "rawValue \(qos.rawValue)"
        }
    }

    /// Same idea for the C-level qos_class_t returned by qos_class_self(). This
    /// is the kernel's answer, and comparing it against the Foundation-level
    /// value above is how we tell a request that was honored from one that was not.
    private static func qosClassName(_ qosClass: qos_class_t) -> String {
        switch qosClass {
        case QOS_CLASS_USER_INTERACTIVE: return "USER_INTERACTIVE"
        case QOS_CLASS_USER_INITIATED: return "USER_INITIATED"
        case QOS_CLASS_DEFAULT: return "DEFAULT"
        case QOS_CLASS_UTILITY: return "UTILITY"
        case QOS_CLASS_BACKGROUND: return "BACKGROUND"
        case QOS_CLASS_UNSPECIFIED: return "UNSPECIFIED"
        default: return "0x" + String(qosClass.rawValue, radix: 16)
        }
    }

    /// Thermal state at the start of the run. `serious` or `critical` means the
    /// Mac is already throttling and the numbers should be rerun cool.
    private static func thermalStateName() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious (let the Mac cool down)"
        case .critical: return "critical (let the Mac cool down)"
        @unknown default: return "unknown"
        }
    }

    // MARK: - Machine details (recorded with every run)
    //
    // The brief requires every captured run to record OS, chip, cores, and debug
    // vs. release. Gathering it in code instead of by hand means the header of a
    // saved output file can never disagree with the machine that produced it.

    struct MachineInfo: Sendable {
        let osVersion: String
        let architecture: String
        let chip: String
        let logicalCores: Int
        let performanceCores: Int?   // optional: Intel Macs report no P/E split
        let efficiencyCores: Int?
        let buildConfiguration: String

        static func current() -> MachineInfo {
            // Debug vs. release changes iteration counts by an order of
            // magnitude (the counting loop is exactly what the optimizer is good
            // at), so every captured number has to say which build produced it.
            // #if DEBUG is resolved at COMPILE time, not runtime.
            #if DEBUG
            let build = "debug"
            #else
            let build = "release"
            #endif
            return MachineInfo(osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                               architecture: sysctlString("hw.machine") ?? "unknown",
                               chip: sysctlString("machdep.cpu.brand_string") ?? "unknown",
                               logicalCores: ProcessInfo.processInfo.activeProcessorCount,
                               // perflevel0 = performance cores, perflevel1 = efficiency.
                               // Absent on Intel, hence the optional.
                               performanceCores: sysctlInt("hw.perflevel0.physicalcpu"),
                               efficiencyCores: sysctlInt("hw.perflevel1.physicalcpu"),
                               buildConfiguration: build)
        }

        /// Reads a string value out of the kernel's sysctl database (the same
        /// data `sysctl -a` prints in Terminal). Foundation exposes no Swift API
        /// for chip name or P/E core counts, so we call the C function directly.
        ///
        /// Two-call idiom, standard for C APIs that return variable-length data:
        /// call once with a nil buffer to learn the size, allocate, call again to
        /// fill it. Returns nil rather than trapping if the key doesn't exist on
        /// this machine.
        private static func sysctlString(_ name: String) -> String? {
            var size = 0
            guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
            var buffer = [CChar](repeating: 0, count: size)
            guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
            return buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        }

        /// Integer variant. Size is known up front (Int32), so one call is enough.
        private static func sysctlInt(_ name: String) -> Int? {
            var value: Int32 = 0
            var size = MemoryLayout<Int32>.size
            guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
            return Int(value)
        }
    }
}
