import Foundation

public struct SpectraCommunityNotificationClient: Sendable {
    public struct Configuration: Sendable {
        public let baseURL: URL

        public init(baseURL: URL) {
            self.baseURL = baseURL
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
        self.decoder = JSONDecoder()
    }

    public func registerAPNsDevice(
        _ registration: SpectraCommunityAPNsDeviceRegistration
    ) async throws -> SpectraCommunityPushDeviceRegistration {
        var request = try await makeRequest(
            method: "PUT",
            installationID: registration.installationID,
            idempotencyKey: registration.idempotencyKey
        )
        request.httpBody = try encoder.encode(registration)
        let response: Envelope<SpectraCommunityPushDeviceRegistration> = try await send(
            request,
            expectedStatusCodes: [200, 201]
        )
        return response.data
    }

    public func unregisterDevice(
        installationID: UUID,
        idempotencyKey: String? = nil
    ) async throws {
        let request = try await makeRequest(
            method: "DELETE",
            installationID: installationID,
            idempotencyKey: idempotencyKey ?? installationID.uuidString.lowercased()
        )
        try await sendEmpty(request, expectedStatusCodes: [204])
    }

    private func makeRequest(
        method: String,
        installationID: UUID,
        idempotencyKey: String
    ) async throws -> URLRequest {
        let token = try await tokenProvider.accessToken()
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SpectraNotificationClientError.emptyAccessToken
        }
        let normalizedBase = configuration.baseURL.absoluteString.trimmingCharacters(
            in: CharacterSet(charactersIn: "/")
        )
        guard let url = URL(
            string: "\(normalizedBase)/v1/me/devices/\(installationID.uuidString.lowercased())"
        ) else {
            throw SpectraNotificationClientError.invalidBaseURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        if method != "GET" && method != "DELETE" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
}
