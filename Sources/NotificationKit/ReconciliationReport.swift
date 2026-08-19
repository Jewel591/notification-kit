import Foundation

public enum ReconciliationDisposition: Sendable, Equatable {
    case notLoaded
    case reconciled
    case authorizationUnavailable(NotificationAuthorization)
    case superseded
    case invalidDesiredSet
}

public struct ReconciliationReport: Sendable, Equatable {
    public let disposition: ReconciliationDisposition
    public let scheduled: [String]
    public let removed: [String]
    public let unchanged: [String]
    public let overflow: [String]
    public let failed: [String]

    public init(
        disposition: ReconciliationDisposition,
        scheduled: [String] = [],
        removed: [String] = [],
        unchanged: [String] = [],
        overflow: [String] = [],
        failed: [String] = []
    ) {
        self.disposition = disposition
        self.scheduled = scheduled
        self.removed = removed
        self.unchanged = unchanged
        self.overflow = overflow
        self.failed = failed
    }
}
