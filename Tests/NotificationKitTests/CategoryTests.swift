import Testing
@_spi(Testing) @testable import NotificationKit

@MainActor
struct CategoryTests {
    @Test
    func categorySpecificationsPassThroughTheSingleClientPath() async {
        let center = TestNotificationCenter()
        let client = NotificationClient(testingCenter: center, router: TestRouter())
        let category = NotificationCategorySpec(
            id: "reminder",
            actions: [
                .button(id: "done", title: "Done", options: [.foreground])
            ],
            options: [.customDismissAction]
        )

        await client.replaceCategories([category])

        #expect(await center.categories == [category])
    }
}
