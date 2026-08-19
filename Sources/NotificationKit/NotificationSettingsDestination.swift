#if canImport(UIKit)
import Foundation
import UIKit

public enum NotificationSettingsDestination {
    public static var url: URL? {
        URL(string: UIApplication.openNotificationSettingsURLString)
    }
}
#endif
