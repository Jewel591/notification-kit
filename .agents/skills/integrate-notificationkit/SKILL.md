---
name: integrate-notificationkit
description: Integrate, migrate, review, or troubleshoot an Apple app that uses the studio NotificationKit Swift package. Use when adding local notifications, replacing app-local UNUserNotificationCenter authorization/scheduling/delegate wrappers, fixing reminder toggles that disagree with OS authorization, migrating pending notification identifiers without duplicates, registering notification categories/actions, or routing notification taps and actions while keeping APNs and product policy in the host app.
---

# Integrate NotificationKit

Use NotificationKit as the app's only implementation of notification
authorization truth, local request reconciliation, one-shot event submission,
category registration, and `UNUserNotificationCenterDelegate` response handoff. Keep product eligibility,
localized copy, navigation, analytics, and APNs infrastructure in the host.

NotificationKit is internal portfolio infrastructure despite its public GitHub
distribution. Follow its fixed house standards. Do not add per-App options,
strategy protocols, or alternate wiring for behavior already fixed by the Kit.

## Read the current contract

Read the package `README.md`, `AGENTS.md`, and public declarations under
`Sources/NotificationKit/` before changing an app. Also obey the target app's
`AGENTS.md`.

Do not reconstruct API names from memory. In particular, preserve the semantic
difference between `NotificationDesiredSet.notLoaded` and `.loaded([])`.

## Audit before editing

Inventory all existing notification surfaces:

1. Every `UNUserNotificationCenter.current()` call.
2. Every authorization-status mirror and UserDefaults `isEnabled` / `hasAsked`
   key.
3. Every request identifier and prefix, including widget or extension writers.
4. Every scheduling, cancellation, and remove-all call.
5. Every category/action registration.
6. Every `UNUserNotificationCenter.delegate` assignment and response route.
7. APNs registration/token handling and remote-notification paths that must stay
   in the app.

Record legacy identifier prefixes before replacing code. A prefix must be
narrow enough to identify only that feature's existing requests.

## Install the package

Add `https://github.com/Jewel591/notification-kit` using an up-to-next-major
version requirement and link the `NotificationKit` product to the application
target. Link extension targets only when they submit one-shot immediate events
through `NotificationClient.shared`; extensions must not author desired
schedules. All processes must use stable namespaces and host IDs.

Do not use an exact version, branch, revision, local path, copied source, or a
second notification wrapper.

## Use the one composition-root path

Create one app router and install it into the module-qualified shared client.
The Kit constructs the sole production client and installs the package's sole
notification-center delegate automatically.

```swift
import NotificationKit

@MainActor
final class AppNotificationRouter: NotificationResponseRouting {
    private let routes: AppRouteStore

    init(routes: AppRouteStore) {
        self.routes = routes
    }

    func handle(_ response: NotificationResponse) {
        switch response.source {
        case let .managed(namespace, id):
            routes.openLocalNotification(
                namespace: namespace,
                id: id,
                payload: response.payload
            )
        case .unmanaged:
            routes.openRemoteNotification(response)
        }
    }
}

@MainActor
struct AppNotifications {
    let client = NotificationKit.NotificationClient.shared

    init(routes: AppRouteStore) {
        client.setResponseRouter(AppNotificationRouter(routes: routes))
    }
}
```

The shared client retains the router. Keep its wiring at the composition root. Remove
every other assignment to
`UNUserNotificationCenter.current().delegate`; route existing APNs responses
through `.unmanaged` instead of adding a second delegate.

The main App is the sole writer for desired-schedule reconciliation and category
replacement. A Widget/App Intent extension may link the package only to call
`NotificationClient.shared.submitImmediately(...)` for a completed event. It
must not reconcile, replace categories, set a router, or keep a direct scheduler.

The package's `Testing` SPI may be imported only by tests that need a fake
notification center. Never use it in a production target or treat it as an
alternate wiring/configuration path.

## Refresh operating-system truth

The shared client refreshes once at initialization and whenever the process
becomes active. The OS status is authoritative because a person can change it
in Settings while the app is backgrounded. Do not duplicate this lifecycle
observer or expose a host-owned refresh policy.

Do not persist or mirror authorization into UserDefaults. A host feature toggle
may still represent the person's product preference, but it is not proof that
the OS can deliver. UI derives the effective state from both values:

```swift
let canSchedule = reminderPreference.isEnabled
    && notifications.authorization.canSchedule
```

If the preference is enabled while authorization is denied, show recovery UI;
do not silently flip the preference off and do not claim reminders are active.

## Request only from an explicit action

Call `requestAuthorizationFromUserAction()` only inside the handler of a clear
person-initiated button or toggle. Never call it at app launch, initialization,
`onAppear`, an automatic `.task`, or from reconciliation.

The Kit always requests the studio-standard alert + sound capabilities. Do not
add App-specific authorization options. Handle `.needsSettings` by offering a
host-owned Settings CTA using `NotificationSettingsDestination.url` on UIKit
platforms. The host opens the URL; the Kit does not.

Render permission UI from the full `authorization` value: status alone is not
enough because alert or sound can be disabled independently in Settings.

