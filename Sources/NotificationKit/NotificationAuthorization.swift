import Foundation

public enum NotificationAuthorizationStatus: Sendable, Equatable {
    case unknown
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
}

public enum NotificationCapabilitySetting: Sendable, Equatable {
    case unknown
    case notSupported
    case disabled
    case enabled
}

public struct NotificationAuthorization: Sendable, Equatable {
    public let status: NotificationAuthorizationStatus
    public let alertSetting: NotificationCapabilitySetting
    public let soundSetting: NotificationCapabilitySetting

    public init(
        status: NotificationAuthorizationStatus,
        alertSetting: NotificationCapabilitySetting,
        soundSetting: NotificationCapabilitySetting
    ) {
        self.status = status
        self.alertSetting = alertSetting
        self.soundSetting = soundSetting
    }

    public var canSchedule: Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            true
        case .unknown, .notDetermined, .denied:
            false
        }
    }

    public var hasAlerts: Bool { alertSetting == .enabled }
    public var hasSound: Bool { soundSetting == .enabled }

    public var needsSettingsForStandardDelivery: Bool {
        switch status {
        case .authorized, .ephemeral:
            !hasAlerts || !hasSound
        case .denied:
            true
        case .unknown, .notDetermined, .provisional:
            false
        }
    }

    public static let unknown = Self(
        status: .unknown,
        alertSetting: .unknown,
        soundSetting: .unknown
    )
    public static let notDetermined = Self(
        status: .notDetermined,
        alertSetting: .disabled,
        soundSetting: .disabled
    )
    public static let denied = Self(
        status: .denied,
        alertSetting: .disabled,
        soundSetting: .disabled
    )
    public static let authorized = Self(
        status: .authorized,
        alertSetting: .enabled,
        soundSetting: .enabled
    )
    public static let provisional = Self(
        status: .provisional,
        alertSetting: .enabled,
        soundSetting: .enabled
    )
    public static let ephemeral = Self(
        status: .ephemeral,
        alertSetting: .enabled,
        soundSetting: .enabled
    )
}

public enum AuthorizationRequestOutcome: Sendable, Equatable {
    case granted
    case alreadyAuthorized
    case denied
    case needsSettings
    case failed
}
