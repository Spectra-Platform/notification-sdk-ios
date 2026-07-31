# Spectra Notification SDK for iOS

Swift Package for Spectra Platform Push/Notification integration.

This package is the client/mobile Notification SDK. It is designed around app
actions such as requesting notification permission, registering the current
device, handling notification payloads, syncing notification sounds and opening
deep links. It does not make mobile apps aware of Delivery Platform internals,
and mobile/browser bundles must never contain Project API tokens or provider
secrets.

For app integration, use [iOS NotificationSDK integration guide](docs/guides/ios-notification-sdk-integration.md).

## 설치

Xcode에서 `File > Add Package Dependencies...`를 열고 아래 Git URL을 추가한다.

```text
https://github.com/Spectra-Platform/notification-sdk-ios.git
```

개발 중에는 `main` branch를 사용할 수 있다.

```swift
.package(
    url: "https://github.com/Spectra-Platform/notification-sdk-ios.git",
    branch: "main"
)
```

버전 태그가 발행된 뒤에는 앱에서 SemVer 범위를 고정한다.

```swift
.package(
    url: "https://github.com/Spectra-Platform/notification-sdk-ios.git",
    .upToNextMinor(from: "0.1.0")
)
```

target dependency에는 product 이름을 사용한다.

```swift
.product(name: "SpectraNotificationSDK", package: "notification-sdk-ios")
```

릴리즈 전 확인 절차는 [release checklist](docs/guides/release-checklist.md)를 따른다. 현재 저장소는 SwiftPM Git package로 소비 가능하도록 준비하며, 최초 SemVer tag는 공개 버전 번호를 확정한 뒤 별도로 생성한다.

Implemented first slice:

- App-facing APNs permission and device registration flow.
- SDK-owned production Notification endpoint defaults to `https://api.spectra.kr`.
  App integrations normally pass only an AuthSDK-backed token provider.
- Community user-token based APNs device registration through
  `PUT /v1/me/devices/{installation_id}` and device deactivation through
  `DELETE /v1/me/devices/{installation_id}`
- Future-facing dynamic notification sound manifest/reporting surface
- iOS notification permission helper with injectable `UserNotifications`
  adapter
- APNs installation ID persistence and device token registration manager
- Dynamic iOS notification sound synchronization helper for
  `Library/Sounds`
- Rich notification attachment payload parser for Notification Service
  Extensions

Legacy/project-scoped helpers for device registration, test push and email send
still exist for compatibility and internal tooling, but they are not the mobile
client SDK surface. Mobile apps must not embed Project API tokens; server-side
email/push send belongs in a future Server SDK or the app backend.

The SDK can now download enabled manifest sounds, verify HTTPS URL, exact
versioned filename, SHA-256 checksum and basic `.caf`/`.wav`/`.aiff` magic
bytes, then atomically store the file in iOS `Library/Sounds`. If sound sync
fails, push delivery should continue and fall back to an already installed or
bundled sound.

## iOS APNs 등록 예시

앱은 AuthSDK에서 만든 token provider를 넘기고, NotificationSDK가 권한 상태와
APNs device token 등록을 맡는다.

```swift
import SpectraNotificationSDK

let client = SpectraCommunityNotificationClient(
    configuration: .init(baseURL: URL(string: "https://api.spectra.kr")!),
    tokenProvider: authClient
)

let permission = SpectraNotificationPermissionManager(
    authorizer: UserNotificationAuthorizationAdapter()
)

let granted = try await permission.requestAuthorization()
if granted {
    // UIApplication.shared.registerForRemoteNotifications() 이후 받은 deviceToken 전달
    let manager = SpectraAPNsDeviceRegistrationManager(client: client)
    try await manager.registerAPNsDeviceToken(
        deviceToken,
        locale: .current,
        timeZone: .current
    )
}
```

## 동적 알림음 동기화

앱 시작 또는 foreground 진입 시 manifest를 확인하고, 설치된 파일만 APNs
`sound` filename으로 사용하게 만든다. 이 흐름은 app-user token provider로
호출되어야 하며, Project API token을 앱에 넣지 않는다.

```swift
let notificationClient = SpectraNotificationClient(
    configuration: .init(
        baseURL: URL(string: "https://api.spectra.kr")!,
        projectId: "project_123"
    ),
    tokenProvider: authClient
)

let soundSync = SpectraNotificationSoundSyncManager(client: notificationClient)
let results = try await soundSync.synchronize()
```

## Rich notification payload

Notification Service Extension에서는 SDK parser로 `rich_attachment`를 먼저
검증한 뒤, 지원되는 image일 때만 attachment 다운로드를 시도한다.

```swift
if let attachment = SpectraRichNotificationAttachment(userInfo: request.content.userInfo),
   attachment.isSupportedImageAttachment {
    // attachment.url을 다운로드하고 attachment.supportedImageType의 typeIdentifier 사용
}
```

## 로컬 검증

```bash
swift package describe
swift test
```
