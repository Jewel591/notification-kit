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
    func overlappingExplicitRequestsAreCoalesced() async {
        let center = TestNotificationCenter()
        await center.configure(
            authorization: .notDetermined,
            requestDelayNanoseconds: 100_000_000
        )
        let client = NotificationClient(testingCenter: center, router: TestRouter())

        let first = Task { await client.requestAuthorizationFromUserAction() }
        await Task.yield()
        while !client.isAuthorizationRequestInFlight {
            await Task.yield()
        }
        let second = await client.requestAuthorizationFromUserAction()

        #expect(second == .ignoredBecauseInFlight)
        #expect(await first.value == .granted)
        #expect(await center.requestCount == 1)
    }
}
