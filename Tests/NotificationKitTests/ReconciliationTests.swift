import Foundation
import Testing
@_spi(Testing) @testable import NotificationKit

@MainActor
struct ReconciliationTests {
    @Test
    func notLoadedNeverErasesExistingRequests() async throws {
        let center = TestNotificationCenter()
        await center.configure(pending: [
            PendingNotificationSnapshot(identifier: "NotificationKit.daily.existing")
        ])
        let client = NotificationClient(testingCenter: center, router: TestRouter())
        let namespace = try NotificationNamespace("daily")

        let report = await client.reconcile(namespace: namespace, desired: .notLoaded)

        #expect(report.disposition == .notLoaded)
        #expect(await center.removedPending.isEmpty)
        #expect(await center.scheduled.isEmpty)
    }

    @Test
    func loadedEmptyClearsOnlyItsNamespace() async throws {
        let center = TestNotificationCenter()
        await center.configure(
            pending: [
                PendingNotificationSnapshot(identifier: "NotificationKit.daily.old"),
                PendingNotificationSnapshot(identifier: "NotificationKit.other.keep"),
                PendingNotificationSnapshot(identifier: "host.keep"),
            ],
            delivered: ["NotificationKit.daily.delivered", "host.delivered"]
        )
        let client = NotificationClient(testingCenter: center, router: TestRouter())
        let namespace = try NotificationNamespace("daily")

        let report = await client.reconcile(namespace: namespace, desired: .loaded([]))

        #expect(report.disposition == .reconciled)
        #expect(await center.removedPending == ["NotificationKit.daily.old"])
        #expect(await center.removedDelivered == ["NotificationKit.daily.delivered"])
        #expect(await center.pending.map(\.identifier).sorted() == [
            "NotificationKit.other.keep", "host.keep"
        ])
    }

    @Test
    func unchangedFingerprintDoesNotReschedule() async throws {
        let desired = try makeDesired(id: "morning")
        let fingerprint = NotificationFingerprint.make(for: desired)
        let center = TestNotificationCenter()
        await center.configure(pending: [PendingNotificationSnapshot(
            identifier: "NotificationKit.daily.morning",
            fingerprint: fingerprint
        )])
        let client = NotificationClient(testingCenter: center, router: TestRouter())

        let report = await client.reconcile(
            namespace: try NotificationNamespace("daily"),
            desired: .loaded([desired])
        )

        #expect(report.unchanged == ["NotificationKit.daily.morning"])
        #expect(await center.scheduled.isEmpty)
    }

    @Test
    func payloadFieldBoundariesCannotCollideInFingerprint() throws {
        let first = try DesiredNotification(
            id: "same",
            title: "Reminder",
            body: "Body",
            payload: ["a": "b&c=d"],
            trigger: .timeInterval(60, repeats: false)
        )
        let second = try DesiredNotification(
            id: "same",
            title: "Reminder",
            body: "Body",
            payload: ["a": "b", "c": "d"],
            trigger: .timeInterval(60, repeats: false)
        )

        #expect(NotificationFingerprint.make(for: first)
                != NotificationFingerprint.make(for: second))
    }

    @Test
    func changedContentReplacesTheSameStableIdentifier() async throws {
        let center = TestNotificationCenter()
        await center.configure(pending: [PendingNotificationSnapshot(
            identifier: "NotificationKit.daily.morning",
            fingerprint: "old"
        )])
        let client = NotificationClient(testingCenter: center, router: TestRouter())

        let report = await client.reconcile(
            namespace: try NotificationNamespace("daily"),
            desired: .loaded([try makeDesired(id: "morning", title: "Updated")])
        )

        #expect(report.scheduled == ["NotificationKit.daily.morning"])
        #expect(await center.scheduled.count == 1)
    }

    @Test
    func legacyPrefixIsRemovedAndRewritten() async throws {
        let center = TestNotificationCenter()
        await center.configure(pending: [
            PendingNotificationSnapshot(identifier: "legacy.daily.morning")
        ])
        let client = NotificationClient(testingCenter: center, router: TestRouter())

        let report = await client.reconcile(
            namespace: try NotificationNamespace(
                "daily",
                legacyPrefixes: ["legacy.daily."]
            ),
            desired: .loaded([try makeDesired(id: "morning")])
        )

        #expect(report.removed.contains("legacy.daily.morning"))
        #expect(report.scheduled == ["NotificationKit.daily.morning"])
    }

    @Test
    func deniedAuthorizationClearsNamespaceWithoutRequestingPermission() async throws {
        let center = TestNotificationCenter()
        await center.configure(
            authorization: .denied,
            pending: [PendingNotificationSnapshot(
                identifier: "NotificationKit.daily.morning"
            )]
        )
        let client = NotificationClient(testingCenter: center, router: TestRouter())

        let report = await client.reconcile(
            namespace: try NotificationNamespace("daily"),
            desired: .loaded([try makeDesired(id: "morning")])
        )

        #expect(report.disposition == .authorizationUnavailable(.denied))
        #expect(await center.requestCount == 0)
        #expect(await center.removedPending == ["NotificationKit.daily.morning"])
    }

    @Test
    func globalCapacityPreservesForeignRequestsAndKeepsSoonestDesired() async throws {
        let center = TestNotificationCenter()
        await center.configure(pending: (0..<63).map {
            PendingNotificationSnapshot(identifier: "foreign.\($0)")
        })
        let client = NotificationClient(testingCenter: center, router: TestRouter())

        let report = await client.reconcile(
            namespace: try NotificationNamespace("daily"),
            desired: .loaded([
                try DesiredNotification(
                    id: "late",
                    title: "Late",
                    body: "Body",
                    trigger: .timeInterval(120, repeats: false)
                ),
                try DesiredNotification(
                    id: "early",
                    title: "Early",
                    body: "Body",
                    trigger: .timeInterval(60, repeats: false)
                ),
            ])
        )

        #expect(report.scheduled == ["NotificationKit.daily.early"])
        #expect(report.overflow == ["late"])
        #expect(await center.pending.filter { $0.identifier.hasPrefix("foreign.") }.count == 63)
    }

    @Test
    func invalidOrDuplicateDesiredSetDoesNotMutateTheCenter() async throws {
        let center = TestNotificationCenter()
        let client = NotificationClient(testingCenter: center, router: TestRouter())
        let duplicate = try makeDesired(id: "same")

        let report = await client.reconcile(
            namespace: try NotificationNamespace("daily"),
            desired: .loaded([duplicate, duplicate])
        )

        #expect(report.disposition == .invalidDesiredSet)
        #expect(await center.scheduled.isEmpty)
        #expect(await center.removedPending.isEmpty)
    }

    @Test
    func newerDisableSupersedesAnOverlappingScheduleRefresh() async throws {
        let center = TestNotificationCenter()
        await center.configure(
            pendingDelayNanoseconds: 100_000_000,
            pending: [PendingNotificationSnapshot(
                identifier: "NotificationKit.daily.old"
            )]
        )
        let client = NotificationClient(testingCenter: center, router: TestRouter())
        let namespace = try NotificationNamespace("daily")
        let refreshed = try makeDesired(id: "new")

        let staleRefresh = Task {
            await client.reconcile(
                namespace: namespace,
                desired: .loaded([refreshed])
            )
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        let disable = await client.reconcile(
            namespace: namespace,
            desired: .loaded([])
        )

        #expect(await staleRefresh.value.disposition == .superseded)
        #expect(disable.disposition == .reconciled)
        #expect(await center.pending.isEmpty)
        #expect(await center.scheduled.isEmpty)
    }

    @Test
    func differentNamespacesShareOneCapacitySnapshotAtATime() async throws {
        let center = TestNotificationCenter()
        await center.configure(pendingDelayNanoseconds: 50_000_000)
        let client = NotificationClient(testingCenter: center)
        let first = try NotificationNamespace("first")
        let second = try NotificationNamespace("second")
        let firstDesired = try (0..<40).map {
            try DesiredNotification(
                id: "item-\($0)",
                title: "First",
                body: "Body",
                trigger: .timeInterval(TimeInterval(60 + $0), repeats: false)
            )
        }
        let secondDesired = try (0..<40).map {
            try DesiredNotification(
                id: "item-\($0)",
                title: "Second",
                body: "Body",
                trigger: .timeInterval(TimeInterval(60 + $0), repeats: false)
            )
        }

        async let firstReport = client.reconcile(
            namespace: first,
            desired: .loaded(firstDesired)
        )
        async let secondReport = client.reconcile(
            namespace: second,
            desired: .loaded(secondDesired)
        )
        let reports = await [firstReport, secondReport]

        #expect(reports.reduce(0) { $0 + $1.scheduled.count } == 64)
        #expect(reports.reduce(0) { $0 + $1.overflow.count } == 16)
        #expect(await center.pending.count == 64)
    }
}
