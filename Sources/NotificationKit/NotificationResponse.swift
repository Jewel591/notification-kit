import Foundation

public enum NotificationResponseSource: Sendable, Equatable {
    case managed(namespace: String, id: String)
    case unmanaged(identifier: String)
}

public enum NotificationResponseAction: Sendable, Equatable {
    case defaultTap
    case dismiss
    case custom(String)
    case textInput(id: String, text: String)
}

public struct NotificationResponse: Sendable, Equatable {
    public let source: NotificationResponseSource
    public let action: NotificationResponseAction
    public let payload: [String: String]

    public init(
        source: NotificationResponseSource,
        action: NotificationResponseAction,
        payload: [String: String]
    ) {
        self.source = source
        self.action = action
        self.payload = payload
    }
}

@MainActor
public protocol NotificationResponseRouting: AnyObject {
    func handle(_ response: NotificationResponse)
}
