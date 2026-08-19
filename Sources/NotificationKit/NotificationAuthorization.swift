import Foundation

public enum NotificationAuthorization: Sendable, Equatable {
    case unknown
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral

    public var canDeliver: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        case .unknown, .notDetermined, .denied:
            false
        }
    }
}

public enum AuthorizationRequestOutcome: Sendable, Equatable {
    case granted
    case alreadyAuthorized
    case denied
    case needsSettings
    case ignoredBecauseInFlight
    case failed
}
