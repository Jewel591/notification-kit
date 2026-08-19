import Foundation

public enum NotificationTriggerSpec: Sendable, Equatable {
    case calendar(DateComponents, repeats: Bool)
    case timeInterval(TimeInterval, repeats: Bool)

    func validate() -> Bool {
        switch self {
        case let .calendar(components, _):
            [
                components.era,
                components.year,
                components.month,
                components.day,
                components.hour,
                components.minute,
                components.second,
                components.weekday,
                components.weekdayOrdinal,
                components.quarter,
                components.weekOfMonth,
                components.weekOfYear,
                components.yearForWeekOfYear,
                components.nanosecond,
            ].contains { $0 != nil }
        case let .timeInterval(interval, repeats):
            interval > 0 && (!repeats || interval >= 60)
        }
    }

    func nextFireDate(after date: Date, calendar: Calendar) -> Date? {
        switch self {
        case let .calendar(components, _):
            calendar.nextDate(
                after: date,
                matching: components,
                matchingPolicy: .nextTimePreservingSmallerComponents
            )
        case let .timeInterval(interval, _):
            date.addingTimeInterval(interval)
        }
    }
}

public struct DesiredNotification: Sendable, Equatable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let body: String
    public let threadIdentifier: String?
    public let categoryIdentifier: String?
    public let payload: [String: String]
    public let trigger: NotificationTriggerSpec

    public init(
        id: String,
        title: String,
        subtitle: String = "",
        body: String,
        threadIdentifier: String? = nil,
        categoryIdentifier: String? = nil,
        payload: [String: String] = [:],
        trigger: NotificationTriggerSpec
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
        self.trigger = trigger
    }
}

enum NotificationIdentifierValidator {
    static func isValid(_ id: String) -> Bool {
        !id.isEmpty && !id.hasPrefix(".") && !id.hasSuffix(".")
            && id.unicodeScalars.allSatisfy {
                CharacterSet.alphanumerics.contains($0)
                    || $0 == "-" || $0 == "_" || $0 == "."
            }
    }
}

public enum NotificationDesiredSet: Sendable, Equatable {
    case notLoaded
    case loaded([DesiredNotification])
}
