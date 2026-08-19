import Foundation

enum NotificationFingerprint {
    static func make(for notification: DesiredNotification) -> String {
        let fields = [
            notification.title,
            notification.subtitle,
            notification.body,
            notification.threadIdentifier ?? "",
            notification.categoryIdentifier ?? "",
            triggerDescription(notification.trigger),
            notification.payload.sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: "&"),
        ]
        return fnv1a64(fields.joined(separator: "\u{1F}"))
    }

    private static func triggerDescription(_ trigger: NotificationTriggerSpec) -> String {
        switch trigger {
        case let .timeInterval(interval, repeats):
            return "interval:\(interval):\(repeats)"
        case let .calendar(components, repeats):
            let calendar = components.calendar?.identifier.debugDescription ?? ""
            let timeZone = components.timeZone?.identifier ?? ""
            let values = [
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
            ].map { $0.map(String.init) ?? "" }.joined(separator: ",")
            return "calendar:\(calendar):\(timeZone):\(values):\(repeats)"
        }
    }

    private static func fnv1a64(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}
