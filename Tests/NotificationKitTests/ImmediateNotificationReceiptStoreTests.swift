import Foundation
import Testing
@testable import NotificationKit

@MainActor
struct ImmediateNotificationReceiptStoreTests {
    @Test func receiptsPersistAcrossStoreInstances() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let now = Date(timeIntervalSince1970: 1_000_000)
        UserDefaultsImmediateNotificationReceiptStore(
            defaults: defaults,
            now: { now }
        ).insert("event-a")

        let restored = UserDefaultsImmediateNotificationReceiptStore(
            defaults: defaults,
            now: { now }
        )
        #expect(restored.contains("event-a"))
    }

    @Test func receiptsExpireAfterFixedRetentionWindow() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var now = Date(timeIntervalSince1970: 2_000_000)
        let store = UserDefaultsImmediateNotificationReceiptStore(
            defaults: defaults,
            now: { now }
        )
        store.insert("event-a")
        now.addTimeInterval(90 * 24 * 60 * 60 + 1)

        #expect(!store.contains("event-a"))
    }

    @Test func receiptHistoryKeepsOnlyNewest512Entries() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var timestamp: TimeInterval = 3_000_000
        let store = UserDefaultsImmediateNotificationReceiptStore(
            defaults: defaults,
            now: { Date(timeIntervalSince1970: timestamp) }
        )
        for index in 0..<513 {
            store.insert("event-\(index)")
            timestamp += 1
        }

        #expect(!store.contains("event-0"))
        #expect(store.contains("event-1"))
        #expect(store.contains("event-512"))
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "NotificationKitTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
