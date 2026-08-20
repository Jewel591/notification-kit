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

    @Test func unreadableLedgerIsPreservedAndUsesProcessLocalRecovery() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let key = "com.jewel591.NotificationKit.immediateReceipts.v1"
        let unreadableData = Data("not-json".utf8)
        defaults.set(unreadableData, forKey: key)
        let store = UserDefaultsImmediateNotificationReceiptStore(
            defaults: defaults,
            now: { Date(timeIntervalSince1970: 4_000_000) }
        )

        #expect(!store.contains("event-a"))
        store.insert("event-a")

        #expect(store.contains("event-a"))
        #expect(defaults.data(forKey: key) == unreadableData)
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "NotificationKitTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
