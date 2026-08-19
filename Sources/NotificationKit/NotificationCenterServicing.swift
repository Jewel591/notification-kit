import Foundation

@_spi(Testing)
public struct PendingNotificationSnapshot: Sendable, Equatable {
    public let identifier: String
    public let fingerprint: String?

    public init(identifier: String, fingerprint: String? = nil) {
        self.identifier = identifier
        self.fingerprint = fingerprint
    }
}

@_spi(Testing)
public struct ScheduledNotificationRequest: Sendable, Equatable {
    public let identifier: String
    public let title: String
    public let subtitle: String
    public let body: String
    public let threadIdentifier: String?
    public let categoryIdentifier: String?
    public let payload: [String: String]
    public let trigger: NotificationTriggerSpec
    public let fingerprint: String

    public init(
        identifier: String,
        title: String,
        subtitle: String,
        body: String,
        threadIdentifier: String?,
        categoryIdentifier: String?,
        payload: [String: String],
        trigger: NotificationTriggerSpec,
        fingerprint: String
    ) {
        self.identifier = identifier
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.threadIdentifier = threadIdentifier
        self.categoryIdentifier = categoryIdentifier
        self.payload = payload
        self.trigger = trigger
        self.fingerprint = fingerprint
    }
}

@_spi(Testing)
public protocol NotificationCenterServicing: Sendable {
    func authorization() async -> NotificationAuthorization
    func requestAuthorization() async throws -> Bool
    func pendingNotifications() async -> [PendingNotificationSnapshot]
    func deliveredNotificationIdentifiers() async -> [String]
    func schedule(_ request: ScheduledNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async
    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) async
    func registerCategories(_ categories: [NotificationCategorySpec]) async

    @MainActor
    func installDelegate(router: (any NotificationResponseRouting)?)
}
