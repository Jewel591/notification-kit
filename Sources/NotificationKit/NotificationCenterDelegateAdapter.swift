import Foundation
@preconcurrency import UserNotifications

final class NotificationCenterDelegateAdapter: NSObject, UNUserNotificationCenterDelegate {
    private let routerBox: NotificationRouterBox

    @MainActor
    init(router: (any NotificationResponseRouting)?) {
        routerBox = NotificationRouterBox(router: router)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let routed = Self.makeResponse(from: response)
        let routerBox = routerBox
        let completion = UncheckedSendable(value: completionHandler)
        Task { @MainActor in
            routerBox.router?.handle(routed)
            completion.value()
        }
    }

    static func parseManagedIdentifier(
        _ identifier: String
    ) -> (namespace: String, id: String)? {
        let prefix = "NotificationKit."
        guard identifier.hasPrefix(prefix) else { return nil }
        let remainder = identifier.dropFirst(prefix.count)
        guard let separator = remainder.firstIndex(of: ".") else { return nil }
        let namespace = String(remainder[..<separator])
        let id = String(remainder[remainder.index(after: separator)...])
        guard !namespace.isEmpty, !id.isEmpty else { return nil }
        return (namespace, id)
    }

    static func makeResponse(from response: UNNotificationResponse) -> NotificationResponse {
        let identifier = response.notification.request.identifier
        let payload = response.notification.request.content.userInfo.reduce(
            into: [String: String]()
        ) { result, item in
            guard let key = item.key as? String,
                  !key.hasPrefix("NotificationKit."),
                  let value = item.value as? String else { return }
            result[key] = value
        }
        return makeResponse(
            identifier: identifier,
            actionIdentifier: response.actionIdentifier,
            userText: (response as? UNTextInputNotificationResponse)?.userText,
            payload: payload
        )
    }

    static func makeResponse(
        identifier: String,
        actionIdentifier: String,
        userText: String? = nil,
        payload: [String: String] = [:]
    ) -> NotificationResponse {
        let source: NotificationResponseSource
        if let managed = parseManagedIdentifier(identifier) {
            source = .managed(namespace: managed.namespace, id: managed.id)
        } else {
            source = .unmanaged(identifier: identifier)
        }

        let action: NotificationResponseAction
        if actionIdentifier == UNNotificationDefaultActionIdentifier {
            action = .defaultTap
        } else if actionIdentifier == UNNotificationDismissActionIdentifier {
            action = .dismiss
        } else if let userText {
            action = .textInput(
                id: actionIdentifier,
                text: userText
            )
        } else {
            action = .custom(actionIdentifier)
        }
        return NotificationResponse(source: source, action: action, payload: payload)
    }
}

@MainActor
private final class NotificationRouterBox {
    private(set) weak var router: (any NotificationResponseRouting)?

    init(router: (any NotificationResponseRouting)?) {
        self.router = router
    }
}

private struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
}
