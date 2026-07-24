import Foundation

public enum SpectraPushEnvironment: String, Codable, Sendable {
    case test
    case live
}

public enum SpectraPushPlatform: String, Codable, Sendable {
    case ios
    case android
}

public enum SpectraPushProvider: String, Codable, Sendable {
    case apns
    case fcm
}

public struct SpectraPushDeviceRegistration: Encodable, Equatable, Sendable {
    public let deviceId: UUID
    public let appInstanceId: UUID
    public let platform: SpectraPushPlatform
    public let provider: SpectraPushProvider
    public let providerToken: String
    public let appIdentifier: String
    public let environment: SpectraPushEnvironment
    public let locale: String?
    public let idempotencyKey: String

    public init(
        deviceId: UUID,
        appInstanceId: UUID,
        platform: SpectraPushPlatform = .ios,
        provider: SpectraPushProvider = .apns,
        providerToken: String,
        appIdentifier: String,
        environment: SpectraPushEnvironment,
        locale: String? = nil,
        idempotencyKey: String
    ) {
        self.deviceId = deviceId
        self.appInstanceId = appInstanceId
        self.platform = platform
        self.provider = provider
        self.providerToken = providerToken
        self.appIdentifier = appIdentifier
        self.environment = environment
        self.locale = locale
        self.idempotencyKey = idempotencyKey
    }

    enum CodingKeys: String, CodingKey {
        case appInstanceId = "app_instance_id"
        case platform
        case provider
        case providerToken = "provider_token"
        case appIdentifier = "app_identifier"
        case environment
        case locale
    }
}

public struct SpectraPushDevice: Codable, Equatable, Sendable {
    public let deviceId: UUID
    public let appInstanceId: UUID
    public let platform: SpectraPushPlatform
    public let provider: SpectraPushProvider
    public let appIdentifier: String
    public let environment: SpectraPushEnvironment
    public let locale: String?
    public let providerTokenHint: String
    public let status: String
    public let inactiveReason: String?
    public let createdAt: Date
    public let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case appInstanceId = "app_instance_id"
        case platform
        case provider
        case appIdentifier = "app_identifier"
        case environment
        case locale
        case providerTokenHint = "provider_token_hint"
        case status
        case inactiveReason = "inactive_reason"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct SpectraPushDeliveryRequest: Encodable, Equatable, Sendable {
    public let deviceId: UUID
    public let title: String
    public let body: String
    public let deepLink: URL?
    public let data: [String: String]?
    public let idempotencyKey: String

    public init(
        deviceId: UUID,
        title: String,
        body: String,
        deepLink: URL? = nil,
        data: [String: String]? = nil,
        idempotencyKey: String
    ) {
        self.deviceId = deviceId
        self.title = title
        self.body = body
        self.deepLink = deepLink
        self.data = data
        self.idempotencyKey = idempotencyKey
    }

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case title
        case body
        case deepLink = "deep_link"
        case data
    }
}

public struct SpectraPushQueuedDelivery: Codable, Equatable, Sendable {
    public let requestId: UUID
    public let status: String
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case status
        case createdAt = "created_at"
    }
}

public struct SpectraNotificationSound: Codable, Equatable, Sendable {
    public let id: String
    public let version: Int
    public let fileName: String
    public let downloadURL: URL
    public let checksum: String
    public let enabled: Bool

    public init(id: String, version: Int, fileName: String, downloadURL: URL, checksum: String, enabled: Bool) {
        self.id = id
        self.version = version
        self.fileName = fileName
        self.downloadURL = downloadURL
        self.checksum = checksum
        self.enabled = enabled
    }
}

public struct SpectraNotificationSoundManifest: Codable, Equatable, Sendable {
    public let sounds: [SpectraNotificationSound]

    public init(sounds: [SpectraNotificationSound]) {
        self.sounds = sounds
    }
}

struct Envelope<T: Decodable>: Decodable {
    let data: T
}
