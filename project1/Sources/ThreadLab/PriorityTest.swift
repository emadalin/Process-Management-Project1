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
// The brief forbids claiming priority guarantees order without evidence, so this
// is built as an experiment with real controls: identical work, a start gate (no
// head starts), load threads (an idle CPU makes the scheduler choose nothing),
// alternated configs over 5 rounds (thermal drift isn't a priority effect), and
// three separate priority readings — requested, reported, and kernel-applied —
// because they don't always agree.
//
// macOS exposes no raw priority to set: you state INTENT via Quality of Service
// and the kernel decides, including which core type the thread lands on.
//
// Entry point for Member 2's mode switch: runPriorityTest()
// =============================================================================

/// Runs every priority configuration `rounds` times, then prints a results table and averages.
func runPriorityTest(rounds: Int = PriorityTest.roundsPerConfig) {
    PriorityTest.run(rounds: rounds)
}

enum PriorityTest {

    // MARK: - Settings

    /// Long enough to average out scheduler noise, short enough for a demo.
    /// Time-boxed, not work-boxed: we measure work done per unit time.
    static let raceDuration: TimeInterval = 2.0
    /// The brief requires at least 5 runs per config — one run is an anecdote.
    static let roundsPerConfig = 5
    /// Pause between races so one race's heat and leftover work don't bleed into the next.
    static let cooldownBetweenRaces: TimeInterval = 1.0
    /// One load thread per logical core, so racers + load threads > cores and everything competes.
    /// The key knob: with no CPU pinning on macOS, oversubscription is the only
    /// way to force a scheduling choice. Without these, all three racers tie.
    static let loadThreadCount = ProcessInfo.processInfo.activeProcessorCount

    struct Config: Sendable {
        let label: String
        /// QoS requested for PickerRobot1, 2, 3. `nil` means never set, so the thread keeps macOS's default.
        let racerQoS: [QualityOfService?]
    }

    static let configs = [
        // Control. `nil` is not the same as `.default`: one leaves the inherited
        // setting alone, the other is an explicit assignment, and Part C asks
        // what the default actually is.
        Config(label: "All `.default`", racerQoS: [nil, nil, nil]),
        // Top, middle and bottom of the range. If QoS affects CPU share at all,
        // it shows up here or nowhere.
        Config(label: "`.userInteractive` / `.utility` / `.background`",
               racerQoS: [.userInteractive, .utility, .background]),
    ]

    // MARK: - Results

    /// What one racer reports back. Three priority readings on purpose —
    /// comparing them is itself a finding.
    struct RacerReport: Sendable {
        let name: String
        let requestedQoS: QualityOfService? // what we asked for; nil = never set
        let reportedQoS: QualityOfService   // Thread.current.qualityOfService, read inside the thread
        let threadPriority: Double          // Thread.current.threadPriority, read inside the thread
        let appliedQoSClass: String         // qos_class_self(): what the kernel actually applied
        let iterations: Int                 // the measurement
    }

    struct Race: Sendable {
        let round: Int
        let configIndex: Int
        let reports: [RacerReport]
    }

    /// Lock-protected store the racers write into. Nothing is printed until every racer has finished.
    /// Concurrent appends to a shared Array would corrupt its buffer, and keeping
    /// the printing out here means no I/O inside the timed section.
    final class ResultsStore: @unchecked Sendable {
        private let lock = NSLock()
        private var reports: [RacerReport] = []

        func record(_ report: RacerReport) {
            lock.lock()
            defer { lock.unlock() }
            reports.append(report)
        }

        /// Sorted by name so the racers always print in the same order.
        func sortedReports() -> [RacerReport] {
            lock.lock()
            defer { lock.unlock() }
            return reports.sorted { $0.name < $1.name }
        }
    }

    /// Holds every thread at the starting line, then releases them all with one shared deadline,
    /// so the thread started first doesn't get a head start (start-order bias).
    /// Without it PickerRobot1 would win every race for reasons unrelated to QoS.
    /// NSCondition, not a plain lock, because we need to wait for a condition and
    /// wake everyone at once.
    final class StartGate: @unchecked Sendable {
        private let condition = NSCondition()
        private var readyCount = 0
        private var deadline: UInt64?   // nil = closed; set = open, and this is the finish time

        /// Called by each thread. Blocks until the gate opens, then returns the shared deadline.
        func waitForStart() -> UInt64 {
            condition.lock()
            defer { condition.unlock() }
            readyCount += 1
            condition.broadcast()   // let the main thread see the new ready count
            // Loop, don't just wait once: condition variables allow spurious
            // wakeups, so a woken thread must re-check what it waited on.
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
            // One deadline for everyone. If each thread computed its own "now + 2s",
            // a late waker would also finish late and get a longer race.
            deadline = DispatchTime.now().uptimeNanoseconds + UInt64(raceDuration * 1_000_000_000)
            condition.broadcast()   // wake them all at once
        }
    }

