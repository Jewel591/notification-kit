import Foundation
import Testing
@_spi(Testing) @testable import NotificationKit

@MainActor
struct ImmediateNotificationTests {
    @Test
    func successfulEventNotificationRecordsAnIdempotencyReceipt() async throws {
        let center = TestNotificationCenter()
        let receipts = TestImmediateReceiptStore()
        let client = NotificationClient(
            testingCenter: center,
            lifecycleSource: TestNotificationLifecycleSource(),
            immediateReceipts: receipts
        )
        let notification = try ImmediateNotification(
            id: "import-complete-42",
            title: "Import complete",
            body: "Your items are ready.",
            payload: ["route": "imports/42"]
        )

        let outcome = await client.submitImmediately(
            namespace: try NotificationNamespace("imports"),
            notification: notification
        )

        #expect(outcome == .submitted(
            identifier: "NotificationKitImmediate.imports.import-complete-42"
        ))
        #expect(await center.immediateSubmissions.count == 1)
        #expect(await center.immediateSubmissions.first?.payload == [
            "route": "imports/42"
        ])
        #expect(await center.pending.isEmpty)
        #expect(receipts.identifiers == [
            "NotificationKitImmediate.imports.import-complete-42"
        ])
    }

    @Test
    func repeatedAndOverlappingSubmissionsNotifyOnlyOnce() async throws {
        let center = TestNotificationCenter()
        let receipts = TestImmediateReceiptStore()
        let client = NotificationClient(
            testingCenter: center,
            lifecycleSource: TestNotificationLifecycleSource(),
            immediateReceipts: receipts
        )
        let namespace = try NotificationNamespace("imports")
        let notification = try ImmediateNotification(
            id: "complete-42",
            title: "Complete",
            body: "Body"
        )

        async let first = client.submitImmediately(
            namespace: namespace,
            notification: notification
        )
        async let second = client.submitImmediately(
            namespace: namespace,
            notification: notification
        )
        let concurrent = await [first, second]
        let retry = await client.submitImmediately(
            namespace: namespace,
            notification: notification
        )

        #expect(concurrent == [
            .submitted(identifier: "NotificationKitImmediate.imports.complete-42"),
            .submitted(identifier: "NotificationKitImmediate.imports.complete-42"),
        ])
        #expect(retry == .alreadySubmitted(
            identifier: "NotificationKitImmediate.imports.complete-42"
        ))
        #expect(await center.immediateSubmissions.count == 1)
    }

    @Test
    func immediateSubmissionNeverPromptsWhenAuthorizationIsUnavailable() async throws {
        let center = TestNotificationCenter()
        await center.configure(authorization: .notDetermined)
        let client = NotificationClient(testingCenter: center)

        let outcome = await client.submitImmediately(
            namespace: try NotificationNamespace("imports"),
            notification: try ImmediateNotification(
                id: "complete",
                title: "Complete",
                body: "Body"
            )
        )

        #expect(outcome == .authorizationUnavailable(.notDetermined))
        #expect(await center.requestCount == 0)
        #expect(await center.immediateSubmissions.isEmpty)
    }

    @Test
    func immediateSubmissionReportsCenterFailure() async throws {
        let center = TestNotificationCenter()
        await center.configure(failingIdentifiers: [
            "NotificationKitImmediate.imports.complete"
        ])
        let client = NotificationClient(testingCenter: center)

        let outcome = await client.submitImmediately(
            namespace: try NotificationNamespace("imports"),
            notification: try ImmediateNotification(
                id: "complete",
                title: "Complete",
                body: "Body"
            )
        )

        #expect(outcome == .failed(
            identifier: "NotificationKitImmediate.imports.complete"
        ))
        #expect(await center.immediateSubmissions.isEmpty)
    }

    @Test
    func immediateNotificationRejectsInvalidIdentifiers() {
        #expect(throws: NotificationIdentifierError.self) {
            try ImmediateNotification(
                id: "bad/id",
                title: "Title",
                body: "Body"
            )
        }
    }
}
