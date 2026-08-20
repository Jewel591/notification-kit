import Foundation

/// A one-shot notification produced by an event that already happened.
///
/// Immediate notifications are submitted explicitly and never participate in
/// desired-schedule reconciliation, so a later refresh cannot replay them.
public struct ImmediateNotification: Sendable, Equatable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let body: String
    public let threadIdentifier: String?
    public let categoryIdentifier: String?
    public let payload: [String: String]

    public init(
        id: String,
        title: String,
        subtitle: String = "",
        body: String,
        threadIdentifier: String? = nil,
        categoryIdentifier: String? = nil,
        payload: [String: String] = [:]
    ) throws {
        guard NotificationIdentifierValidator.isValid(id) else {
            throw NotificationIdentifierError.invalidNotificationID(id)
        }
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.threadIdentifier = threadIdentifier
        self.categoryIdentifier = categoryIdentifier
        self.payload = payload
    }
}

public enum ImmediateSubmissionOutcome: Sendable, Equatable {
    case submitted(identifier: String)
    case alreadySubmitted(identifier: String)
    case authorizationUnavailable(NotificationAuthorization)
    case failed(identifier: String)
}
