import Foundation
import UserNotifications
@_spi(Testing) @testable import NotificationKit

enum TestCenterError: Error {
    case schedulingFailed
}

actor TestNotificationCenter: NotificationCenterServicing {
    var currentAuthorization: NotificationAuthorization = .authorized
    var requestResult = true
    var requestDelayNanoseconds: UInt64 = 0
    var requestCount = 0
    var pendingDelayNanoseconds: UInt64 = 0
    var pending: [PendingNotificationSnapshot] = []
    var delivered: [String] = []
    var scheduled: [ScheduledNotificationRequest] = []
    var removedPending: [String] = []
    var removedDelivered: [String] = []
    var categories: [NotificationCategorySpec] = []
    var failingIdentifiers: Set<String> = []

    func authorization() async -> NotificationAuthorization {
        currentAuthorization
    }

    func requestAuthorization() async throws -> Bool {
        requestCount += 1
        if requestDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: requestDelayNanoseconds)
        }
        currentAuthorization = requestResult ? .authorized : .denied
        return requestResult
    }

    func pendingNotifications() async -> [PendingNotificationSnapshot] {
        if pendingDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: pendingDelayNanoseconds)
        }
        return pending
    }

    func deliveredNotificationIdentifiers() async -> [String] {
        delivered
    }

    func schedule(_ request: ScheduledNotificationRequest) async throws {
        if failingIdentifiers.contains(request.identifier) {
            throw TestCenterError.schedulingFailed
        }
        scheduled.append(request)
        pending.removeAll { $0.identifier == request.identifier }
        pending.append(PendingNotificationSnapshot(
            identifier: request.identifier,
            fingerprint: request.fingerprint
        ))
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async {
        removedPending.append(contentsOf: identifiers)
        pending.removeAll { identifiers.contains($0.identifier) }
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) async {
        removedDelivered.append(contentsOf: identifiers)
        delivered.removeAll { identifiers.contains($0) }
    }

    func registerCategories(_ categories: [NotificationCategorySpec]) async {
        self.categories = categories
    }

    @MainActor
    func installDelegate(router: (any NotificationResponseRouting)?) {}

    func configure(
        authorization: NotificationAuthorization? = nil,
        requestResult: Bool? = nil,
        requestDelayNanoseconds: UInt64? = nil,
        pendingDelayNanoseconds: UInt64? = nil,
        pending: [PendingNotificationSnapshot]? = nil,
        delivered: [String]? = nil,
        failingIdentifiers: Set<String>? = nil
    ) {
        if let authorization { currentAuthorization = authorization }
        if let requestResult { self.requestResult = requestResult }
        if let requestDelayNanoseconds {
            self.requestDelayNanoseconds = requestDelayNanoseconds
        }
        if let pendingDelayNanoseconds {
            self.pendingDelayNanoseconds = pendingDelayNanoseconds
        }
        if let pending { self.pending = pending }
        if let delivered { self.delivered = delivered }
        if let failingIdentifiers { self.failingIdentifiers = failingIdentifiers }
    }
}

@MainActor
final class TestRouter: NotificationResponseRouting {
    private(set) var responses: [NotificationResponse] = []

    func handle(_ response: NotificationResponse) {
        responses.append(response)
    }
}

func makeDesired(
    id: String,
    hour: Int = 9,
    title: String = "Reminder"
) throws -> DesiredNotification {
    try DesiredNotification(
        id: id,
        title: title,
        body: "Body",
        payload: ["route": id],
        trigger: .calendar(DateComponents(hour: hour), repeats: true)
    )
}
