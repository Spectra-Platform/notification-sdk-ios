import Foundation

public enum SpectraRichNotificationAttachmentKind: String, Codable, Equatable, Sendable {
    case image
    case audio
    case file
    case unknown
}

public struct SpectraRichNotificationAttachment: Equatable, Sendable {
    public static let maximumImageBytes: Int64 = 10 * 1024 * 1024

    public let kind: SpectraRichNotificationAttachmentKind
    public let url: URL
    public let contentType: String
    public let expiresAt: Date

    public init?(
        userInfo: [AnyHashable: Any],
        now: Date = Date()
    ) {
        guard let attachment = Self.dictionaryValue(userInfo["rich_attachment"]),
              let rawKind = Self.stringValue(attachment["kind"]),
              let rawURL = Self.stringValue(attachment["url"]),
              let url = URL(string: rawURL),
              let rawContentType = Self.stringValue(attachment["content_type"]),
              let rawExpiresAt = Self.stringValue(attachment["expires_at"]),
              let expiresAt = Self.date(from: rawExpiresAt),
              expiresAt > now else {
            return nil
        }

        self.kind = SpectraRichNotificationAttachmentKind(rawValue: rawKind) ?? .unknown
        self.url = url
        self.contentType = Self.normalizedContentType(rawContentType)
        self.expiresAt = expiresAt
    }

    public var isHTTPS: Bool {
        url.scheme?.lowercased() == "https" && url.host?.isEmpty == false
    }

    public var supportedImageType: SpectraRichNotificationImageType? {
        SpectraRichNotificationImageType(contentType: contentType)
    }

    public var isSupportedImageAttachment: Bool {
        kind == .image && isHTTPS && supportedImageType != nil
    }

    public func acceptsImageResponse(
        statusCode: Int? = nil,
        mimeType: String? = nil,
        expectedContentLength: Int64? = nil
    ) -> Bool {
        guard isSupportedImageAttachment else { return false }
        if let statusCode, !(200..<300).contains(statusCode) {
            return false
        }
        if let expectedContentLength, expectedContentLength > Self.maximumImageBytes {
            return false
        }
        if let mimeType, SpectraRichNotificationImageType(contentType: mimeType) == nil {
            return false
        }
        return true
    }

    private static func dictionaryValue(_ value: Any?) -> [AnyHashable: Any]? {
        if let dictionary = value as? [AnyHashable: Any] {
            return dictionary
        }
        if let dictionary = value as? NSDictionary {
            var result: [AnyHashable: Any] = [:]
            dictionary.forEach { key, value in
                guard let hashableKey = key as? AnyHashable else { return }
                result[hashableKey] = value
            }
            return result
        }
        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let value as String:
            return value
        case let value as NSString:
            return value as String
        default:
            return nil
        }
    }

    private static func normalizedContentType(_ contentType: String) -> String {
        contentType
            .split(separator: ";", maxSplits: 1)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private static func date(from rawValue: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: rawValue) {
            return date
        }
        return ISO8601DateFormatter().date(from: rawValue)
    }
}

public struct SpectraRichNotificationImageType: Equatable, Sendable {
    public let contentType: String
    public let fileExtension: String
    public let typeIdentifier: String

    public init?(contentType: String) {
        let normalized = contentType
            .split(separator: ";", maxSplits: 1)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        guard let known = Self.supported[normalized] else {
            return nil
        }
        self.contentType = normalized
        self.fileExtension = known.fileExtension
        self.typeIdentifier = known.typeIdentifier
    }

    private static let supported: [String: (fileExtension: String, typeIdentifier: String)] = [
        "image/jpeg": ("jpg", "public.jpeg"),
        "image/jpg": ("jpg", "public.jpeg"),
        "image/png": ("png", "public.png"),
        "image/gif": ("gif", "com.compuserve.gif"),
        "image/heic": ("heic", "public.heic"),
        "image/heif": ("heif", "public.heif"),
        "image/tiff": ("tiff", "public.tiff")
    ]
}
