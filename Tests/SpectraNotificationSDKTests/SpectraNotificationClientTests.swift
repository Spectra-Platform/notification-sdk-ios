import Foundation
import XCTest
@testable import SpectraNotificationSDK

final class SpectraNotificationClientTests: XCTestCase {
    func testProductionConfigurationOwnsNotificationEndpoint() {
        let configuration = SpectraNotificationClient.Configuration.production(projectId: "project-test")

        XCTAssertEqual(configuration.baseURL.absoluteString, "https://api.spectra.kr")
        XCTAssertEqual(configuration.projectId, "project-test")
    }

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

    func testSendEmailUsesAuthTokenProviderAndProjectEmailPath() async throws {
        let requestId = UUID(uuidString: "00000000-0000-4000-8000-000000000006")!
        let response = #"{"data":{"request_id":"\#(requestId.uuidString.lowercased())","status":"accepted","created_at":"2026-07-24T02:20:00.000Z"}}"#.data(using: .utf8)!
        let transport = RecordingTransport(response: response, statusCode: 202)
        let client = makeClient(transport: transport)

        let queued = try await client.sendEmail(.init(
            recipientEmail: "recipient@example.test",
            subject: "Spectra verification",
            text: "Your code is 123456",
            html: "<p>Your code is <strong>123456</strong></p>",
            idempotencyKey: "email-1"
        ))

        let recordedRequest = await transport.lastRequest
        let request = try XCTUnwrap(recordedRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/platform/v1/projects/project-test/email/delivery-requests")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer project-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), "email-1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(queued.requestId, requestId)
        XCTAssertEqual(queued.status, .accepted)

        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any]
        )
        XCTAssertEqual(body["recipient_email"] as? String, "recipient@example.test")
        XCTAssertEqual(body["subject"] as? String, "Spectra verification")
        XCTAssertEqual(body["text"] as? String, "Your code is 123456")
        XCTAssertEqual(body["html"] as? String, "<p>Your code is <strong>123456</strong></p>")
        XCTAssertEqual(
            Set(body.keys),
            Set(["recipient_email", "subject", "text", "html"])
        )
    }

    func testFetchEmailDeliveryStatusUsesPrivacySafeProjectPath() async throws {
        let requestId = UUID(uuidString: "00000000-0000-4000-8000-000000000007")!
        let response = """
        {
          "data": {
            "request_id": "\(requestId.uuidString.lowercased())",
            "template_id": "developer_single_email.v1",
            "recipient_masked": "r***@e***.test",
            "status": "delivered",
            "attempt_count": 1,
            "created_at": "2026-07-24T02:20:00.000Z",
            "updated_at": "2026-07-24T02:20:02.000Z",
            "completed_at": "2026-07-24T02:20:02.000Z"
          }
        }
        """.data(using: .utf8)!
        let transport = RecordingTransport(response: response, statusCode: 200)
        let client = makeClient(transport: transport)

        let status = try await client.fetchEmailDeliveryRequest(requestId)
        let request = await transport.lastRequest

        XCTAssertEqual(request?.httpMethod, "GET")
        XCTAssertEqual(request?.url?.path, "/platform/v1/projects/project-test/email/delivery-requests/\(requestId.uuidString.lowercased())")
        XCTAssertEqual(status.requestId, requestId)
        XCTAssertEqual(status.recipientMasked, "r***@e***.test")
        XCTAssertEqual(status.status, .delivered)
        XCTAssertEqual(status.attemptCount, 1)
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

    func testNotificationPermissionManagerUsesInjectedAuthorizer() async throws {
        let authorizer = MockNotificationAuthorizer(status: .notDetermined, requestResult: true)
        let manager = SpectraNotificationPermissionManager(authorizer: authorizer)

        let initialStatus = await manager.currentStatus()
        let shouldRegisterBeforeRequest = await manager.shouldRegisterForRemoteNotifications()
        XCTAssertEqual(initialStatus, .notDetermined)
        XCTAssertFalse(shouldRegisterBeforeRequest)

        let granted = try await manager.requestAuthorization(options: [.alert, .sound])

        let lastRequestedOptions = await authorizer.currentLastRequestedOptions()
        XCTAssertTrue(granted)
        XCTAssertEqual(lastRequestedOptions, [.alert, .sound])
        await authorizer.setStatus(.authorized)
        let shouldRegisterAfterAuthorization = await manager.shouldRegisterForRemoteNotifications()
        XCTAssertTrue(shouldRegisterAfterAuthorization)
    }

    func testAPNsDeviceTokenHexEncodingUsesLowercaseTwoDigitBytes() {
        let data = Data([0x00, 0x01, 0x0f, 0x10, 0xff])

        XCTAssertEqual(SpectraAPNsDeviceRegistrationManager.hexDeviceToken(data), "00010f10ff")
    }

    func testAPNsRegistrationManagerReusesGeneratedInstallationID() async throws {
        let installationID = UUID(uuidString: "11111111-2222-4333-8444-555555555555")!
        let store = InMemorySpectraInstallationIDStore()
        let manager = SpectraAPNsDeviceRegistrationManager(
            client: makeCommunityClient(transport: RecordingTransport(response: Data(), statusCode: 204)),
            installationIDStore: store,
            idGenerator: { installationID }
        )

        let first = try await manager.currentOrCreateInstallationID()
        let second = try await manager.currentOrCreateInstallationID()

        XCTAssertEqual(first, installationID)
        XCTAssertEqual(second, installationID)
    }

    func testAPNsRegistrationManagerRegistersHexTokenWithStableInstallationID() async throws {
        let installationID = UUID(uuidString: "46f6609f-c319-40e2-9f2b-3f305ad71942")!
        let transport = RecordingTransport(
            response: Self.communityDeviceEnvelope(installationID: installationID, status: "active"),
            statusCode: 200
        )
        let store = InMemorySpectraInstallationIDStore()
        let manager = SpectraAPNsDeviceRegistrationManager(
            client: makeCommunityClient(transport: transport),
            installationIDStore: store,
            idGenerator: { installationID }
        )

        let registration = try await manager.registerAPNsDeviceToken(
            Data([0xde, 0xad, 0xbe, 0xef]),
            locale: Locale(identifier: "ko_KR"),
            timeZone: TimeZone(identifier: "Asia/Seoul")!,
            idempotencyKey: "manager-register-1"
        )

        let request = await transport.lastRequest
        XCTAssertEqual(registration.installationID, installationID)
        XCTAssertEqual(request?.httpMethod, "PUT")
        XCTAssertEqual(request?.url?.path, "/v1/me/devices/\(installationID.uuidString.lowercased())")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Idempotency-Key"), "manager-register-1")

        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try XCTUnwrap(request?.httpBody)) as? [String: Any]
        )
        XCTAssertEqual(body["device_token"] as? String, "deadbeef")
        XCTAssertEqual(body["locale"] as? String, "ko_KR")
        XCTAssertEqual(body["time_zone"] as? String, "Asia/Seoul")
    }

    func testAPNsRegistrationManagerUnregistersStoredInstallationAndClearsStore() async throws {
        let installationID = UUID(uuidString: "46f6609f-c319-40e2-9f2b-3f305ad71942")!
        let transport = RecordingTransport(response: Data(), statusCode: 204)
        let store = InMemorySpectraInstallationIDStore(installationID: installationID)
        let manager = SpectraAPNsDeviceRegistrationManager(
            client: makeCommunityClient(transport: transport),
            installationIDStore: store
        )

        try await manager.unregisterAPNsDevice(idempotencyKey: "manager-unregister-1")

        let request = await transport.lastRequest
        XCTAssertEqual(request?.httpMethod, "DELETE")
        XCTAssertEqual(request?.url?.path, "/v1/me/devices/\(installationID.uuidString.lowercased())")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Idempotency-Key"), "manager-unregister-1")
        let storedInstallationID = await store.installationID()
        XCTAssertNil(storedInstallationID)
    }

    func testSoundSyncManagerDownloadsValidWavAndReportsInstallation() async throws {
        let soundURL = URL(string: "https://cdn.example.test/message-v1.wav")!
        var wav = Data("RIFF".utf8)
        wav.append(contentsOf: [0x04, 0x00, 0x00, 0x00])
        wav.append(Data("WAVE".utf8))
        let checksum = SpectraNotificationSoundSyncManager.sha256Hex(wav)
        let manifest = """
        {
          "sounds": [
            {
              "id": "message",
              "version": 1,
              "fileName": "message-v1.wav",
              "downloadURL": "\(soundURL.absoluteString)",
              "checksum": "sha256:\(checksum)",
              "enabled": true
            }
          ]
        }
        """.data(using: .utf8)!
        let transport = QueuedRecordingTransport(responses: [
            .init(statusCode: 200, data: manifest),
            .init(statusCode: 204, data: Data())
        ])
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let manager = SpectraNotificationSoundSyncManager(
            client: makeClient(transport: transport),
            downloader: MockSoundDownloader(dataByURL: [soundURL: wav]),
            installationStore: InMemorySpectraNotificationSoundInstallationStore(),
            soundsDirectory: temporaryDirectory,
            now: { Date(timeIntervalSince1970: 1_779_811_200) }
        )
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let results = try await manager.synchronize()

        XCTAssertEqual(results, [
            .init(soundID: "message", version: 1, fileName: "message-v1.wav", status: .installed)
        ])
        XCTAssertTrue(FileManager.default.fileExists(atPath: temporaryDirectory.appendingPathComponent("message-v1.wav").path))
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.map(\.httpMethod), ["GET", "PUT"])
        XCTAssertEqual(requests.first?.url?.path, "/platform/v1/projects/project-test/notification/sounds/manifest")
        XCTAssertEqual(requests.last?.url?.path, "/platform/v1/projects/project-test/notification/sounds/installations/message")
    }

    func testSoundChecksumSupportsHexAndSha256Prefix() {
        let data = Data("fixture".utf8)
        let checksum = SpectraNotificationSoundSyncManager.sha256Hex(data)

        XCTAssertTrue(SpectraNotificationSoundSyncManager.checksumMatches(data, checksum: checksum))
        XCTAssertTrue(SpectraNotificationSoundSyncManager.checksumMatches(data, checksum: "sha256:\(checksum)"))
        XCTAssertFalse(SpectraNotificationSoundSyncManager.checksumMatches(data, checksum: "sha256:wrong"))
    }

    func testRichNotificationAttachmentParsesAndValidatesImagePayload() throws {
        let userInfo: [AnyHashable: Any] = [
            "rich_attachment": [
                "kind": "image",
                "url": "https://media.example.test/notification-preview/image.jpg",
                "content_type": "image/jpeg; charset=binary",
                "expires_at": "2026-07-25T13:00:00Z"
            ]
        ]

        let attachment = try XCTUnwrap(SpectraRichNotificationAttachment(
            userInfo: userInfo,
            now: ISO8601DateFormatter().date(from: "2026-07-25T12:59:00Z")!
        ))

        XCTAssertEqual(attachment.kind, .image)
        XCTAssertEqual(attachment.contentType, "image/jpeg")
        XCTAssertEqual(attachment.supportedImageType?.fileExtension, "jpg")
        XCTAssertTrue(attachment.acceptsImageResponse(
            statusCode: 200,
            mimeType: "image/jpeg",
            expectedContentLength: 1024
        ))
        XCTAssertFalse(attachment.acceptsImageResponse(
            statusCode: 200,
            mimeType: "text/html",
            expectedContentLength: 1024
        ))
    }

    func testRichNotificationAttachmentRejectsExpiredPayload() {
        let userInfo: [AnyHashable: Any] = [
            "rich_attachment": [
                "kind": "image",
                "url": "https://media.example.test/notification-preview/image.jpg",
                "content_type": "image/jpeg",
                "expires_at": "2026-07-25T12:00:00Z"
            ]
        ]

        XCTAssertNil(SpectraRichNotificationAttachment(
            userInfo: userInfo,
            now: ISO8601DateFormatter().date(from: "2026-07-25T12:00:01Z")!
        ))
    }

    private func makeClient(transport: any SpectraNotificationTransport) -> SpectraNotificationClient {
        SpectraNotificationClient(
            configuration: .init(baseURL: URL(string: "http://127.0.0.1:3002")!, projectId: "project-test"),
            tokenProvider: StaticSpectraAccessTokenProvider(token: "project-token"),
            transport: transport
        )
    }

    private func makeCommunityClient(transport: any SpectraNotificationTransport) -> SpectraCommunityNotificationClient {
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

actor QueuedRecordingTransport: SpectraNotificationTransport {
    private var responses: [SpectraNotificationResponse]
    private var requests: [URLRequest] = []

    init(responses: [SpectraNotificationResponse]) {
        self.responses = responses
    }

    func send(_ request: URLRequest) async throws -> SpectraNotificationResponse {
        requests.append(request)
        guard responses.isEmpty == false else {
            return SpectraNotificationResponse(statusCode: 500, data: Data())
        }
        return responses.removeFirst()
    }

    func recordedRequests() -> [URLRequest] {
        requests
    }
}

struct MockSoundDownloader: SpectraNotificationSoundDownloading {
    let dataByURL: [URL: Data]

    func data(from url: URL) async throws -> Data {
        guard let data = dataByURL[url] else {
            throw URLError(.fileDoesNotExist)
        }
        return data
    }
}

actor MockNotificationAuthorizer: SpectraNotificationAuthorizing {
    private var status: SpectraNotificationAuthorizationStatus
    private let requestResult: Bool
    private(set) var lastRequestedOptions: SpectraNotificationAuthorizationOptions?

    init(status: SpectraNotificationAuthorizationStatus, requestResult: Bool) {
        self.status = status
        self.requestResult = requestResult
    }

    func authorizationStatus() async -> SpectraNotificationAuthorizationStatus {
        status
    }

    func requestAuthorization(options: SpectraNotificationAuthorizationOptions) async throws -> Bool {
        lastRequestedOptions = options
        return requestResult
    }

    func setStatus(_ status: SpectraNotificationAuthorizationStatus) {
        self.status = status
    }

    func currentLastRequestedOptions() -> SpectraNotificationAuthorizationOptions? {
        lastRequestedOptions
    }
}
