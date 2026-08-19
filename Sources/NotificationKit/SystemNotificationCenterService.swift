import Foundation
@preconcurrency import UserNotifications

final class SystemNotificationCenterService: NotificationCenterServicing, @unchecked Sendable {
    static let namespaceKey = "NotificationKit.namespace"
    static let hostIDKey = "NotificationKit.hostID"
    static let fingerprintKey = "NotificationKit.fingerprint"

    private let center: UNUserNotificationCenter
    private var delegateAdapter: NotificationCenterDelegateAdapter?

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorization() async -> NotificationAuthorization {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized: return .authorized
        case .provisional: return .provisional
        case .ephemeral: return .ephemeral
        @unknown default: return .unknown
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func pendingNotifications() async -> [PendingNotificationSnapshot] {
        await center.pendingNotificationRequests().map {
            PendingNotificationSnapshot(
                identifier: $0.identifier,
                fingerprint: $0.content.userInfo[Self.fingerprintKey] as? String
            )
        }
    }

    func deliveredNotificationIdentifiers() async -> [String] {
        await center.deliveredNotifications().map { $0.request.identifier }
    }

    func schedule(_ request: ScheduledNotificationRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.subtitle = request.subtitle
        content.body = request.body
        content.sound = .default
        content.threadIdentifier = request.threadIdentifier ?? ""
        content.categoryIdentifier = request.categoryIdentifier ?? ""
        var userInfo = request.payload
        let source = NotificationCenterDelegateAdapter.parseManagedIdentifier(request.identifier)
        userInfo[Self.namespaceKey] = source?.namespace
        userInfo[Self.hostIDKey] = source?.id
        userInfo[Self.fingerprintKey] = request.fingerprint
        content.userInfo = userInfo

        let trigger: UNNotificationTrigger
        switch request.trigger {
        case let .calendar(components, repeats):
            trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: repeats
            )
        case let .timeInterval(interval, repeats):
            trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: interval,
                repeats: repeats
            )
        }
        try await center.add(UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: trigger
        ))
    }

    func removePendingNotificationRequests(
        withIdentifiers identifiers: [String]
    ) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDeliveredNotifications(
        withIdentifiers identifiers: [String]
    ) async {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func registerCategories(_ categories: [NotificationCategorySpec]) async {
        center.setNotificationCategories(Set(categories.map(\.systemValue)))
    }

    @MainActor
    func installDelegate(router: (any NotificationResponseRouting)?) {
        let adapter = NotificationCenterDelegateAdapter(router: router)
        delegateAdapter = adapter
        center.delegate = adapter
    }
}

private extension NotificationActionOptions {
    var systemValue: UNNotificationActionOptions {
        var value: UNNotificationActionOptions = []
        if contains(.foreground) { value.insert(.foreground) }
        if contains(.destructive) { value.insert(.destructive) }
        if contains(.authenticationRequired) {
            value.insert(.authenticationRequired)
        }
        return value
    }
}

private extension NotificationActionSpec {
    var systemValue: UNNotificationAction {
        switch self {
        case let .button(id, title, options):
            UNNotificationAction(
                identifier: id,
                title: title,
                options: options.systemValue
            )
        case let .textInput(id, title, buttonTitle, placeholder, options):
            UNTextInputNotificationAction(
                identifier: id,
                title: title,
                options: options.systemValue,
                textInputButtonTitle: buttonTitle,
                textInputPlaceholder: placeholder
            )
        }
    }
}

private extension NotificationCategoryOptions {
    var systemValue: UNNotificationCategoryOptions {
        var value: UNNotificationCategoryOptions = []
        if contains(.customDismissAction) { value.insert(.customDismissAction) }
        #if os(iOS)
        if contains(.allowInCarPlay) { value.insert(.allowInCarPlay) }
        #endif
        if contains(.hiddenPreviewsShowTitle) {
            value.insert(.hiddenPreviewsShowTitle)
        }
        if contains(.hiddenPreviewsShowSubtitle) {
            value.insert(.hiddenPreviewsShowSubtitle)
        }
        return value
    }
}

private extension NotificationCategorySpec {
    var systemValue: UNNotificationCategory {
        UNNotificationCategory(
            identifier: id,
            actions: actions.map(\.systemValue),
            intentIdentifiers: intentIdentifiers,
            options: options.systemValue
        )
    }
}
