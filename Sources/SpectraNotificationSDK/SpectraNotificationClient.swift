import Foundation

public enum SpectraNotificationClientError: Error, Equatable, Sendable {
    case invalidBaseURL
    case invalidResponse
    case unexpectedStatusCode(Int)
    case emptyAccessToken
}

public enum SpectraAPNsDeviceRegistrationManagerError: Error, Equatable, Sendable {
    case missingInstallationID
}

public struct SpectraNotificationClient: Sendable {
    public struct Configuration: Sendable {
        public static let productionBaseURL = URL(string: "https://api.spectra.kr")!

        public let baseURL: URL
        public let projectId: String

        public init(baseURL: URL = Self.productionBaseURL, projectId: String) {
            self.baseURL = baseURL
            self.projectId = projectId
        }

        public static func production(projectId: String) -> Configuration {
            Configuration(projectId: projectId)
        }

        public static func custom(baseURL: URL, projectId: String) -> Configuration {
            Configuration(baseURL: baseURL, projectId: projectId)
        }
    }

    private let configuration: Configuration
    private let tokenProvider: any SpectraAccessTokenProviding
    private let transport: any SpectraNotificationTransport
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        configuration: Configuration,
        tokenProvider: any SpectraAccessTokenProviding,
        transport: any SpectraNotificationTransport = URLSessionSpectraNotificationTransport()
    ) {
        self.configuration = configuration
        self.tokenProvider = tokenProvider
        self.transport = transport
        self.encoder = JSONEncoder()
        self.decoder = Self.makeDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    public init(
        projectId: String,
        tokenProvider: any SpectraAccessTokenProviding,
        transport: any SpectraNotificationTransport = URLSessionSpectraNotificationTransport()
    ) {
        self.init(
            configuration: .production(projectId: projectId),
            tokenProvider: tokenProvider,
            transport: transport
        )
    }

    public init(
        auth tokenProvider: any SpectraAccessTokenProviding,
        projectID: String,
        transport: any SpectraNotificationTransport = URLSessionSpectraNotificationTransport()
    ) {
        self.init(projectId: projectID, tokenProvider: tokenProvider, transport: transport)
    }

    @available(*, deprecated, message: "Project-scoped device registration is a server/testing compatibility surface. Mobile apps should use SpectraCommunityNotificationClient or SpectraAPNsDeviceRegistrationManager.")
    public func registerDevice(_ registration: SpectraPushDeviceRegistration) async throws -> SpectraPushDevice {
        var request = try await makeRequest(
            method: "PUT",
            path: "notification/devices/\(registration.deviceId.uuidString.lowercased())",
            idempotencyKey: registration.idempotencyKey
        )
        request.httpBody = try encoder.encode(registration)
        let response: Envelope<SpectraPushDevice> = try await send(request, expectedStatusCodes: [200, 201])
        return response.data
    }

    @available(*, deprecated, message: "Project-scoped device deactivation is a server/testing compatibility surface. Mobile apps should unregister through SpectraCommunityNotificationClient or SpectraAPNsDeviceRegistrationManager.")
    public func deactivateDevice(deviceId: UUID) async throws {
        let request = try await makeRequest(
            method: "DELETE",
            path: "notification/devices/\(deviceId.uuidString.lowercased())"
        )
        _ = try await sendEmpty(request, expectedStatusCodes: [204])
    }

    @available(*, deprecated, message: "Push sending is a server-side/testing surface. Mobile apps should register the current device and handle notification events instead.")
    public func sendTestPush(_ push: SpectraPushDeliveryRequest) async throws -> SpectraPushQueuedDelivery {
        var request = try await makeRequest(
            method: "POST",
            path: "notification/delivery-requests",
            idempotencyKey: push.idempotencyKey
        )
        request.httpBody = try encoder.encode(push)
        let response: Envelope<SpectraPushQueuedDelivery> = try await send(request, expectedStatusCodes: [202])
        return response.data
    }

    @available(*, deprecated, message: "Email send belongs in a server SDK or backend using a Project API token. Mobile apps must not send project-authorized email directly.")
    public func sendEmail(_ email: SpectraEmailDeliveryRequest) async throws -> SpectraEmailQueuedDelivery {
        var request = try await makeRequest(
            method: "POST",
            path: "email/delivery-requests",
            idempotencyKey: email.idempotencyKey
        )
        request.httpBody = try encoder.encode(email)
        let response: Envelope<SpectraEmailQueuedDelivery> = try await send(request, expectedStatusCodes: [202])
        return response.data
    }

    @available(*, deprecated, message: "Email delivery status lookup belongs with the server-side email surface, not the mobile Notification SDK.")
    public func fetchEmailDeliveryRequest(_ requestId: UUID) async throws -> SpectraEmailDeliveryStatus {
        let request = try await makeRequest(
            method: "GET",
            path: "email/delivery-requests/\(requestId.uuidString.lowercased())"
        )
        let response: Envelope<SpectraEmailDeliveryStatus> = try await send(request, expectedStatusCodes: [200])
        return response.data
    }

    public func fetchSoundManifest() async throws -> SpectraNotificationSoundManifest {
        let request = try await makeRequest(method: "GET", path: "notification/sounds/manifest")
        return try await send(request, expectedStatusCodes: [200])
    }

    public func reportSoundInstallation(soundId: String, version: Int, fileName: String) async throws {
        struct Body: Encodable {
            let soundId: String
            let version: Int
            let fileName: String

            enum CodingKeys: String, CodingKey {
                case soundId = "sound_id"
                case version
                case fileName = "file_name"
            }
        }
        var request = try await makeRequest(method: "PUT", path: "notification/sounds/installations/\(soundId)")
        request.httpBody = try encoder.encode(Body(soundId: soundId, version: version, fileName: fileName))
        _ = try await sendEmpty(request, expectedStatusCodes: [200, 204])
    }

    private func makeRequest(method: String, path: String, idempotencyKey: String? = nil) async throws -> URLRequest {
        let token = try await tokenProvider.accessToken()
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SpectraNotificationClientError.emptyAccessToken
        }
        let normalizedBase = configuration.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: "\(normalizedBase)/platform/v1/projects/\(configuration.projectId)/\(path)") else {
            throw SpectraNotificationClientError.invalidBaseURL
        }
        components.percentEncodedPath = components.percentEncodedPath
            .replacingOccurrences(of: configuration.projectId, with: percentEncode(configuration.projectId))
        guard let url = components.url else {
            throw SpectraNotificationClientError.invalidBaseURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if method != "GET" && method != "DELETE" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest, expectedStatusCodes: Set<Int>) async throws -> T {
        let response = try await transport.send(request)
        guard expectedStatusCodes.contains(response.statusCode) else {
            throw SpectraNotificationClientError.unexpectedStatusCode(response.statusCode)
        }
        return try decoder.decode(T.self, from: response.data)
    }

    private func sendEmpty(_ request: URLRequest, expectedStatusCodes: Set<Int>) async throws {
        let response = try await transport.send(request)
        guard expectedStatusCodes.contains(response.statusCode) else {
            throw SpectraNotificationClientError.unexpectedStatusCode(response.statusCode)
        }
    }

    private func percentEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = Self.iso8601DateWithFractionalSeconds(from: value) {
                return date
            }
            if let date = Self.iso8601Date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an RFC3339 timestamp."
            )
        }
        return decoder
    }

    private static func iso8601DateWithFractionalSeconds(from value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }

    private static func iso8601Date(from value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}
