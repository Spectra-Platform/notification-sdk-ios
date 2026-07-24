import Foundation

public enum SpectraCommunityPushPlatform: String, Codable, Sendable {
    case ios
}

public enum SpectraCommunityPushChannel: String, Codable, Sendable {
    case apns
}

public enum SpectraCommunityPushDeviceStatus: String, Codable, Sendable {
    case active
    case inactive
}

public struct SpectraCommunityAPNsDeviceRegistration: Encodable, Equatable, Sendable {
    public let installationID: UUID
    public let platform: SpectraCommunityPushPlatform
    public let channel: SpectraCommunityPushChannel
    public let deviceToken: String
    public let locale: String
    public let timeZone: String
    public let idempotencyKey: String

    public init(
        installationID: UUID,
        platform: SpectraCommunityPushPlatform = .ios,
        channel: SpectraCommunityPushChannel = .apns,
        deviceToken: String,
        locale: String,
        timeZone: String,
        idempotencyKey: String = UUID().uuidString
    ) {
        self.installationID = installationID
        self.platform = platform
        self.channel = channel
        self.deviceToken = deviceToken
        self.locale = locale
        self.timeZone = timeZone
        self.idempotencyKey = idempotencyKey
    }

    enum CodingKeys: String, CodingKey {
        case platform
        case channel
        case deviceToken = "device_token"
        case locale
        case timeZone = "time_zone"
    }
}

public struct SpectraCommunityPushDeviceRegistration: Decodable, Equatable, Sendable {
    public let deviceID: String
    public let installationID: UUID
    public let platform: SpectraCommunityPushPlatform
    public let channel: SpectraCommunityPushChannel
    public let status: SpectraCommunityPushDeviceStatus
    public let createdAt: String
    public let updatedAt: String

    public init(
        deviceID: String,
        installationID: UUID,
        platform: SpectraCommunityPushPlatform,
        channel: SpectraCommunityPushChannel,
        status: SpectraCommunityPushDeviceStatus,
        createdAt: String,
        updatedAt: String
    ) {
        self.deviceID = deviceID
        self.installationID = installationID
        self.platform = platform
        self.channel = channel
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case installationID = "installation_id"
        case platform
        case channel
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
