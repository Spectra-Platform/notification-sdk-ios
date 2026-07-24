import Foundation
import XCTest
@testable import SpectraNotificationSDK

final class SpectraNotificationClientTests: XCTestCase {
    func testRegisterDeviceUsesProjectTokenAndContractPath() async throws {
        let transport = RecordingTransport(response: Self.deviceEnvelope(status: "active"), statusCode: 201)
        let client = makeClient(transport: transport)
        let deviceId = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let appInstanceId = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!

        let device = try await client.registerDevice(.init(
            deviceId: deviceId,
            appInstanceId: appInstanceId,
            providerToken: String(repeating: "a", count: 64),
            appIdentifier: "kr.spectra.ios",
            environment: .test,
            locale: "ko-KR",
            idempotencyKey: "device-register-1"
        ))

        let request = await transport.lastRequest
        XCTAssertEqual(request?.httpMethod, "PUT")
        XCTAssertEqual(request?.url?.path, "/platform/v1/projects/project-test/notification/devices/\(deviceId.uuidString.lowercased())")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Authorization"), "Bearer project-token")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Idempotency-Key"), "device-register-1")
        XCTAssertEqual(device.deviceId, deviceId)
        XCTAssertEqual(device.providerTokenHint, "****aaaa")
    }

    func testDeactivateDeviceAcceptsNoContent() async throws {
        let transport = RecordingTransport(response: Data(), statusCode: 204)
        let client = makeClient(transport: transport)
        let deviceId = UUID(uuidString: "00000000-0000-4000-8000-000000000003")!

        try await client.deactivateDevice(deviceId: deviceId)

        let request = await transport.lastRequest
        XCTAssertEqual(request?.httpMethod, "DELETE")
        XCTAssertEqual(request?.url?.path, "/platform/v1/projects/project-test/notification/devices/\(deviceId.uuidString.lowercased())")
    }

    func testSendTestPushQueuesDeliveryRequest() async throws {
        let requestId = UUID(uuidString: "00000000-0000-4000-8000-000000000004")!
        let response = #"{"data":{"request_id":"\#(requestId.uuidString.lowercased())","status":"queued","created_at":"2026-07-24T02:20:00Z"}}"#.data(using: .utf8)!
        let transport = RecordingTransport(response: response, statusCode: 202)
        let client = makeClient(transport: transport)

        let queued = try await client.sendTestPush(.init(
            deviceId: UUID(uuidString: "00000000-0000-4000-8000-000000000005")!,
            title: "Test",
            body: "Hello",
            deepLink: URL(string: "spectra://notification/test"),
            data: ["kind": "local"],
            idempotencyKey: "push-1"
        ))

        let request = await transport.lastRequest
        XCTAssertEqual(request?.httpMethod, "POST")
        XCTAssertEqual(request?.url?.path, "/platform/v1/projects/project-test/notification/delivery-requests")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Idempotency-Key"), "push-1")
        XCTAssertEqual(queued.requestId, requestId)
        XCTAssertEqual(queued.status, "queued")
    }

    func testFetchSoundManifestUsesFutureSoundPath() async throws {
        let response = #"{"sounds":[{"id":"message","version":1,"fileName":"message-v1.caf","downloadURL":"https://cdn.example.test/message-v1.caf","checksum":"sha256:abc","enabled":true}]}"#.data(using: .utf8)!
        let transport = RecordingTransport(response: response, statusCode: 200)
        let client = makeClient(transport: transport)

        let manifest = try await client.fetchSoundManifest()
        let request = await transport.lastRequest

        XCTAssertEqual(manifest.sounds.first?.id, "message")
        XCTAssertEqual(request?.url?.path, "/platform/v1/projects/project-test/notification/sounds/manifest")
    }

    func testUnexpectedStatusThrowsWithoutLeakingToken() async {
        let transport = RecordingTransport(response: Data(#"{"error":{"code":"NOPE"}}"#.utf8), statusCode: 401)
        let client = makeClient(transport: transport)

        do {
            _ = try await client.sendTestPush(.init(
                deviceId: UUID(),
                title: "Test",
                body: "Hello",
                idempotencyKey: "push-2"
            ))
            XCTFail("Expected failure")
        } catch {
            XCTAssertEqual(error as? SpectraNotificationClientError, .unexpectedStatusCode(401))
            XCTAssertFalse(String(describing: error).contains("project-token"))
        }
    }

    func testCommunityRegisterAPNsDeviceUsesUserTokenAndAppFacingPath() async throws {
        let installationID = UUID(uuidString: "46f6609f-c319-40e2-9f2b-3f305ad71942")!
        let transport = RecordingTransport(
            response: Self.communityDeviceEnvelope(installationID: installationID, status: "active"),
            statusCode: 200
        )
        let client = makeCommunityClient(transport: transport)

        let registration = try await client.registerAPNsDevice(.init(
            installationID: installationID,
            deviceToken: "fixture-token-not-real",
            locale: "ko-KR",
            timeZone: "Asia/Seoul",
            idempotencyKey: "community-device-register-1"
        ))

        let request = await transport.lastRequest
        XCTAssertEqual(request?.httpMethod, "PUT")
        XCTAssertEqual(request?.url?.path, "/v1/me/devices/\(installationID.uuidString.lowercased())")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Authorization"), "Bearer oidc-user-token")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Idempotency-Key"), "community-device-register-1")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(registration.installationID, installationID)
        XCTAssertEqual(registration.deviceID, "ios:apns:fixture-token-hint")
        XCTAssertEqual(registration.platform, .ios)
        XCTAssertEqual(registration.channel, .apns)
        XCTAssertEqual(registration.status, .active)
        XCTAssertEqual(registration.createdAt, "2026-07-24T02:20:00Z")
        XCTAssertEqual(registration.updatedAt, "2026-07-24T02:20:00Z")

        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try XCTUnwrap(request?.httpBody)) as? [String: Any]
        )
        XCTAssertEqual(body["platform"] as? String, "ios")
        XCTAssertEqual(body["channel"] as? String, "apns")
        XCTAssertEqual(body["device_token"] as? String, "fixture-token-not-real")
        XCTAssertEqual(body["locale"] as? String, "ko-KR")
        XCTAssertEqual(body["time_zone"] as? String, "Asia/Seoul")
        XCTAssertEqual(
            Set(body.keys),
            Set(["platform", "channel", "device_token", "locale", "time_zone"])
        )
    }

    func testCommunityUnregisterUsesInstallationScopedDelete() async throws {
        let transport = RecordingTransport(response: Data(), statusCode: 204)
        let client = makeCommunityClient(transport: transport)
        let installationID = UUID(uuidString: "46f6609f-c319-40e2-9f2b-3f305ad71942")!

        try await client.unregisterDevice(installationID: installationID)

        let request = await transport.lastRequest
        XCTAssertEqual(request?.httpMethod, "DELETE")
        XCTAssertEqual(request?.url?.path, "/v1/me/devices/\(installationID.uuidString.lowercased())")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Authorization"), "Bearer oidc-user-token")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Idempotency-Key"), installationID.uuidString.lowercased())
        XCTAssertNil(request?.value(forHTTPHeaderField: "Content-Type"))
    }

    private func makeClient(transport: RecordingTransport) -> SpectraNotificationClient {
        SpectraNotificationClient(
            configuration: .init(baseURL: URL(string: "http://127.0.0.1:3002")!, projectId: "project-test"),
            tokenProvider: StaticSpectraAccessTokenProvider(token: "project-token"),
            transport: transport
        )
    }

    private func makeCommunityClient(transport: RecordingTransport) -> SpectraCommunityNotificationClient {
        SpectraCommunityNotificationClient(
            configuration: .init(baseURL: URL(string: "http://127.0.0.1:8080")!),
            tokenProvider: StaticSpectraAccessTokenProvider(token: "oidc-user-token"),
            transport: transport
        )
    }

    private static func deviceEnvelope(status: String) -> Data {
        Data("""
        {
          "data": {
            "device_id": "00000000-0000-4000-8000-000000000001",
            "app_instance_id": "00000000-0000-4000-8000-000000000002",
            "platform": "ios",
            "provider": "apns",
            "app_identifier": "kr.spectra.ios",
            "environment": "test",
            "locale": "ko-KR",
            "provider_token_hint": "****aaaa",
            "status": "\(status)",
            "created_at": "2026-07-24T02:20:00Z",
            "updated_at": "2026-07-24T02:20:00Z"
          }
        }
        """.utf8)
    }

    private static func communityDeviceEnvelope(installationID: UUID, status: String) -> Data {
        Data("""
        {
          "data": {
            "device_id": "ios:apns:fixture-token-hint",
            "installation_id": "\(installationID.uuidString.lowercased())",
            "platform": "ios",
            "channel": "apns",
            "status": "\(status)",
            "created_at": "2026-07-24T02:20:00Z",
            "updated_at": "2026-07-24T02:20:00Z"
          }
        }
        """.utf8)
    }
}

actor RecordingTransport: SpectraNotificationTransport {
    private let response: Data
    private let statusCode: Int
    private(set) var lastRequest: URLRequest?

    init(response: Data, statusCode: Int) {
        self.response = response
        self.statusCode = statusCode
    }

    func send(_ request: URLRequest) async throws -> SpectraNotificationResponse {
        lastRequest = request
        return SpectraNotificationResponse(statusCode: statusCode, data: response)
    }
}
