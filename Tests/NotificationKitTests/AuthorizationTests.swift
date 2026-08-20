import Testing
@_spi(Testing) @testable import NotificationKit

@MainActor
struct AuthorizationTests {
    @Test
    func deniedAuthorizationReturnsSettingsWithoutPromptingAgain() async {
        let center = TestNotificationCenter()
        await center.configure(authorization: .denied)
        let client = NotificationClient(testingCenter: center, router: TestRouter())

        let outcome = await client.requestAuthorizationFromUserAction()

        #expect(outcome == .needsSettings)
        #expect(await center.requestCount == 0)
        #expect(client.authorization == .denied)
    }

    @Test
    func explicitRequestRefreshesTheOperatingSystemTruth() async {
        let center = TestNotificationCenter()
        await center.configure(authorization: .notDetermined, requestResult: true)
        let client = NotificationClient(testingCenter: center, router: TestRouter())

        let outcome = await client.requestAuthorizationFromUserAction()

        #expect(outcome == .granted)
        #expect(await center.requestCount == 1)
        #expect(client.authorization == .authorized)
    }

    @Test
    func concurrentRequestsBeforeTheFirstAuthorizationReadShareOneTask() async {
        let center = TestNotificationCenter()
        await center.configure(
            authorization: .notDetermined,
            authorizationDelayNanoseconds: 50_000_000,
            requestDelayNanoseconds: 50_000_000
        )
        let client = NotificationClient(testingCenter: center, router: TestRouter())

        async let first = client.requestAuthorizationFromUserAction()
        async let second = client.requestAuthorizationFromUserAction()
        let outcomes = await [first, second]

        #expect(outcomes == [.granted, .granted])
        #expect(await center.requestCount == 1)
        #expect(!client.isAuthorizationRequestInFlight)
    }

    @Test
    func provisionalAuthorizationCanUpgradeFromAUserAction() async {
        let center = TestNotificationCenter()
        await center.configure(authorization: .provisional, requestResult: true)
        let client = NotificationClient(testingCenter: center)

        #expect(await client.requestAuthorizationFromUserAction() == .granted)
        #expect(await center.requestCount == 1)
    }

    @Test
    func disabledSoundReportsSettingsRecoveryInsteadOfAvailable() async {
        let center = TestNotificationCenter()
        let missingSound = NotificationAuthorization(
            status: .authorized,
            alertSetting: .enabled,
            soundSetting: .disabled
        )
        await center.configure(authorization: missingSound)
        let client = NotificationClient(testingCenter: center)

        #expect(await client.requestAuthorizationFromUserAction() == .needsSettings)
        #expect(client.authorization.canSchedule)
        #expect(client.authorization.hasAlerts)
        #expect(!client.authorization.hasSound)
        #expect(client.authorization.needsSettingsForStandardDelivery)
        #expect(await center.requestCount == 0)
    }

    @Test
    func appActivationAutomaticallyRefreshesSettingsTruth() async {
        let center = TestNotificationCenter()
        let lifecycle = TestNotificationLifecycleSource()
        let client = NotificationClient(
            testingCenter: center,
            lifecycleSource: lifecycle,
            immediateReceipts: TestImmediateReceiptStore()
        )
        await center.configure(authorization: .denied)

        lifecycle.sendBecameActive()
        await Task.yield()
        while client.authorization != .denied {
            await Task.yield()
        }

        #expect(client.authorization == .denied)
        #expect(lifecycle.startCount == 1)
    }
}
