# NotificationKit

An opinionated Swift package for the shared notification mechanics in Ivens'
Apple app portfolio: operating-system authorization truth, explicit permission
requests, deterministic local scheduling, one-shot event notifications,
category/action registration, and a single typed response handoff.

NotificationKit contains no notification UI and no growth strategy. Apps keep
their own reminder rules, localized copy, onboarding education, settings
screens, navigation, analytics, and APNs infrastructure.

## Fixed portfolio policy

- Permission is requested only by an explicit call to
  `requestAuthorizationFromUserAction()`. Launch, reconciliation, initialization,
  `onAppear`, and automatic tasks never prompt.
- Authorization is never persisted or mirrored in an app-owned boolean. Call
  `refreshAuthorization()` when the app becomes active.
- `.notLoaded` means "the host has not produced its desired schedule yet" and
  is a no-op. `.loaded([])` means "the desired schedule is empty" and clears
  that namespace.
- Reconciliation is namespace-scoped and never removes another feature's
  requests. Legacy prefixes can be adopted without leaving duplicate reminders.
- Reconciliations across namespaces are serialized inside the Kit so every
  capacity decision sees the latest shared 64-request queue.
- Event notifications use `submitImmediately`. They never enter a desired
  schedule and therefore cannot be replayed by a later reconciliation.
- APNs device registration, tokens, provider calls, remote payloads, delivery
  monitoring, and server scheduling are out of scope.

## Composition root

```swift
import NotificationKit

@MainActor
final class AppNotificationRouter: NotificationResponseRouting {
    func handle(_ response: NotificationResponse) {
        // Translate the typed response into the app's route/deep link.
    }
}

let router = AppNotificationRouter()
let notifications = NotificationKit.NotificationClient(router: router)

// Refresh on initial composition and whenever scenePhase becomes .active.
await notifications.refreshAuthorization()
```

The client retains the router for its lifetime. Keep the client at the app
composition root; do not construct another notification client per screen.
When a process has no notification-tap route—typically a Widget/App Intent
extension that only reconciles a shared schedule—use `NotificationClient()`;
do not create a no-op router.
The system-center adapter is intentionally not public API. A narrowly named
`Testing` SPI exists for deterministic host tests; it is not an alternate
production wiring path or a policy configuration surface.

## Request authorization

Call the request API only from a person's explicit action after explaining the
immediate benefit:

```swift
let outcome = await notifications.requestAuthorizationFromUserAction()
```

The fixed portfolio policy requests alert and sound access. Badge,
critical-alert, and provisional capabilities are deliberately not configurable
or requested speculatively. A denied status returns `.needsSettings` without
calling the system request API again.

NotificationKit exposes `NotificationSettingsDestination.url` on UIKit
platforms. The host decides whether and how to present a Settings recovery CTA
and performs the actual open operation.

## Reconcile a local schedule

```swift
let namespace = try NotificationNamespace(
    "daily-reminders",
    legacyPrefixes: ["legacy.daily."]
)

let desired = try DesiredNotification(
    id: "evening",
    title: String(localized: "Daily reminder title"),
    body: String(localized: "Daily reminder body"),
    payload: ["route": "daily-review"],
    trigger: .calendar(
        DateComponents(hour: 20),
        repeats: true
    )
)

let report = await notifications.reconcile(
    namespace: namespace,
    desired: .loaded([desired])
)
```

Use `.notLoaded` while asynchronous preferences/data are unresolved. Pass
`.loaded([])` only when the host has authoritatively decided that no request
should remain. Reconciliation never prompts; when authorization cannot deliver,
it clears only the requested namespace and reports the reason.

## Submit an event notification

Use the separate one-shot API for a completed background/App Intent action,
geofence event, Live Activity fallback, or other event that already happened:

```swift
let outcome = await notifications.submitImmediately(
    namespace: try NotificationNamespace("imports"),
    notification: try ImmediateNotification(
        id: "completed-\(jobID)",
        title: String(localized: "Import complete"),
        body: String(localized: "Your items are ready."),
        payload: ["route": "imports/\(jobID)"]
    )
)
```

This API reads authorization but never prompts. Use a stable event identity or
a genuine event UUID as `id`; do not use the current timestamp merely to bypass
deduplication. Do not model an immediate event as a one-second desired schedule.

## Categories and responses

Register typed category specifications at composition time, before scheduling
notifications that reference them. NotificationKit installs one
`UNUserNotificationCenterDelegate`, presents foreground notifications using the
portfolio default (banner, list, and sound), and routes both package-owned and
unmanaged responses to `NotificationResponseRouting` on the main actor.

Unmanaged responses preserve compatibility with APNs and product-specific
notification code without pulling those systems into this package. The router
receives data and decides what the app should do; NotificationKit never opens a
URL or changes navigation.

## Requirements

- iOS 17+
- macOS 14+
- visionOS 1+
- Swift 6

Agent integration and migration guidance lives in
[`.agents/skills/integrate-notificationkit/`](.agents/skills/integrate-notificationkit/SKILL.md).
