import Foundation

// Owner: Member 5 (Sarah Rae & Calli), Part C: priority / scheduling investigation.
//
// Three identical CPU-bound PickerRobot racers count loop iterations for a fixed
// 2 seconds. We compare how much work each one gets done with all-default QoS vs.
// .userInteractive / .utility / .background. Extra load threads make sure there are
// more busy threads than cores, because macOS has no CPU pinning.
//
// Entry point for Member 2's mode switch: runPriorityTest()

/// Runs every priority configuration `rounds` times, then prints a results table and averages.
func runPriorityTest(rounds: Int = PriorityTest.roundsPerConfig) {
    PriorityTest.run(rounds: rounds)
}

enum PriorityTest {

    // MARK: - Settings

    static let raceDuration: TimeInterval = 2.0
    static let roundsPerConfig = 5
    /// Pause between races so one race's heat and leftover work don't bleed into the next.
    static let cooldownBetweenRaces: TimeInterval = 1.0
    /// One load thread per logical core, so racers + load threads > cores and everything competes.
    static let loadThreadCount = ProcessInfo.processInfo.activeProcessorCount

    struct Config: Sendable {
        let label: String
        /// QoS requested for PickerRobot1, 2, 3. `nil` means never set, so the thread keeps macOS's default.
        let racerQoS: [QualityOfService?]
    }

    static let configs = [
        Config(label: "All `.default`", racerQoS: [nil, nil, nil]),
        Config(label: "`.userInteractive` / `.utility` / `.background`",
               racerQoS: [.userInteractive, .utility, .background]),
    ]

    // MARK: - Results

    struct RacerReport: Sendable {
        let name: String
        let requestedQoS: QualityOfService?
        let reportedQoS: QualityOfService   // Thread.current.qualityOfService, read inside the thread
        let threadPriority: Double          // Thread.current.threadPriority, read inside the thread
        let appliedQoSClass: String         // qos_class_self(): what the kernel actually applied
        let iterations: Int
    }

    struct Race: Sendable {
        let round: Int
        let configIndex: Int
        let reports: [RacerReport]
    }

    /// Lock-protected store the racers write into. Nothing is printed until every racer has finished.
    final class ResultsStore: @unchecked Sendable {
        private let lock = NSLock()
        private var reports: [RacerReport] = []

        func record(_ report: RacerReport) {
            lock.lock()
            defer { lock.unlock() }
            reports.append(report)
        }

        func sortedReports() -> [RacerReport] {
            lock.lock()
            defer { lock.unlock() }
            return reports.sorted { $0.name < $1.name }
        }
    }

    /// Holds every thread at the starting line, then releases them all with one shared deadline,
    /// so the thread started first doesn't get a head start (start-order bias).
    final class StartGate: @unchecked Sendable {
        private let condition = NSCondition()
        private var readyCount = 0
        private var deadline: UInt64?

        /// Called by each thread. Blocks until the gate opens, then returns the shared deadline.
        func waitForStart() -> UInt64 {
            condition.lock()
            defer { condition.unlock() }
            readyCount += 1
            condition.broadcast()   // let the main thread see the new ready count
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
            deadline = DispatchTime.now().uptimeNanoseconds + UInt64(raceDuration * 1_000_000_000)
            condition.broadcast()
        }
    }

    // MARK: - Running the races

    static func run(rounds: Int) {
        guard rounds > 0 else { return }
        let machine = MachineInfo.current()
        printMachineSummary(machine)

        // Alternate configs each round so heat and background activity don't favor one config.
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
        let group = DispatchGroup()
        let gate = StartGate()
        let store = ResultsStore()

        for (index, qos) in config.racerQoS.enumerated() {
            startThread(named: "PickerRobot\(index + 1)", qos: qos, group: group) {
                let current = Thread.current
                let reportedQoS = current.qualityOfService
                let priority = current.threadPriority
                let applied = qosClassName(qos_class_self())

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

        for index in 1...loadThreadCount {
            startThread(named: "LoadThread\(index)", qos: nil, group: group) {
                _ = countIterations(until: gate.waitForStart())
            }
        }

        gate.openWhenReady(threadCount: config.racerQoS.count + loadThreadCount, raceDuration: raceDuration)
        group.wait()
        return store.sortedReports()
    }

    /// Creates, names, and starts one thread. QoS is set before start() because NSThread.h marks
    /// qualityOfService "read-only after the thread is started". (Can move to Member 2's startWorker once it exists.)
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
            thread.qualityOfService = qos
        }
        group.enter()
        thread.start()
    }

