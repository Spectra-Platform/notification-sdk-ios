# Spectra Notification SDK for iOS

Swift Package for Spectra Platform Push/Notification integration.

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

- Project-token based device registration
- Device deactivation
- Test push delivery request
- Community user-token based APNs device registration through
  `PUT /v1/me/devices/{installation_id}` and device deactivation through
  `DELETE /v1/me/devices/{installation_id}`
- Future-facing dynamic notification sound manifest/reporting surface

The SDK does not persist downloaded sound files yet. iOS `Library/Sounds`
download and checksum management remains a later implementation slice.

## 로컬 검증

```bash
swift package describe
swift test
```
