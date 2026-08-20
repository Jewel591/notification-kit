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

    init(
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.now = now
    }

    func contains(_ identifier: String) -> Bool {
        let receipts = loadAndPrune()
        let contains = receipts[identifier] != nil
        persist(receipts)
        return contains
    }

    func insert(_ identifier: String) {
        var receipts = loadAndPrune()
        receipts[identifier] = now().timeIntervalSince1970
        if receipts.count > Policy.maximumCount {
            let overflow = receipts.count - Policy.maximumCount
            for key in receipts.sorted(by: { $0.value < $1.value })
                .prefix(overflow)
                .map(\.key)
            {
                receipts.removeValue(forKey: key)
            }
        }
        persist(receipts)
    }

    private func loadAndPrune() -> [String: TimeInterval] {
        guard let data = defaults.data(forKey: Policy.key),
              var receipts = try? JSONDecoder().decode(
                  [String: TimeInterval].self,
                  from: data
              )
        else {
            return [:]
        }
        let cutoff = now().timeIntervalSince1970 - Policy.retention
        receipts = receipts.filter { $0.value >= cutoff }
        return receipts
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