    // MARK: - Running the races

    static func run(rounds: Int) {
        guard rounds > 0 else { return }
        // Recorded every run: scheduling results mean nothing without the
        // hardware they were measured on.
        let machine = MachineInfo.current()
        printMachineSummary(machine)

        // Alternate configs each round so heat and background activity don't favor one config.
        // All 5 control races then all 5 experimental ones would run the second
        // config on a hotter machine — a systematic bias, not noise.
        var races: [Race] = []
        for round in 1...rounds {
            for configIndex in configs.indices {
                let reports = race(configs[configIndex])
                printRace(round: round, config: configs[configIndex], reports: reports)
                races.append(Race(round: round, configIndex: configIndex, reports: reports))
                Thread.sleep(forTimeInterval: cooldownBetweenRaces)
            }
        }

        printResultsTable(races, machine: machine)
        printAverages(races)
    }

    /// One race: start the racers and load threads, hold them at the gate, release them together, wait for all.
    private static func race(_ config: Config) -> [RacerReport] {
        let group = DispatchGroup()   // same latch pattern as Part A
        let gate = StartGate()
        let store = ResultsStore()

        for (index, qos) in config.racerQoS.enumerated() {
            startThread(named: "PickerRobot\(index + 1)", qos: qos, group: group) {
                // Read from INSIDE the thread: from outside we'd only see what we set.
                let current = Thread.current
                let reportedQoS = current.qualityOfService
                let priority = current.threadPriority
                // The kernel's own view — whether our request was honored or downgraded.
                let applied = qosClassName(qos_class_self())

                // Setup is all above the gate, so it's outside the timed window.
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

        // The oversubscription load: same work, QoS never set, results ignored.
        // They exist only to keep every core busy.
        for index in 1...loadThreadCount {
            startThread(named: "LoadThread\(index)", qos: nil, group: group) {
                _ = countIterations(until: gate.waitForStart())
            }
        }

        // Blocks until everyone is parked at the gate, then releases them together.
        gate.openWhenReady(threadCount: config.racerQoS.count + loadThreadCount, raceDuration: raceDuration)
        group.wait()
        return store.sortedReports()
    }

    /// Creates, names, and starts one thread. QoS is set before start() because NSThread.h marks
    /// qualityOfService "read-only after the thread is started". (Can move to Member 2's startWorker once it exists.)
    /// Part C needs its own helper: startWorker always assigns a QoS, and the
    /// control config requires leaving it untouched — hence the optional.
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
            thread.qualityOfService = qos   // nil leaves the inherited value alone
        }
        group.enter()    // before start(), as in Harness.swift
        thread.start()
    }

    /// The identical CPU-bound work: count loop iterations until the shared deadline.
    /// No printing, locking, or sleeping inside the loop.
    /// Pure CPU, no syscalls or I/O, or we'd be measuring contention for
    /// something other than the processor. The count is a proxy for how many
    /// time slices the scheduler handed this thread.
    private static func countIterations(until deadline: UInt64) -> Int {
        var iterations = 0
        while DispatchTime.now().uptimeNanoseconds < deadline {
            iterations += 1
        }
        return iterations
    }

    // MARK: - Output
    // All on the main thread, after the races finish.

    /// Hardware and thermal context. Required for the write-up: the same code
    /// gives different results on different chips and on a throttled machine.
    private static func printMachineSummary(_ machine: MachineInfo) {
        print("Machine: \(machine.chip) (\(machine.architecture)), macOS \(machine.osVersion)")
        // The P/E split matters most: a .background thread parked on an
        // efficiency core is a hardware placement, not just a smaller time slice,
        // and is the likeliest explanation for a large QoS gap.
        if let performance = machine.performanceCores, let efficiency = machine.efficiencyCores {
            print("Cores: \(machine.logicalCores) logical = \(performance) performance + \(efficiency) efficiency")
        } else {
            print("Cores: \(machine.logicalCores) logical (no P/E split reported, likely Intel)")
        }
        // Both can silently invalidate a run, so they're recorded, not assumed.
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled ? "ON (turn off for real runs)" : "off"
        print("Build: \(machine.buildConfiguration) · Low Power Mode: \(lowPower) · Thermal state: \(thermalStateName())")
        print("Each race: \(configs[0].racerQoS.count) PickerRobot racers + \(loadThreadCount) load threads, "
              + "\(raceDuration) s, \(cooldownBetweenRaces) s cooldown between races")
    }

    /// Per-race detail: requested vs. reported vs. applied, then the count.
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

