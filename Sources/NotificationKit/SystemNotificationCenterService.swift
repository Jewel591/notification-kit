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
        return Self.makeAuthorization(
            status: settings.authorizationStatus,
            alertSetting: settings.alertSetting,
            soundSetting: settings.soundSetting
        )
    }

    static func makeAuthorization(
        status: UNAuthorizationStatus,
        alertSetting: UNNotificationSetting,
        soundSetting: UNNotificationSetting
    ) -> NotificationAuthorization {
        NotificationAuthorization(
            status: status.notificationKitValue,
            alertSetting: alertSetting.notificationKitValue,
            soundSetting: soundSetting.notificationKitValue
        )
    }

    static let authorizationOptions: UNAuthorizationOptions = [.alert, .sound]

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: Self.authorizationOptions)
    }

    func pendingNotifications() async -> [PendingNotificationSnapshot] {
        await center.pendingNotificationRequests().map {
            PendingNotificationSnapshot(
                identifier: $0.identifier,
                fingerprint: $0.content.userInfo[Self.fingerprintKey] as? String
            )
        }
    }

    func schedule(_ request: ScheduledNotificationRequest) async throws {
        let content = Self.makeContent(
            identifier: request.identifier,
            title: request.title,
            subtitle: request.subtitle,
            body: request.body,
            threadIdentifier: request.threadIdentifier,
            categoryIdentifier: request.categoryIdentifier,
            payload: request.payload,
            fingerprint: request.fingerprint
        )

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

    func submitImmediately(_ request: ImmediateNotificationRequest) async throws {
        let content = Self.makeContent(
            identifier: request.identifier,
            title: request.title,
            subtitle: request.subtitle,
            body: request.body,
            threadIdentifier: request.threadIdentifier,
            categoryIdentifier: request.categoryIdentifier,
            payload: request.payload,
            fingerprint: nil
        )
        try await center.add(UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: nil
        ))
    }

    static func makeContent(
        identifier: String,
        title: String,
        subtitle: String,
        body: String,
        threadIdentifier: String?,
        categoryIdentifier: String?,
        payload: [String: String],
        fingerprint: String?
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = .default
        content.threadIdentifier = threadIdentifier ?? ""
        content.categoryIdentifier = categoryIdentifier ?? ""
        var userInfo = payload
        let source = NotificationCenterDelegateAdapter.parseManagedIdentifier(identifier)
        userInfo[Self.namespaceKey] = source?.namespace
        userInfo[Self.hostIDKey] = source?.id
        if let fingerprint {
            userInfo[Self.fingerprintKey] = fingerprint
        }
        content.userInfo = userInfo
        return content
    }

    func removePendingNotificationRequests(
        withIdentifiers identifiers: [String]
    ) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func replaceCategories(_ categories: [NotificationCategorySpec]) async {
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
        if contains(.hiddenPreviewsShowTitle) {
            value.insert(.hiddenPreviewsShowTitle)
        }
        if contains(.hiddenPreviewsShowSubtitle) {
            value.insert(.hiddenPreviewsShowSubtitle)
        }
        return value
    }
}

extension NotificationCategorySpec {
    var systemValue: UNNotificationCategory {
        UNNotificationCategory(
            identifier: id,
            actions: actions.map(\.systemValue),
            intentIdentifiers: intentIdentifiers,
            options: options.systemValue
        )
    }
}

private extension UNAuthorizationStatus {
    var notificationKitValue: NotificationAuthorizationStatus {
        switch self {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized: .authorized
        case .provisional: .provisional
        case .ephemeral: .ephemeral
        @unknown default: .unknown
        }
    }
}

private extension UNNotificationSetting {
    var notificationKitValue: NotificationCapabilitySetting {
        switch self {
        case .notSupported: .notSupported
        case .disabled: .disabled
        case .enabled: .enabled
        @unknown default: .unknown
        }
    }
}