Denial, restriction, and cancellation are normal states. Notification access
must never be required to complete onboarding or use unrelated/core features.

## Reconcile desired local notifications

Create one stable namespace per independently controlled notification feature.
Use stable logical IDs; never include a timestamp, localized string, random UUID,
or array index.

```swift
let namespace = try NotificationNamespace(
    "daily-reminders",
    legacyPrefixes: ["legacy.daily."]
)

let desired: NotificationDesiredSet
if preferencesAreStillLoading {
    desired = .notLoaded
} else if !reminderPreference.isEnabled {
    desired = .loaded([])
} else {
    desired = .loaded([
        try DesiredNotification(
            id: "evening",
            title: localizedTitle,
            body: localizedBody,
            payload: ["route": "daily-review"],
            trigger: .calendar(
                DateComponents(hour: 20),
                repeats: true
            )
        )
    ])
}

let report = await notifications.reconcile(
    namespace: namespace,
    desired: desired
)
```

Always pass already-localized strings. Reconcile after authoritative preferences
load, after an explicit preference change, after authorization becomes
deliverable, and when schedule inputs such as time zone or selected time change.
Do not schedule requests directly alongside the Kit.

Treat `.notLoaded` as the safe loading state. Using `.loaded([])` before
preferences finish loading erases valid reminders by design.

## Submit event notifications separately

Use `submitImmediately(namespace:notification:)` for an event that already
happened: App Intent completion/failure, geofence entry/exit, a Live Activity
fallback, or similar one-shot feedback. The Kit checks current authorization
without prompting and submits a `nil`-trigger system request.

```swift
let outcome = await notifications.submitImmediately(
    namespace: try NotificationNamespace("analysis-results"),
    notification: try ImmediateNotification(
        id: resultID.uuidString,
        title: localizedTitle,
        body: localizedBody,
        payload: ["route": "results/\(resultID)"]
    )
)
```

Use a stable event ID or a genuine event UUID. Do not manufacture a timestamp
solely to force duplicates. Never place immediate events in
`NotificationDesiredSet`; reconciliation represents future desired state and
must remain safely repeatable.

Immediate requests use `NotificationKitImmediate.<namespace>.<id>`, while
reconciled schedules retain `NotificationKit.<namespace>.<id>`. Do not
construct either identifier family in host code.

Successful event IDs are persisted for the Kit's fixed 90-day/512-entry window;
normal task and App Intent retries return `.alreadySubmitted`. Treat this as
durable retry idempotency, not cross-process exactly-once delivery: a crash
between system submission and receipt persistence can still duplicate.

## Migrate existing requests without duplicates

1. Preserve each old feature's exact identifier prefix.
2. Put those prefixes in that feature's `NotificationNamespace`.
3. Run the first authoritative reconciliation before deleting legacy scheduling
   code.
4. Verify the report removes legacy IDs and schedules
   `NotificationKit.<namespace>.<host-id>` replacements.
5. Delete the old scheduler, cancellation code, authorization mirror, and
   delegate assignment in the same app change.

Do not call `removeAllPendingNotificationRequests()` or
`removeAllDeliveredNotifications()`. NotificationKit deliberately preserves
other namespaces, other Kit consumers, and unmanaged APNs/product requests.

## Register actions once

Build localized `NotificationCategorySpec` values at composition time and call
`replaceCategories(_:)` with the complete desired category set before scheduling
notifications that reference them. The API replaces the system set; it is not
an additive registration operation.
Map `.defaultTap`, `.dismiss`, `.custom`, and `.textInput` in the app router.
The Kit provides data only; navigation remains host-owned.

## Preserve the boundary

- Keep APNs registration, device tokens, providers, remote payload schemas,
  delivery monitoring, transactional notification semantics, and server-side
  scheduling outside this package.
- Keep reminder eligibility, frequency, quiet hours, copy, localization,
  analytics, and growth policy in the host.
- Keep notification education and Settings presentation UI in the host.
- Do not generalize NotificationKit into camera/location/photo permission
  management.
- Do not expose new configuration for fixed foreground presentation, default
  sound, authorization options, identifier format, or the pending-request cap.
- APNs apps retain `UIApplicationDelegate` token callbacks, but remove their
  `UNUserNotificationCenterDelegate` conformance. NotificationKit presents
  foreground remote notifications and routes their custom string keys through
  `.unmanaged`; the App router interprets those keys.

## Verify the migration

Run focused tests proving:

- loading state cannot wipe pending requests;
- disabling a feature clears only its namespace;
- a denied status never triggers another system prompt;
- the host toggle and OS authorization render an honest recovery state;
- legacy IDs are replaced without duplicate delivery;
- unrelated and APNs identifiers survive reconciliation;
- notification actions reach the expected app route;
- immediate event notifications submit once and never prompt or enter desired state;
- concurrent namespaces never make independent stale capacity decisions;
- delegate routing and completion return to the main thread from a background callback;
- no second delegate or direct scheduler remains.

Finally run product-playbook's `notification-kit-lint`. Passing the structural
lint does not prove runtime authorization, migration, routing, or localized copy;
report those checks separately.