    /// Raw per-run numbers as a Markdown table, ready to paste into
    /// docs/section5-priority-scheduling.md. Every run is shown, including any
    /// that contradict the trend.
    private static func printResultsTable(_ races: [Race], machine: MachineInfo) {
        print("\nResults table:")
        print("| Run | Config | Picker-1 | Picker-2 | Picker-3 | Chip | Build | Notes |")
        print("|---|---|---|---|---|---|---|---|")
        // Grouped by config so each condition reads as a block.
        for configIndex in configs.indices {
            for race in races where race.configIndex == configIndex {
                let counts = race.reports.map { $0.iterations.formatted() }.joined(separator: " | ")
                print("| \(race.round) | \(configs[configIndex].label) | \(counts) | \(machine.chip) "
                      + "| \(machine.buildConfiguration) | +\(loadThreadCount) load threads |")
            }
        }
    }

    /// The conclusion line. Percentages, not raw counts: absolute numbers are
    /// machine- and build-specific, the ratio is the finding. Expect ~100/100/100
    /// in the control — a big spread there means we're measuring noise.
    private static func printAverages(_ races: [Race]) {
        print("\nAverage iterations per racer (% of the fastest racer in that config):")
        for (configIndex, config) in configs.enumerated() {
            let runs = races.filter { $0.configIndex == configIndex }
            guard !runs.isEmpty else { continue }
            let averages = config.racerQoS.indices.map { racer in
                runs.map { $0.reports[racer].iterations }.reduce(0, +) / runs.count
            }
            let fastest = max(averages.max() ?? 1, 1)   // guards against dividing by zero
            let cells = averages.enumerated().map { index, average in
                "PickerRobot\(index + 1) \(average.formatted()) (\(average * 100 / fastest)%)"
            }
            print("  \(config.label): " + cells.joined(separator: " · "))
        }
    }

    // --- Formatting helpers ---------------------------------------------------

    /// Fixed-width columns, so the per-race lines align in a terminal.
    private static func pad(_ text: String, _ width: Int) -> String {
        text.padding(toLength: max(width, text.count), withPad: " ", startingAt: 0)
    }

    /// QualityOfService is Int-backed and would otherwise print as a bare number.
    private static func qosName(_ qos: QualityOfService) -> String {
        switch qos {
        case .userInteractive: return ".userInteractive"
        case .userInitiated: return ".userInitiated"
        case .default: return ".default"
        case .utility: return ".utility"
        case .background: return ".background"
        // Non-frozen ObjC enum: Apple may add cases, so Swift makes us handle them.
        @unknown default: return "rawValue \(qos.rawValue)"
        }
    }

    /// The C-level class from qos_class_self() — the kernel's answer. Comparing
    /// it to the Foundation value tells us if a request was honored.
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

    /// `serious` or `critical` means the Mac is already throttling — rerun cool.
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
    // The brief requires every captured run to record OS, chip, cores and build.
    // Gathering it in code means a saved file can't disagree with the machine
    // that produced it.

    struct MachineInfo: Sendable {
        let osVersion: String
        let architecture: String
        let chip: String
        let logicalCores: Int
        let performanceCores: Int?   // nil on Intel: no P/E split
        let efficiencyCores: Int?
        let buildConfiguration: String

        static func current() -> MachineInfo {
            // Debug vs. release changes the counts by an order of magnitude — a
            // counting loop is exactly what the optimizer is good at. Resolved at
            // compile time.
            #if DEBUG
            let build = "debug"
            #else
            let build = "release"
            #endif
            return MachineInfo(osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                               architecture: sysctlString("hw.machine") ?? "unknown",
                               chip: sysctlString("machdep.cpu.brand_string") ?? "unknown",
                               logicalCores: ProcessInfo.processInfo.activeProcessorCount,
                               // perflevel0 = performance, perflevel1 = efficiency.
                               performanceCores: sysctlInt("hw.perflevel0.physicalcpu"),
                               efficiencyCores: sysctlInt("hw.perflevel1.physicalcpu"),
                               buildConfiguration: build)
        }

        /// Reads a string from the kernel's sysctl database (what `sysctl -a`
        /// prints). Foundation has no Swift API for chip name or P/E counts.
        /// Two-call C idiom: ask the size, allocate, then fill.
        private static func sysctlString(_ name: String) -> String? {
            var size = 0
            guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
            var buffer = [CChar](repeating: 0, count: size)
            guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
            return buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        }

        /// Integer variant — size known up front, so one call does it.
        private static func sysctlInt(_ name: String) -> Int? {
            var value: Int32 = 0
            var size = MemoryLayout<Int32>.size
            guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
            return Int(value)
        }
    }
}