    /// The identical CPU-bound work: count loop iterations until the shared deadline.
    /// No printing, locking, or sleeping inside the loop.
    private static func countIterations(until deadline: UInt64) -> Int {
        var iterations = 0
        while DispatchTime.now().uptimeNanoseconds < deadline {
            iterations += 1
        }
        return iterations
    }

    // MARK: - Output

    private static func printMachineSummary(_ machine: MachineInfo) {
        print("Machine: \(machine.chip) (\(machine.architecture)), macOS \(machine.osVersion)")
        if let performance = machine.performanceCores, let efficiency = machine.efficiencyCores {
            print("Cores: \(machine.logicalCores) logical = \(performance) performance + \(efficiency) efficiency")
        } else {
            print("Cores: \(machine.logicalCores) logical (no P/E split reported, likely Intel)")
        }
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled ? "ON (turn off for real runs)" : "off"
        print("Build: \(machine.buildConfiguration) · Low Power Mode: \(lowPower) · Thermal state: \(thermalStateName())")
        print("Each race: \(configs[0].racerQoS.count) PickerRobot racers + \(loadThreadCount) load threads, "
              + "\(raceDuration) s, \(cooldownBetweenRaces) s cooldown between races")
    }

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

    private static func printResultsTable(_ races: [Race], machine: MachineInfo) {
        print("\nResults table:")
        print("| Run | Config | Picker-1 | Picker-2 | Picker-3 | Chip | Build | Notes |")
        print("|---|---|---|---|---|---|---|---|")
        for configIndex in configs.indices {
            for race in races where race.configIndex == configIndex {
                let counts = race.reports.map { $0.iterations.formatted() }.joined(separator: " | ")
                print("| \(race.round) | \(configs[configIndex].label) | \(counts) | \(machine.chip) "
                      + "| \(machine.buildConfiguration) | +\(loadThreadCount) load threads |")
            }
        }
    }

    private static func printAverages(_ races: [Race]) {
        print("\nAverage iterations per racer (% of the fastest racer in that config):")
        for (configIndex, config) in configs.enumerated() {
            let runs = races.filter { $0.configIndex == configIndex }
            guard !runs.isEmpty else { continue }
            let averages = config.racerQoS.indices.map { racer in
                runs.map { $0.reports[racer].iterations }.reduce(0, +) / runs.count
            }
            let fastest = max(averages.max() ?? 1, 1)
            let cells = averages.enumerated().map { index, average in
                "PickerRobot\(index + 1) \(average.formatted()) (\(average * 100 / fastest)%)"
            }
            print("  \(config.label): " + cells.joined(separator: " · "))
        }
    }

    private static func pad(_ text: String, _ width: Int) -> String {
        text.padding(toLength: max(width, text.count), withPad: " ", startingAt: 0)
    }

    private static func qosName(_ qos: QualityOfService) -> String {
        switch qos {
        case .userInteractive: return ".userInteractive"
        case .userInitiated: return ".userInitiated"
        case .default: return ".default"
        case .utility: return ".utility"
        case .background: return ".background"
        @unknown default: return "rawValue \(qos.rawValue)"
        }
    }

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

    struct MachineInfo: Sendable {
        let osVersion: String
        let architecture: String
        let chip: String
        let logicalCores: Int
        let performanceCores: Int?
        let efficiencyCores: Int?
        let buildConfiguration: String

        static func current() -> MachineInfo {
            #if DEBUG
            let build = "debug"
            #else
            let build = "release"
            #endif
            return MachineInfo(osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                               architecture: sysctlString("hw.machine") ?? "unknown",
                               chip: sysctlString("machdep.cpu.brand_string") ?? "unknown",
                               logicalCores: ProcessInfo.processInfo.activeProcessorCount,
                               performanceCores: sysctlInt("hw.perflevel0.physicalcpu"),
                               efficiencyCores: sysctlInt("hw.perflevel1.physicalcpu"),
                               buildConfiguration: build)
        }

        private static func sysctlString(_ name: String) -> String? {
            var size = 0
            guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
            var buffer = [CChar](repeating: 0, count: size)
            guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
            return buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        }

        private static func sysctlInt(_ name: String) -> Int? {
            var value: Int32 = 0
            var size = MemoryLayout<Int32>.size
            guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
            return Int(value)
        }
    }
}
