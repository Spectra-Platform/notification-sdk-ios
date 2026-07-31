# NotificationSDK iOS Release Checklist

이 문서는 `notification-sdk-ios`를 Swift Package Manager로 배포할 때 확인할 기준이다. 현재 배포 방식은 Git URL 기반 SwiftPM package이며, 앱 쪽에서는 branch 또는 SemVer tag로 의존성을 고정한다.

## 배포 단위

- Repository: `https://github.com/Spectra-Platform/notification-sdk-ios.git`
- Swift package name: `SpectraNotificationSDK`
- Library product: `SpectraNotificationSDK`
- Minimum platform: iOS 17, macOS 14
- Swift tools version: 5.9

## 앱에서 추가하는 방법

개발 중 branch 의존성:

```swift
.package(
    url: "https://github.com/Spectra-Platform/notification-sdk-ios.git",
    branch: "main"
)
```

릴리즈 후 권장 의존성:

```swift
.package(
    url: "https://github.com/Spectra-Platform/notification-sdk-ios.git",
    .upToNextMinor(from: "0.1.0")
)
```

product:

```swift
.product(name: "SpectraNotificationSDK", package: "notification-sdk-ios")
```

## 버전 정책

- tag는 `vMAJOR.MINOR.PATCH` 형식을 사용한다. 예: `v0.1.0`
- `0.x` 구간에서는 public API 변경이 잦을 수 있으므로 앱은 `.upToNextMinor` 또는 exact version을 우선 사용한다.
- public type, initializer, protocol requirement 변경은 `CHANGELOG.md` 또는 release note에 적는다.
- Project API token, APNs `.p8`, FCM key, 운영 provider credential, sample device token은 tag에 포함하지 않는다.

## 릴리즈 전 로컬 검증

```bash
swift package resolve
swift package describe
swift test
git diff --check
```

CI도 같은 범위를 검증한다.

## tag 생성 절차

버전 번호가 확정된 뒤에만 tag를 만든다.

```bash
git status --short
git tag -a v0.1.0 -m "NotificationSDK iOS 0.1.0"
git push origin v0.1.0
```

## 릴리즈 전 확인 항목

- README의 설치 URL과 product 이름이 실제 `Package.swift`와 일치한다.
- `Package.swift`에 local path dependency가 없다.
- `.build`, `.swiftpm`, DerivedData, Xcode user state가 commit에 포함되지 않는다.
- 앱 bundle에 Project API token이나 provider secret을 넣지 않는다는 문구가 유지된다.
- AuthSDK와 직접 결합하지 않고 token provider protocol 경계가 유지된다.
- APNs 실기기 발송, foreground/background sound 동작, dynamic sound download/persistence는 release note에서 구현 상태를 구분한다.

## 현재 배포 경계

이 체크리스트는 SwiftPM package 배포 가능 상태를 다룬다. 아직 다음 항목은 구현 완료가 아니다.

- AuthSDK adapter를 패키지 내부 product로 제공
- APNs 실기기 E2E
- dynamic sound download/persistence
- foreground/background 중복 알림음 정책
- Storage Platform을 이용한 sound binary 저장소 연동
