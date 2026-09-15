import Foundation

/// The shared resource for Sections 3 and 4 of the demo (Part B).
///
/// `@unchecked Sendable`: we're telling the Swift 6 compiler "trust us, we
/// handle thread safety ourselves" so this instance can be captured by
/// multiple `Thread` closures. In `unsync` mode we deliberately don't
/// actually handle it — that's the bug we're demonstrating.
final class VendingMachine: @unchecked Sendable {

    // MARK: - Shared state (Section 1 — the three counters everything races on)

    var itemsInStock: Int
    var coinBoxCents: Int
    var cashCollectedCents: Int

    // MARK: - Configuration
    // Agreed shape, not final values — adjust together if the demo needs different numbers.

    let itemPriceCents: Int
    let comboSize: Int
    let restockThreshold: Int
    let restockTraySize: Int

    // MARK: - Synchronization (Member 4 wires this up in the Safe methods below)

    private let lock = NSLock()

    init(startingStock: Int = 10_000,
         itemPriceCents: Int = 150,
         comboSize: Int = 3,
         restockThreshold: Int = 500,
         restockTraySize: Int = 50) {
        self.itemsInStock = startingStock
        self.coinBoxCents = 0
        self.cashCollectedCents = 0
        self.itemPriceCents = itemPriceCents
        self.comboSize = comboSize
        self.restockThreshold = restockThreshold
        self.restockTraySize = restockTraySize
    }

    // MARK: - Unsynchronized methods (Member 3, Part B first half)
    // TODO(Member 3): read -> sched_yield() -> write, to widen the timing window
    // and expose (not create) the race. Keep prints out of these — they slow
    // threads and hide races.

    /// If stock > 0, take 1 item and add its price to the coin box.
    @discardableResult
    func buyOneUnsafe() -> Bool {
        fatalError("TODO(Member 3): implement buyOneUnsafe")
    }

    /// If stock >= comboSize, take comboSize items and add comboSize x price.
    @discardableResult
    func buyComboUnsafe() -> Bool {
        fatalError("TODO(Member 3): implement buyComboUnsafe")
    }

    /// When stock drops below restockThreshold, load a tray of restockTraySize.
    func restockUnsafe() {
        fatalError("TODO(Member 3): implement restockUnsafe")
    }

    /// Read coinBoxCents, add it to cashCollectedCents, reset the box to 0.
    func collectCashUnsafe() {
        fatalError("TODO(Member 3): implement collectCashUnsafe")
    }

    // MARK: - Synchronized methods (Member 4, Part B second half)
    // TODO(Member 4): lock.lock() + defer { lock.unlock() }, identical logic
    // to the Unsafe versions above — same checks, same math, just guarded.

    /// Safe counterpart of buyOneUnsafe().
    @discardableResult
    func buyOneSafe() -> Bool {
        fatalError("TODO(Member 4): implement buyOneSafe")
    }

    /// Safe counterpart of buyComboUnsafe().
    @discardableResult
    func buyComboSafe() -> Bool {
        fatalError("TODO(Member 4): implement buyComboSafe")
    }

    /// Safe counterpart of restockUnsafe().
    func restockSafe() {
        fatalError("TODO(Member 4): implement restockSafe")
    }

    /// Safe counterpart of collectCashUnsafe().
    func collectCashSafe() {
        fatalError("TODO(Member 4): implement collectCashSafe")
    }
}
