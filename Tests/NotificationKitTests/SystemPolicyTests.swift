import Testing
import UserNotifications
@testable import NotificationKit

struct SystemPolicyTests {
    @Test func authorizationMappingKeepsAlertAndSoundTruth() {
        let authorization = SystemNotificationCenterService.makeAuthorization(
            status: .authorized,
            alertSetting: .enabled,
            soundSetting: .disabled
        )

        #expect(authorization.status == .authorized)
        #expect(authorization.canSchedule)
        #expect(authorization.hasAlerts)
        #expect(!authorization.hasSound)
        #expect(authorization.needsSettingsForStandardDelivery)
        #expect(SystemNotificationCenterService.authorizationOptions == [.alert, .sound])
    }

    @Test func contentMapperEnforcesSoundAndReservedPayloadMarkers() {
        let content = SystemNotificationCenterService.makeContent(
            identifier: "NotificationKit.daily.morning",
            title: "Title",
            subtitle: "Subtitle",
            body: "Body",
            threadIdentifier: "thread",
            categoryIdentifier: "reminder",
            payload: [
                "route": "today",
                SystemNotificationCenterService.namespaceKey: "attacker",
                SystemNotificationCenterService.hostIDKey: "attacker",
            ],
            fingerprint: "fingerprint"
        )

        #expect(content.sound == .default)
        #expect(content.threadIdentifier == "thread")
        #expect(content.categoryIdentifier == "reminder")
        #expect(content.userInfo["route"] as? String == "today")
        #expect(content.userInfo[SystemNotificationCenterService.namespaceKey]
                as? String == "daily")
        #expect(content.userInfo[SystemNotificationCenterService.hostIDKey]
                as? String == "morning")
        #expect(content.userInfo[SystemNotificationCenterService.fingerprintKey]
                as? String == "fingerprint")
    }

    @Test func categoryMapperPreservesFixedTypedOptions() throws {
        let spec = NotificationCategorySpec(
            id: "reminder",
            actions: [
                .button(
                    id: "done",
                    title: "Done",
                    options: [.foreground, .authenticationRequired]
                )
            ],
            options: [.customDismissAction, .hiddenPreviewsShowTitle]
        )

        let category = spec.systemValue
        let action = try #require(category.actions.first)

        #expect(category.identifier == "reminder")
        #expect(action.options.contains(.foreground))
        #expect(action.options.contains(.authenticationRequired))
        #expect(category.options.contains(.customDismissAction))
        #expect(category.options.contains(.hiddenPreviewsShowTitle))
    }

    @Test func foregroundPresentationPolicyIsFixed() {
        #expect(NotificationCenterDelegateAdapter.foregroundPresentationOptions
                == [.banner, .list, .sound])
    }
}
