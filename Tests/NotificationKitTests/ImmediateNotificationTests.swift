import Foundation
import Testing
@_spi(Testing) @testable import NotificationKit

@MainActor
struct ImmediateNotificationTests {
    @Test
    func eventNotificationIsSubmittedOnceWithoutEnteringPendingState() async throws {
        let center = TestNotificationCenter()
        let client = NotificationClient(testingCenter: center)
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
            identifier: "NotificationKit.imports.import-complete-42"
        ))
        #expect(await center.immediateSubmissions.count == 1)
        #expect(await center.immediateSubmissions.first?.payload == [
            "route": "imports/42"
        ])
        #expect(await center.pending.isEmpty)
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
            "NotificationKit.imports.complete"
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
            identifier: "NotificationKit.imports.complete"
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
