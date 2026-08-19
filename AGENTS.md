# NotificationKit

Public Swift package that standardizes notification authorization truth, local
notification reconciliation, one-shot event submission, categories/actions,
and response routing across Ivens' Apple app portfolio.

## Product boundary

- The package owns the current `UNUserNotificationCenter` authorization truth,
  an explicitly user-triggered request API, deterministic local-notification
  reconciliation, one-shot event submission, package-owned identifiers,
  category registration, and the single notification-center delegate handoff.
- Host apps own reminder eligibility, schedules as business decisions, copy and
  localization, onboarding and Settings UI, growth frequency, quiet-hour
  policy, analytics, and every deep-link/navigation action.
- APNs registration, device tokens, providers, payload delivery, server-side
  scheduling, delivery observation, kill switches, and transactional business
  notifications are permanently outside this package. If repeated evidence
  later justifies shared push infrastructure, create a separate narrow package.
- This is not a generic permission package. Camera, photos, location,
  microphone, speech, tracking, and other protected resources remain in each
  host app.
- OnboardingKit never requests notification authorization. An onboarding screen
  may explain the benefit, but its explicit button calls the host-owned
  composition root, which delegates the notification request to this package.

## Fixed behavior

- Reconciliation never requests authorization.
- Authorization always requests the portfolio-standard alert + sound options.
  Badge, provisional, critical-alert, and per-App authorization option knobs do
  not belong in the public API without demonstrated cross-product divergence.
- Authorization requests can only enter through
  `requestAuthorizationFromUserAction()` and are coalesced while in flight.
- `.notLoaded` desired state is a no-op; `.loaded([])` deliberately clears that
  namespace. This distinction prevents asynchronous loading from erasing valid
  schedules.
- The package only mutates its requested namespace and configured legacy
  prefixes. It never calls a remove-all API.
- Identifiers use `NotificationKit.<namespace>.<host-id>`. Legacy identifiers
  are adopted during reconciliation and rewritten to package-owned IDs.
- The global 64-pending-request limit preserves requests outside the current
  namespace. When capacity is insufficient, the current namespace keeps its
  soonest-firing requests and reports overflow.
- All in-process namespace reconciliations share one serialized mutation queue;
  two features cannot each decide from the same stale capacity snapshot.
- Immediate event notifications use a separate non-reconciled API. They check
  current authorization, never prompt, and cannot be replayed by schedule refresh.
- The package delegate always completes the system callback. It extracts a
  Sendable response first, then routes on the main actor. It never opens a URL
  or performs navigation itself.
- No package-owned UserDefaults keys or app-level `isEnabled` flag exist.
  Authorization status is read from the operating system; feature enablement
  remains host-owned.
- Foreground presentation, default sound, identifier format, pending-request
  cap behavior, and delegate completion semantics are fixed house standards,
  not initializer configuration.

## Engineering

- Swift 6 strict concurrency. Public API supports iOS 17, macOS 14, and
  visionOS 1.
- Zero third-party and zero studio-kit dependencies. UserNotifications and
  Foundation only, with a UIKit-gated Settings URL convenience.
- Keep one library target. Do not add a NotificationKitUI target.
- Every authorization, identifier, reconciliation, immediate-submission,
  category, or routing change requires focused Swift Testing coverage against
  an injected notification center. Tests must never schedule real notifications.
- Delegate changes require a background-entry regression test proving both
  routing and the system completion callback execute on the main thread.
- Keep `.agents/skills/integrate-notificationkit/SKILL.md` aligned with the
  public API and migration order.
- Keep product-playbook's `notification-kit-lint` aligned with the public SPM
  URL and module-qualified composition-root construction.
