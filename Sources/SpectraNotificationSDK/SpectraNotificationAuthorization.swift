import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

public enum SpectraNotificationAuthorizationStatus: String, Codable, Equatable, Sendable {
    case notDetermined = "not_determined"
    case denied
    case authorized
    case provisional
    case ephemeral
    case unknown
}

public struct SpectraNotificationAuthorizationOptions: OptionSet, Equatable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let badge = SpectraNotificationAuthorizationOptions(rawValue: 1 << 0)
    public static let sound = SpectraNotificationAuthorizationOptions(rawValue: 1 << 1)
    public static let alert = SpectraNotificationAuthorizationOptions(rawValue: 1 << 2)
    public static let provisional = SpectraNotificationAuthorizationOptions(rawValue: 1 << 3)

    public static let standard: SpectraNotificationAuthorizationOptions = [.alert, .sound, .badge]
}

public struct SpectraNotificationForegroundPresentationOptions: OptionSet, Equatable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let badge = SpectraNotificationForegroundPresentationOptions(rawValue: 1 << 0)
    public static let sound = SpectraNotificationForegroundPresentationOptions(rawValue: 1 << 1)
    public static let banner = SpectraNotificationForegroundPresentationOptions(rawValue: 1 << 2)
    public static let list = SpectraNotificationForegroundPresentationOptions(rawValue: 1 << 3)

    public static let quiet: SpectraNotificationForegroundPresentationOptions = []
    public static let standard: SpectraNotificationForegroundPresentationOptions = [.banner, .list, .sound, .badge]
}

public protocol SpectraNotificationAuthorizing: Sendable {
    func authorizationStatus() async -> SpectraNotificationAuthorizationStatus
    func requestAuthorization(options: SpectraNotificationAuthorizationOptions) async throws -> Bool
}

public struct SpectraNotificationPermissionManager: Sendable {
    private let authorizer: any SpectraNotificationAuthorizing

    public init(authorizer: any SpectraNotificationAuthorizing) {
        self.authorizer = authorizer
    }

    public func currentStatus() async -> SpectraNotificationAuthorizationStatus {
        await authorizer.authorizationStatus()
    }

    public func requestAuthorization(
        options: SpectraNotificationAuthorizationOptions = .standard
    ) async throws -> Bool {
        try await authorizer.requestAuthorization(options: options)
    }

    public func shouldRegisterForRemoteNotifications() async -> Bool {
        switch await currentStatus() {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied, .unknown:
            return false
        }
    }
}

#if canImport(UserNotifications)
public final class UserNotificationAuthorizationAdapter: SpectraNotificationAuthorizing, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func authorizationStatus() async -> SpectraNotificationAuthorizationStatus {
        let settings = await center.notificationSettings()
        return SpectraNotificationAuthorizationStatus(settings.authorizationStatus)
    }

    public func requestAuthorization(options: SpectraNotificationAuthorizationOptions = .standard) async throws -> Bool {
        try await center.requestAuthorization(options: UNAuthorizationOptions(options))
    }
}

public extension SpectraNotificationAuthorizationStatus {
    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        case .provisional:
            self = .provisional
        case .ephemeral:
            self = .ephemeral
        @unknown default:
            self = .unknown
        }
    }
}

public extension UNAuthorizationOptions {
    init(_ options: SpectraNotificationAuthorizationOptions) {
        self.init()
        if options.contains(.badge) { insert(.badge) }
        if options.contains(.sound) { insert(.sound) }
        if options.contains(.alert) { insert(.alert) }
        if options.contains(.provisional) { insert(.provisional) }
    }
}

public extension UNNotificationPresentationOptions {
    init(_ options: SpectraNotificationForegroundPresentationOptions) {
        self.init()
        if options.contains(.badge) { insert(.badge) }
        if options.contains(.sound) { insert(.sound) }
        if options.contains(.banner) { insert(.banner) }
        if options.contains(.list) { insert(.list) }
    }
}
#endif
