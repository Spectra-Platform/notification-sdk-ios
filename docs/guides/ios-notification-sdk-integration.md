# iOS NotificationSDK Integration Guide

이 문서는 iOS 앱에서 `SpectraNotificationSDK`를 로컬 Swift Package로 붙이고,
AuthSDK token provider를 통해 알림 권한 요청, APNs 기기 등록, 수신/open 처리
준비를 연결하는 현재 기준을 설명한다. 앱 개발자는 내부 Delivery 서버 구조를
알 필요가 없고, Project API token을 iOS app bundle에 넣지 않는다.

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

## 4. 앱에서 쓰지 않는 server/testing surface

`SpectraNotificationClient`의 project-scoped test push, email send/status helper는
현재 호환성과 내부 테스트를 위해 남아 있지만, 모바일 앱의 기본 통합 표면이 아니다.
이 기능은 Project API token 또는 server-authorized token이 필요한 server/testing
성격이므로 iOS app bundle에 직접 넣지 않는다.

제품 앱에서는 위의 `SpectraCommunityNotificationClient`와
`SpectraAPNsDeviceRegistrationManager`를 우선 사용한다. 서버 발송 예시는 future
Server SDK 또는 앱 backend 문서로 분리한다.

서버 권한으로 처리해야 하는 기능:

- 특정 사용자/기기로 push 발송
- email 발송
- 발송 상태 운영 조회
- provider/admin style device 관리

## 5. Legacy project-scoped device registration

기존 project-scoped device registration API는 Delivery Push project path를 직접 확인해야
하는 내부 테스트용이다. 일반 앱 통합은 3번의 community device registration을 사용한다.

## 6. Legacy test push

테스트 push 발송은 앱 사용자의 동작이 아니라 서버/운영성 동작이다. 모바일 SDK에서는 deprecated surface로 유지하고, 이후 Server SDK로 분리한다.

`queued`는 서버가 요청을 durable하게 접수했다는 의미다. 실제 APNs provider accepted, iPhone 표시, 알림음 재생은 별도 상태다.

## 7. Sound manifest와 설치 보고

```swift
let notificationClient = SpectraNotificationClient(
    configuration: .init(
        baseURL: URL(string: "https://api.spectra.kr")!,
        projectId: "project_xxx"
    ),
    tokenProvider: tokenProvider
)

let manifest = try await notificationClient.fetchSoundManifest()

for sound in manifest.sounds where sound.enabled {
    try await notificationClient.reportSoundInstallation(
        soundId: sound.id,
        version: sound.version,
        fileName: sound.fileName
    )
}
```

`SpectraNotificationSoundSyncManager`를 사용하면 manifest 조회, HTTPS URL 검증,
checksum 검증, `Library/Sounds` 저장과 설치 보고를 한 번에 처리한다.

## 8. 현재 완료 상태

- Swift Package build/test
- community user-token APNs device registration/deactivation client
- app-user token provider 기반 sound manifest/install report client
- dynamic sound download/persistence
- rich notification attachment parser

## 아직 완료가 아닌 것

- AuthSDK adapter를 패키지 내부 product로 제공
- APNs 실기기 E2E
- foreground/background 중복 알림음 정책
- Storage Platform을 이용한 sound binary 저장소 연동
- push/email 발송용 Server SDK
