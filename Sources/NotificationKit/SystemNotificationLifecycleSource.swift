import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class SystemNotificationLifecycleSource: NSObject, NotificationLifecycleSourcing {
    var becameActiveHandler: (() -> Void)?
    private var isStarted = false

    func start() {
        guard !isStarted else { return }
        isStarted = true

        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        #elseif canImport(AppKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        #endif
    }

    @objc private func didBecomeActive() {
        becameActiveHandler?()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
