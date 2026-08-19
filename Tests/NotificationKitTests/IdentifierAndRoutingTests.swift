import Testing
import UserNotifications
@_spi(Testing) @testable import NotificationKit

struct IdentifierAndRoutingTests {
    @Test
    func identifiersAreStableAndNamespaceScoped() throws {
        let namespace = try NotificationNamespace("daily-reminders")

        #expect(try namespace.identifier(for: "evening.v1")
                == "NotificationKit.daily-reminders.evening.v1")
        #expect(namespace.owns("NotificationKit.daily-reminders.evening.v1"))
        #expect(!namespace.owns("NotificationKit.other.evening.v1"))
    }

    @Test
    func invalidIdentifiersAreRejected() {
        #expect(throws: NotificationIdentifierError.self) {
            try NotificationNamespace("daily reminders")
        }
        #expect(throws: NotificationIdentifierError.self) {
            try DesiredNotification(
                id: "bad/id",
                title: "Title",
                body: "Body",
                trigger: .timeInterval(60, repeats: false)
            )
        }
    }

    @Test
    func managedDefaultTapProducesTypedSource() {
        let response = NotificationCenterDelegateAdapter.makeResponse(
            identifier: "NotificationKit.daily.morning",
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            payload: ["route": "today"]
        )

        #expect(response == NotificationResponse(
            source: .managed(namespace: "daily", id: "morning"),
            action: .defaultTap,
            payload: ["route": "today"]
        ))
    }

    @Test
    func unmanagedAndTextInputResponsesRemainRoutable() {
        let response = NotificationCenterDelegateAdapter.makeResponse(
            identifier: "remote.apns",
            actionIdentifier: "reply",
            userText: "Done",
            payload: ["record": "42"]
        )

        #expect(response.source == .unmanaged(identifier: "remote.apns"))
        #expect(response.action == .textInput(id: "reply", text: "Done"))
    }
}
