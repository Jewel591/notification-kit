import Foundation

@MainActor
final class UserDefaultsImmediateNotificationReceiptStore:
    ImmediateNotificationReceiptStoring
{
    private enum Policy {
        static let key = "com.jewel591.NotificationKit.immediateReceipts.v1"
        static let retention: TimeInterval = 90 * 24 * 60 * 60
        static let maximumCount = 512
    }

    private let defaults: UserDefaults
    private let now: () -> Date
    private var volatileRecoveryReceipts: [String: TimeInterval] = [:]

    init(
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.now = now
    }

    func contains(_ identifier: String) -> Bool {
        switch loadAndPrune() {
        case let .loaded(receipts):
            persist(receipts)
            return receipts[identifier] != nil
        case .unreadable:
            pruneVolatileRecoveryReceipts()
            return volatileRecoveryReceipts[identifier] != nil
        }
    }

    func insert(_ identifier: String) {
        switch loadAndPrune() {
        case var .loaded(receipts):
            receipts[identifier] = now().timeIntervalSince1970
            trimToMaximumCount(&receipts)
            persist(receipts)
        case .unreadable:
            pruneVolatileRecoveryReceipts()
            volatileRecoveryReceipts[identifier] = now().timeIntervalSince1970
            trimToMaximumCount(&volatileRecoveryReceipts)
        }
    }

    private enum LoadResult {
        case loaded([String: TimeInterval])
        case unreadable
    }

    private func loadAndPrune() -> LoadResult {
        guard let data = defaults.data(forKey: Policy.key) else {
            return .loaded([:])
        }
        guard var receipts = try? JSONDecoder().decode(
            [String: TimeInterval].self,
            from: data
        ) else {
            return .unreadable
        }
        let cutoff = now().timeIntervalSince1970 - Policy.retention
        receipts = receipts.filter { $0.value >= cutoff }
        return .loaded(receipts)
    }

    private func pruneVolatileRecoveryReceipts() {
        let cutoff = now().timeIntervalSince1970 - Policy.retention
        volatileRecoveryReceipts = volatileRecoveryReceipts.filter {
            $0.value >= cutoff
        }
    }

    private func trimToMaximumCount(_ receipts: inout [String: TimeInterval]) {
        guard receipts.count > Policy.maximumCount else { return }
        let overflow = receipts.count - Policy.maximumCount
        for key in receipts.sorted(by: { $0.value < $1.value })
            .prefix(overflow)
            .map(\.key)
        {
            receipts.removeValue(forKey: key)
        }
    }

    private func persist(_ receipts: [String: TimeInterval]) {
        guard let data = try? JSONEncoder().encode(receipts) else { return }
        defaults.set(data, forKey: Policy.key)
    }
}

@MainActor
final class MemoryImmediateNotificationReceiptStore:
    ImmediateNotificationReceiptStoring
{
    private var identifiers: Set<String> = []

    func contains(_ identifier: String) -> Bool {
        identifiers.contains(identifier)
    }

    func insert(_ identifier: String) {
        identifiers.insert(identifier)
    }
}
