import Foundation
import Observation

@MainActor
@Observable
public final class NotificationClient {
    public private(set) var authorization: NotificationAuthorization = .unknown
    public private(set) var isAuthorizationRequestInFlight = false

    private let center: any NotificationCenterServicing
    private let router: (any NotificationResponseRouting)?
    private let reconciler: NotificationReconciler

    public convenience init(router: (any NotificationResponseRouting)? = nil) {
        self.init(
            testingCenter: SystemNotificationCenterService(),
            router: router
        )
    }

    /// Test seam for deterministic authorization and scheduling tests.
    /// Production composition roots use `init(router:)`.
    @_spi(Testing)
    public init(
        testingCenter center: any NotificationCenterServicing,
        router: (any NotificationResponseRouting)? = nil
    ) {
        self.center = center
        self.router = router
        reconciler = NotificationReconciler(center: center)
        center.installDelegate(router: router)
    }

    public func refreshAuthorization() async {
        authorization = await center.authorization()
    }

    public func requestAuthorizationFromUserAction() async -> AuthorizationRequestOutcome {
        guard !isAuthorizationRequestInFlight else {
            return .ignoredBecauseInFlight
        }

        await refreshAuthorization()
        switch authorization {
        case .authorized, .provisional, .ephemeral:
            return .alreadyAuthorized
        case .denied:
            return .needsSettings
        case .unknown:
            return .failed
        case .notDetermined:
            break
        }

        isAuthorizationRequestInFlight = true
        defer { isAuthorizationRequestInFlight = false }
        do {
            let granted = try await center.requestAuthorization()
            await refreshAuthorization()
            return granted ? .granted : .denied
        } catch {
            await refreshAuthorization()
            return .failed
        }
    }

    public func registerCategories(_ categories: [NotificationCategorySpec]) async {
        await center.registerCategories(categories)
    }

    /// Submit an event notification once without adding it to reconciled state.
    /// This never requests authorization.
    public func submitImmediately(
        namespace: NotificationNamespace,
        notification: ImmediateNotification
    ) async -> ImmediateSubmissionOutcome {
        let currentAuthorization = await center.authorization()
        authorization = currentAuthorization
        guard currentAuthorization.canDeliver else {
            return .authorizationUnavailable(currentAuthorization)
        }
        let identifier: String
        do {
            identifier = try namespace.identifier(for: notification.id)
        } catch {
            return .failed(identifier: notification.id)
        }
        do {
            try await center.submitImmediately(ImmediateNotificationRequest(
                identifier: identifier,
                title: notification.title,
                subtitle: notification.subtitle,
                body: notification.body,
                threadIdentifier: notification.threadIdentifier,
                categoryIdentifier: notification.categoryIdentifier,
                payload: notification.payload
            ))
            return .submitted(identifier: identifier)
        } catch {
            return .failed(identifier: identifier)
        }
    }

    public func reconcile(
        namespace: NotificationNamespace,
        desired: NotificationDesiredSet
    ) async -> ReconciliationReport {
        let report = await reconciler.reconcile(
            namespace: namespace,
            desired: desired
        )
        authorization = await center.authorization()
        return report
    }
}
