import Foundation

public struct NotificationActionOptions: OptionSet, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let foreground = Self(rawValue: 1 << 0)
    public static let destructive = Self(rawValue: 1 << 1)
    public static let authenticationRequired = Self(rawValue: 1 << 2)
}

public enum NotificationActionSpec: Sendable, Equatable {
    case button(
        id: String,
        title: String,
        options: NotificationActionOptions = []
    )
    case textInput(
        id: String,
        title: String,
        buttonTitle: String,
        placeholder: String,
        options: NotificationActionOptions = []
    )
}

public struct NotificationCategoryOptions: OptionSet, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let customDismissAction = Self(rawValue: 1 << 0)
    public static let allowInCarPlay = Self(rawValue: 1 << 1)
    public static let hiddenPreviewsShowTitle = Self(rawValue: 1 << 2)
    public static let hiddenPreviewsShowSubtitle = Self(rawValue: 1 << 3)
}

public struct NotificationCategorySpec: Sendable, Equatable {
    public let id: String
    public let actions: [NotificationActionSpec]
    public let intentIdentifiers: [String]
    public let options: NotificationCategoryOptions

    public init(
        id: String,
        actions: [NotificationActionSpec],
        intentIdentifiers: [String] = [],
        options: NotificationCategoryOptions = []
    ) {
        self.id = id
        self.actions = actions
        self.intentIdentifiers = intentIdentifiers
        self.options = options
    }
}
