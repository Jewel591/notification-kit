import Testing
import UserNotifications
@_spi(Testing) @testable import NotificationKit

@MainActor
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
    func legacyPrefixesCannotAdoptManagedIdentifierFamilies() {
        #expect(throws: NotificationIdentifierError.invalidLegacyPrefix(
            "NotificationKit."
        )) {
            try NotificationNamespace(
                "daily",
                legacyPrefixes: ["NotificationKit."]
            )
        }
        #expect(throws: NotificationIdentifierError.invalidLegacyPrefix(
            "NotificationKitImmediate.other."
        )) {
            try NotificationNamespace(
                "daily",
                legacyPrefixes: ["NotificationKitImmediate.other."]
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
    func immediateManagedTapProducesTypedSource() {
        let response = NotificationCenterDelegateAdapter.makeResponse(
            identifier: "NotificationKitImmediate.imports.complete-42",
            actionIdentifier: UNNotificationDefaultActionIdentifier
        )

        #expect(response.source == .managed(
            namespace: "imports",
            id: "complete-42"
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

    @Test
    func responseRoutingAndSystemCompletionReturnToMainThread() async {
        let response = NotificationResponse(
            source: .unmanaged(identifier: "remote.apns"),
            action: .defaultTap,
            payload: [:]
        )
        let recorder = CallbackThreadRecorder()

        let completionWasOnMainThread = await withCheckedContinuation {
            continuation in
            DispatchQueue.global().async {
                NotificationCenterDelegateAdapter.completeResponse(
                    response,
                    route: { _ in
                        recorder.routeWasOnMainThread = Thread.isMainThread
                    },
                    completionHandler: {
                        continuation.resume(returning: Thread.isMainThread)
                    }
                )
            }
        }

        #expect(recorder.routeWasOnMainThread)
        #expect(completionWasOnMainThread)
    }
}

@MainActor
private final class CallbackThreadRecorder {
    var routeWasOnMainThread = false
}
