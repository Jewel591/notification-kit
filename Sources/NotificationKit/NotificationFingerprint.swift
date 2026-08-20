import Foundation

enum NotificationFingerprint {
    static func make(for notification: DesiredNotification) -> String {
        var fields = [
            notification.title,
            notification.subtitle,
            notification.body,
            notification.threadIdentifier ?? "",
            notification.categoryIdentifier ?? "",
            triggerDescription(notification.trigger),
        ]
        for item in notification.payload.sorted(by: { $0.key < $1.key }) {
            fields.append(item.key)
            fields.append(item.value)
        }
        return fnv1a64(lengthPrefixed(fields))
    }

    private static func lengthPrefixed(_ fields: [String]) -> Data {
        var result = Data()
        for field in fields {
            let bytes = Data(field.utf8)
            var length = UInt64(bytes.count).bigEndian
            withUnsafeBytes(of: &length) { result.append(contentsOf: $0) }
            result.append(bytes)
        }
        return result
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

    private static func fnv1a64(_ value: Data) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}
