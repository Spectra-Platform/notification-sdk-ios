import Foundation

public protocol SpectraInstallationIDStore: Sendable {
    func installationID() async -> UUID?
    func saveInstallationID(_ installationID: UUID) async throws
    func clearInstallationID() async throws
}

public actor InMemorySpectraInstallationIDStore: SpectraInstallationIDStore {
    private var storedInstallationID: UUID?

    public init(installationID: UUID? = nil) {
        self.storedInstallationID = installationID
    }

    public func installationID() async -> UUID? {
        storedInstallationID
    }

    public func saveInstallationID(_ installationID: UUID) async throws {
        storedInstallationID = installationID
    }

    public func clearInstallationID() async throws {
        storedInstallationID = nil
    }
}

public final class UserDefaultsSpectraInstallationIDStore: SpectraInstallationIDStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "com.spectra.notification.installation-id"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func installationID() async -> UUID? {
        defaults.string(forKey: key).flatMap(UUID.init(uuidString:))
    }

    public func saveInstallationID(_ installationID: UUID) async throws {
        defaults.set(installationID.uuidString.lowercased(), forKey: key)
    }

    public func clearInstallationID() async throws {
        defaults.removeObject(forKey: key)
    }
}

public struct SpectraAPNsDeviceRegistrationManager: Sendable {
    private let client: SpectraCommunityNotificationClient
    private let installationIDStore: any SpectraInstallationIDStore
    private let idGenerator: @Sendable () -> UUID

    public init(
        client: SpectraCommunityNotificationClient,
        installationIDStore: any SpectraInstallationIDStore = UserDefaultsSpectraInstallationIDStore(),
        idGenerator: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.client = client
        self.installationIDStore = installationIDStore
        self.idGenerator = idGenerator
    }

    public func currentInstallationID() async -> UUID? {
        await installationIDStore.installationID()
    }

    public func currentOrCreateInstallationID() async throws -> UUID {
        if let existing = await installationIDStore.installationID() {
            return existing
        }
        let installationID = idGenerator()
        try await installationIDStore.saveInstallationID(installationID)
        return installationID
    }

    public func registerAPNsDeviceToken(
        _ deviceToken: Data,
        locale: Locale = .current,
        timeZone: TimeZone = .current,
        idempotencyKey: String? = nil
    ) async throws -> SpectraCommunityPushDeviceRegistration {
        try await registerAPNsDeviceToken(
            Self.hexDeviceToken(deviceToken),
            localeIdentifier: locale.identifier,
            timeZoneIdentifier: timeZone.identifier,
            idempotencyKey: idempotencyKey
        )
    }

    public func registerAPNsDeviceToken(
        _ deviceToken: String,
        localeIdentifier: String = Locale.current.identifier,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        idempotencyKey: String? = nil
    ) async throws -> SpectraCommunityPushDeviceRegistration {
        let installationID = try await currentOrCreateInstallationID()
        return try await client.registerAPNsDevice(.init(
            installationID: installationID,
            deviceToken: deviceToken,
            locale: localeIdentifier,
            timeZone: timeZoneIdentifier,
            idempotencyKey: idempotencyKey ?? defaultRegisterIdempotencyKey(
                installationID: installationID,
                deviceToken: deviceToken
            )
        ))
    }

    public func unregisterAPNsDevice(idempotencyKey: String? = nil) async throws {
        guard let installationID = await installationIDStore.installationID() else {
            throw SpectraAPNsDeviceRegistrationManagerError.missingInstallationID
        }
        try await client.unregisterDevice(
            installationID: installationID,
            idempotencyKey: idempotencyKey ?? "apns-unregister-\(installationID.uuidString.lowercased())"
        )
        try await installationIDStore.clearInstallationID()
    }

    public static func hexDeviceToken(_ deviceToken: Data) -> String {
        deviceToken.map { String(format: "%02x", $0) }.joined()
    }

    private func defaultRegisterIdempotencyKey(installationID: UUID, deviceToken: String) -> String {
        let tokenHint = String(deviceToken.suffix(12))
        return "apns-register-\(installationID.uuidString.lowercased())-\(tokenHint)"
    }
}
