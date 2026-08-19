import Foundation

actor NotificationReconciler {
    private static let pendingRequestLimit = 64

    private let center: any NotificationCenterServicing
    private let now: @Sendable () -> Date
    private let calendar: @Sendable () -> Calendar
    private var generations: [String: UInt64] = [:]

    init(
        center: any NotificationCenterServicing,
        now: @escaping @Sendable () -> Date = Date.init,
        calendar: @escaping @Sendable () -> Calendar = { .current }
    ) {
        self.center = center
        self.now = now
        self.calendar = calendar
    }

    func reconcile(
        namespace: NotificationNamespace,
        desired: NotificationDesiredSet
    ) async -> ReconciliationReport {
        let generation = (generations[namespace.id] ?? 0) &+ 1
        generations[namespace.id] = generation

        guard case let .loaded(notifications) = desired else {
            return ReconciliationReport(disposition: .notLoaded)
        }

        let ids = notifications.map(\.id)
        guard Set(ids).count == ids.count,
              notifications.allSatisfy({ $0.trigger.validate() }) else {
            return ReconciliationReport(disposition: .invalidDesiredSet)
        }

        let authorization = await center.authorization()
        guard isCurrent(generation, namespace: namespace.id) else {
            return ReconciliationReport(disposition: .superseded)
        }

        let pending = await center.pendingNotifications()
        guard isCurrent(generation, namespace: namespace.id) else {
            return ReconciliationReport(disposition: .superseded)
        }

        if !authorization.canDeliver {
            let ownedPending = pending.map(\.identifier).filter(namespace.owns)
            let delivered = await center.deliveredNotificationIdentifiers()
            guard isCurrent(generation, namespace: namespace.id) else {
                return ReconciliationReport(disposition: .superseded)
            }
            let ownedDelivered = delivered.filter(namespace.owns)
            await center.removePendingNotificationRequests(withIdentifiers: ownedPending)
            await center.removeDeliveredNotifications(withIdentifiers: ownedDelivered)
            return ReconciliationReport(
                disposition: .authorizationUnavailable(authorization),
                removed: Array(Set(ownedPending + ownedDelivered)).sorted()
            )
        }

        let foreignCount = pending.count(where: { !namespace.owns($0.identifier) })
        let capacity = max(0, Self.pendingRequestLimit - foreignCount)
        let sortedDesired = notifications.sorted {
            let lhsDate = $0.trigger.nextFireDate(after: now(), calendar: calendar())
            let rhsDate = $1.trigger.nextFireDate(after: now(), calendar: calendar())
            switch (lhsDate, rhsDate) {
            case let (.some(lhs), .some(rhs)) where lhs != rhs:
                return lhs < rhs
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                return $0.id < $1.id
            }
        }
        let keptDesired = Array(sortedDesired.prefix(capacity))
        let overflow = Array(sortedDesired.dropFirst(capacity)).map(\.id).sorted()

        var requests: [ScheduledNotificationRequest] = []
        requests.reserveCapacity(keptDesired.count)
        for notification in keptDesired {
            guard let identifier = try? namespace.identifier(for: notification.id) else {
                continue
            }
            requests.append(ScheduledNotificationRequest(
                identifier: identifier,
                title: notification.title,
                subtitle: notification.subtitle,
                body: notification.body,
                threadIdentifier: notification.threadIdentifier,
                categoryIdentifier: notification.categoryIdentifier,
                payload: notification.payload,
                trigger: notification.trigger,
                fingerprint: NotificationFingerprint.make(for: notification)
            ))
        }

        let desiredIdentifiers = Set(requests.map(\.identifier))
        let ownedPending = pending.filter { namespace.owns($0.identifier) }
        let pendingByIdentifier = Dictionary(
            uniqueKeysWithValues: ownedPending.map { ($0.identifier, $0) }
        )
        let toRemove = ownedPending.map(\.identifier).filter {
            !desiredIdentifiers.contains($0) || !$0.hasPrefix(namespace.identifierPrefix)
        }
        if !toRemove.isEmpty {
            await center.removePendingNotificationRequests(withIdentifiers: toRemove)
        }

        let delivered = await center.deliveredNotificationIdentifiers()
        guard isCurrent(generation, namespace: namespace.id) else {
            return ReconciliationReport(disposition: .superseded)
        }
        let deliveredToRemove = delivered.filter {
            namespace.owns($0)
                && (!desiredIdentifiers.contains($0)
                    || !$0.hasPrefix(namespace.identifierPrefix))
        }
        if !deliveredToRemove.isEmpty {
            await center.removeDeliveredNotifications(withIdentifiers: deliveredToRemove)
        }

        var scheduled: [String] = []
        var unchanged: [String] = []
        var failed: [String] = []
        for request in requests {
            guard isCurrent(generation, namespace: namespace.id) else {
                return ReconciliationReport(disposition: .superseded)
            }
            if pendingByIdentifier[request.identifier]?.fingerprint == request.fingerprint {
                unchanged.append(request.identifier)
                continue
            }
            do {
                try await center.schedule(request)
                scheduled.append(request.identifier)
            } catch {
                failed.append(request.identifier)
            }
        }

        return ReconciliationReport(
            disposition: .reconciled,
            scheduled: scheduled.sorted(),
            removed: Array(Set(toRemove + deliveredToRemove)).sorted(),
            unchanged: unchanged.sorted(),
            overflow: overflow,
            failed: failed.sorted()
        )
    }

    private func isCurrent(_ generation: UInt64, namespace: String) -> Bool {
        generations[namespace] == generation
    }
}
