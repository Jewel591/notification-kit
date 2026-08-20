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
- Authorization is never persisted or mirrored in an app-owned boolean. The
  shared client refreshes it initially and whenever the app becomes active.
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
let notifications = NotificationKit.NotificationClient.shared
notifications.setResponseRouter(router)
```

The shared client retains the router, refreshes authorization on construction,
and refreshes again whenever the process becomes active. It is the only
production client and the main App is the sole reconciliation/category writer.
Extensions may submit one-shot events through `.shared`, but must not reconcile
the shared pending queue or install a second response router.
The system-center adapter is intentionally not public API. A narrowly named
`Testing` SPI exists for deterministic host tests; it is not an alternate
production wiring path or a policy configuration surface.

## Request authorization

Call the request API only from a person's explicit action after explaining the
immediate benefit:

```swift
let outcome = await notifications.requestAuthorizationFromUserAction()
```

The fixed portfolio policy requests alert and sound access. The returned
authorization value also exposes the actual alert and sound settings so UI can
honestly distinguish partial system configuration. Badge,
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
deduplication. Successful IDs are retained for 90 days, capped at the newest
512, so ordinary task/App Intent retries return `.alreadySubmitted`. This is
durable retry idempotency, not a cross-process exactly-once guarantee: a process
crash between system submission and receipt persistence can still duplicate.
Do not model an immediate event as a one-second desired schedule.
Immediate requests use a distinct managed identifier family, so reconciliation
for the same namespace cannot remove a delivered event notification or replace
a future scheduled request with a nil-trigger request.

## Categories and responses

Replace the complete typed category set at composition time with
`replaceCategories(_:)`, before scheduling
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
