# iOS NotificationSDK Integration Guide

이 문서는 iOS 앱에서 `SpectraNotificationSDK`를 로컬 Swift Package로 붙이고, AuthSDK token provider를 통해 Delivery Platform Push API를 호출하는 현재 기준을 설명한다.

## 1. Package 추가

현재는 Swift Package Manager registry 배포 전이므로 로컬 package로 연결한다.

Xcode 기준:

1. `File > Add Package Dependencies...`
2. `Add Local...`
3. `Spectra-Platform/notification-sdk-ios` 선택
4. app target에 `SpectraNotificationSDK` product 추가

`Package.swift`를 사용하는 앱/샘플이면 다음처럼 local dependency를 둔다.

```swift
.package(path: "../Spectra-Platform/notification-sdk-ios")
```

AuthSDK와 함께 사용할 경우:

```swift
.package(path: "../Spectra-Platform/auth-sdk-ios"),
.package(path: "../Spectra-Platform/notification-sdk-ios")
```

## 2. AuthSDK token provider adapter

앱 bundle에 Project API token을 넣지 않는다. AuthSDK가 app-user access token을 제공하고, NotificationSDK는 얇은 adapter를 통해 token string만 받는다.

```swift
import SpectraAuthSDK
import SpectraNotificationSDK

struct NotificationTokenProvider: SpectraAccessTokenProviding {
    let auth: any TokenProvider

    func accessToken() async throws -> String {
        try await auth.getAccessToken().value
    }
}
```

현재 `notification-sdk-ios`는 AuthSDK에 hard dependency를 두지 않는다. 패키지 결합을 피하기 위해 앱에서 adapter를 소유한다.

## 3. Community device registration

앱 최종 사용자 토큰으로 APNs device를 등록하는 app-facing client다.

```swift
let tokenProvider = NotificationTokenProvider(auth: authClient)

let notificationClient = SpectraCommunityNotificationClient(
    configuration: .init(baseURL: URL(string: "https://console.spectra.kr")!),
    tokenProvider: tokenProvider
)

let installationID = UUID()

let registered = try await notificationClient.registerAPNsDevice(
    SpectraCommunityAPNsDeviceRegistration(
        installationID: installationID,
        deviceToken: apnsDeviceTokenHex,
        locale: Locale.current.identifier,
        timeZone: TimeZone.current.identifier
    )
)
```

해제:

```swift
try await notificationClient.unregisterDevice(installationID: installationID)
```

## 4. Project-token client

`SpectraNotificationClient`는 Project 단위 Push API를 호출한다. 이 client는 현재 test push, provider/admin style operation에 가깝다. Project API token을 iOS app bundle에 직접 넣지 않는다.

내부 테스트나 server-owned tooling에서만 `StaticSpectraAccessTokenProvider`를 사용할 수 있다.

```swift
let projectTokenProvider = StaticSpectraAccessTokenProvider(token: "project_api_token")

let projectClient = SpectraNotificationClient(
    configuration: .init(
        baseURL: URL(string: "https://console.spectra.kr")!,
        projectId: "project_xxx"
    ),
    tokenProvider: projectTokenProvider
)
```

## 5. Device registration

```swift
let deviceID = UUID()
let appInstanceID = UUID()

let device = try await projectClient.registerDevice(
    SpectraPushDeviceRegistration(
        deviceId: deviceID,
        appInstanceId: appInstanceID,
        providerToken: apnsDeviceTokenHex,
        appIdentifier: "kr.spectra.ios",
        environment: .test,
        locale: Locale.current.identifier,
        idempotencyKey: "register-\(deviceID.uuidString)"
    )
)
```

비활성화:

```swift
try await projectClient.deactivateDevice(deviceId: deviceID)
```

## 6. Test push

```swift
let queued = try await projectClient.sendTestPush(
    SpectraPushDeliveryRequest(
        deviceId: deviceID,
        title: "Spectra test",
        body: "NotificationSDK test push",
        deepLink: URL(string: "spectra://notifications/test"),
        data: ["source": "ios-sdk-guide"],
        idempotencyKey: "test-push-\(UUID().uuidString)"
    )
)
```

`queued`는 Delivery가 요청을 durable하게 접수했다는 의미다. 실제 APNs provider accepted, iPhone 표시, 알림음 재생은 별도 상태다.

## 7. Sound manifest와 설치 보고

```swift
let manifest = try await projectClient.fetchSoundManifest()

for sound in manifest.sounds where sound.enabled {
    // 현재 SDK는 download/persistence를 구현하지 않는다.
    // 후속 slice에서 downloadURL, checksum, fileName을 사용해 Library/Sounds에 저장한다.
    try await projectClient.reportSoundInstallation(
        soundId: sound.id,
        version: sound.version,
        fileName: sound.fileName
    )
}
```

현재 미구현:

- `downloadURL`에서 음원 다운로드
- checksum 검증
- `.caf`/`.wav`/`.aiff` 형식·30초 제한 검증
- `Library/Sounds` 저장
- bundled fallback sound 선택

기존 `spectra-ios`의 dynamic sound manager가 구현 reference이며, 다음 slice에서 SDK로 추출해야 한다.

## 8. 현재 완료 상태

- Swift Package build/test
- community user-token APNs device registration/deactivation client
- project-token device registration/deactivation client
- test push request client
- sound manifest/install report client

## 아직 완료가 아닌 것

- AuthSDK adapter를 패키지 내부 product로 제공
- APNs 실기기 E2E
- dynamic sound download/persistence
- foreground/background 중복 알림음 정책
- Storage Platform을 이용한 sound binary 저장소 연동

