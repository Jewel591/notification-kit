import Foundation
import Observation

@MainActor
@Observable
public final class NotificationClient {
    public static let shared = NotificationClient()

    public private(set) var authorization: NotificationAuthorization = .unknown
    public private(set) var isAuthorizationRequestInFlight = false

    private let center: any NotificationCenterServicing
    private let reconciler: NotificationReconciler
    private let lifecycleSource: any NotificationLifecycleSourcing
    private let immediateReceipts: any ImmediateNotificationReceiptStoring

    private var router: (any NotificationResponseRouting)?
    private var authorizationRequest: (
        id: UUID,
        task: Task<AuthorizationRequestOutcome, Never>
    )?
    private var immediateSubmissions: [
        String: Task<ImmediateSubmissionOutcome, Never>
    ] = [:]

    private convenience init() {
        let center = SystemNotificationCenterService()
        self.init(
            testingCenter: center,
            lifecycleSource: SystemNotificationLifecycleSource(),
            immediateReceipts: UserDefaultsImmediateNotificationReceiptStore()
        )
    }

    /// Test seam for deterministic authorization and scheduling tests.
    /// Production code always uses `NotificationClient.shared`.
    @_spi(Testing)
    public convenience init(
        testingCenter center: any NotificationCenterServicing,
        router: (any NotificationResponseRouting)? = nil
    ) {
        self.init(
            testingCenter: center,
            router: router,
            lifecycleSource: SystemNotificationLifecycleSource(),
            immediateReceipts: MemoryImmediateNotificationReceiptStore()
        )
    }

    @_spi(Testing)
    public init(
        testingCenter center: any NotificationCenterServicing,
        router: (any NotificationResponseRouting)? = nil,
        lifecycleSource: any NotificationLifecycleSourcing,
        immediateReceipts: any ImmediateNotificationReceiptStoring
    ) {
        self.center = center
        self.router = router
        self.lifecycleSource = lifecycleSource
        self.immediateReceipts = immediateReceipts
        reconciler = NotificationReconciler(center: center)
        center.installDelegate(router: router)

        lifecycleSource.becameActiveHandler = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.refreshAuthorizationFromSystem()
            }
        }
        lifecycleSource.start()
        Task { @MainActor [weak self] in
            await self?.refreshAuthorizationFromSystem()
        }
    }

    /// Installs the app's single response route while NotificationKit remains
    /// the sole UNUserNotificationCenter delegate owner.
    public func setResponseRouter(
        _ router: (any NotificationResponseRouting)?
    ) {
        self.router = router
        center.installDelegate(router: router)
    }

    public func requestAuthorizationFromUserAction() async
        -> AuthorizationRequestOutcome
    {
        if let authorizationRequest {
            return await authorizationRequest.task.value
        }

        let requestID = UUID()
        isAuthorizationRequestInFlight = true
        let task = Task { @MainActor [weak self] in
            guard let self else { return AuthorizationRequestOutcome.failed }
            return await self.performAuthorizationRequest()
        }
        authorizationRequest = (requestID, task)

        let outcome = await task.value
        if authorizationRequest?.id == requestID {
            authorizationRequest = nil
            isAuthorizationRequestInFlight = false
        }
        return outcome
    }

    public func replaceCategories(_ categories: [NotificationCategorySpec]) async {
        await center.replaceCategories(categories)
    }

    /// Submits a stable event notification once. Successful identifiers are
    /// retained for a fixed 90-day/512-entry window so normal task or intent
    /// retries do not notify twice. This never requests authorization.
    public func submitImmediately(
        namespace: NotificationNamespace,
        notification: ImmediateNotification
    ) async -> ImmediateSubmissionOutcome {
        let identifier: String
        do {
            identifier = try namespace.identifier(for: notification.id)
        } catch {
            return .failed(identifier: notification.id)
        }

        if let existing = immediateSubmissions[identifier] {
            return await existing.value
        }

        let task = Task { @MainActor [weak self] in
            guard let self else {
                return ImmediateSubmissionOutcome.failed(identifier: identifier)
            }
            return await self.performImmediateSubmission(
                identifier: identifier,
                notification: notification
            )
        }
        immediateSubmissions[identifier] = task
        let outcome = await task.value
        immediateSubmissions[identifier] = nil
        return outcome
    }

    public func reconcile(
        namespace: NotificationNamespace,
        desired: NotificationDesiredSet
    ) async -> ReconciliationReport {
        let report = await reconciler.reconcile(
            namespace: namespace,
            desired: desired
        )
        await refreshAuthorizationFromSystem()
        return report
    }

    private func performAuthorizationRequest() async -> AuthorizationRequestOutcome {
        await refreshAuthorizationFromSystem()
        switch authorization.status {
        case .authorized, .ephemeral:
            return authorization.needsSettingsForStandardDelivery
                ? .needsSettings
                : .alreadyAuthorized
        case .denied:
            return .needsSettings
        case .unknown:
            return .failed
        case .notDetermined, .provisional:
            break
        }

        do {
            let granted = try await center.requestAuthorization()
            await refreshAuthorizationFromSystem()
            if authorization.status == .denied || !granted {
                return .denied
            }
            return authorization.needsSettingsForStandardDelivery
                ? .needsSettings
                : .granted
        } catch {
            await refreshAuthorizationFromSystem()
            return .failed
        }
    }

    private func performImmediateSubmission(
        identifier: String,
        notification: ImmediateNotification
    ) async -> ImmediateSubmissionOutcome {
        if immediateReceipts.contains(identifier) {
            return .alreadySubmitted(identifier: identifier)
        }

        await refreshAuthorizationFromSystem()
        guard authorization.canSchedule else {
            return .authorizationUnavailable(authorization)
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
            immediateReceipts.insert(identifier)
            return .submitted(identifier: identifier)
        } catch {
            return .failed(identifier: identifier)
        }
    }

    private func refreshAuthorizationFromSystem() async {
        authorization = await center.authorization()
    }
}
