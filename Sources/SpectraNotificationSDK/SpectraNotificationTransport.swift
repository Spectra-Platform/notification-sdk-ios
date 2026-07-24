import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct SpectraNotificationResponse: Sendable {
    public let statusCode: Int
    public let data: Data

    public init(statusCode: Int, data: Data) {
        self.statusCode = statusCode
        self.data = data
    }
}

public protocol SpectraNotificationTransport: Sendable {
    func send(_ request: URLRequest) async throws -> SpectraNotificationResponse
}

public struct URLSessionSpectraNotificationTransport: SpectraNotificationTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> SpectraNotificationResponse {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SpectraNotificationClientError.invalidResponse
        }
        return SpectraNotificationResponse(statusCode: http.statusCode, data: data)
    }
}
