import Foundation

public enum NotificationIdentifierError: Error, Sendable, Equatable {
    case invalidNamespace(String)
    case invalidNotificationID(String)
    case duplicateNotificationID(String)
    case invalidLegacyPrefix(String)
}

public struct NotificationNamespace: Hashable, Sendable {
    public let id: String
    public let legacyPrefixes: [String]

    public init(_ id: String, legacyPrefixes: [String] = []) throws {
        guard Self.isValidNamespace(id) else {
            throw NotificationIdentifierError.invalidNamespace(id)
        }
        let normalizedLegacyPrefixes = Array(
            Set(legacyPrefixes.filter { !$0.isEmpty })
        ).sorted()
        if let invalidPrefix = normalizedLegacyPrefixes.first(where: Self.isManagedPrefix) {
            throw NotificationIdentifierError.invalidLegacyPrefix(invalidPrefix)
        }
        self.id = id
        self.legacyPrefixes = normalizedLegacyPrefixes
    }

    public var identifierPrefix: String {
        "NotificationKit.\(id)."
    }

    var immediateIdentifierPrefix: String {
        "NotificationKitImmediate.\(id)."
    }

    public func identifier(for hostID: String) throws -> String {
        guard Self.isValidHostID(hostID) else {
            throw NotificationIdentifierError.invalidNotificationID(hostID)
        }
        return identifierPrefix + hostID
    }

    func immediateIdentifier(for hostID: String) throws -> String {
        guard Self.isValidHostID(hostID) else {
            throw NotificationIdentifierError.invalidNotificationID(hostID)
        }
        return immediateIdentifierPrefix + hostID
    }

    func owns(_ identifier: String) -> Bool {
        identifier.hasPrefix(identifierPrefix)
            || legacyPrefixes.contains { identifier.hasPrefix($0) }
    }

    func hostID(from identifier: String) -> String? {
        guard identifier.hasPrefix(identifierPrefix) else { return nil }
        return String(identifier.dropFirst(identifierPrefix.count))
    }

    private static func isValidNamespace(_ value: String) -> Bool {
        !value.isEmpty && value.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_"
        }
    }

    private static func isManagedPrefix(_ value: String) -> Bool {
        value == "NotificationKit"
            || value.hasPrefix("NotificationKit.")
            || value == "NotificationKitImmediate"
            || value.hasPrefix("NotificationKitImmediate.")
    }

    private static func isValidHostID(_ value: String) -> Bool {
        !value.isEmpty && !value.hasPrefix(".") && !value.hasSuffix(".")
            && value.unicodeScalars.allSatisfy {
                CharacterSet.alphanumerics.contains($0)
                    || $0 == "-" || $0 == "_" || $0 == "."
            }
    }
}
