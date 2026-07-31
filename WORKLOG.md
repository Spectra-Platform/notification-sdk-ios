# WORKLOG — notification-sdk-ios

## 2026-07-31 — Client/server SDK surface alignment

- 목적: Notification SDK가 내부 Delivery 서버 구조나 server-side 발송 기능을 앱-facing public surface처럼 보이게 하지 않도록 정리한다.
- 결과: README와 iOS integration guide를 알림 권한 요청, APNs 기기 등록, 수신/open/sound/rich notification 중심으로 재정렬했다. Project-scoped device/test push/email send/status helper는 기존 호환성을 위해 유지하되 deprecated server/testing surface로 표시했다. HANDOFF에 “앱 bundle에는 Project API token을 넣지 않으며, server-side email/push send는 future Server SDK/backend helper로 분리” 결정을 추가했다.
- 검증: `swift test` 19 tests 통과. deprecated legacy helper를 테스트하는 케이스에서 의도한 deprecation warning이 출력됐다. `git diff --check` 통과.
- 상세 로그:
  [docs/work-logs/2026-07-31-01-client-server-sdk-surface-alignment.md](docs/work-logs/2026-07-31-01-client-server-sdk-surface-alignment.md)

## 2026-07-24 — Auth token 기반 Email delivery surface

- 목적: NotificationSDK가 AuthSDK token provider를 받아 Delivery Platform의 Project Email API를 호출할 수 있게 한다.
- 결과: `sendEmail`, `fetchEmailDeliveryRequest`, privacy-safe email delivery 모델과 fractional RFC3339 date decoding을 추가했다. SDK는 SMTP를 직접 보내지 않고 서버 API만 호출한다.
- 검증: `swift test` 9 tests 통과.
- 상세 로그:
  [docs/work-logs/2026-07-24-04-auth-token-email-delivery-surface.md](docs/work-logs/2026-07-24-04-auth-token-email-delivery-surface.md)

## 2026-07-24 — NotificationSDK SwiftPM release readiness

- 목적: iOS NotificationSDK를 Swift Package Manager Git URL로 붙일 수 있는 배포 준비 상태로 정리한다.
- 결과: GitHub Actions SwiftPM CI, README Git URL/branch/SemVer 설치 예시, release checklist와 HANDOFF 기준을 추가했다.
- 검증: `swift package resolve`, `swift package describe`, `swift test` 7 tests, workflow YAML parse, `git diff --check` 통과.
- 상세 로그:
  [docs/work-logs/2026-07-24-03-notification-sdk-spm-release-readiness.md](docs/work-logs/2026-07-24-03-notification-sdk-spm-release-readiness.md)

## 2026-07-24 — iOS Notification SDK integration guide

- 목적: AuthSDK token provider를 받아 NotificationSDK를 사용하는 iOS 앱 통합 방식을 문서화한다.
- 결과: README guide 링크, HANDOFF 위치 기록, local package/device/test push/sound manifest 예제 문서를 추가했다.
- 검증: `swift test` 7 tests, 문서 파일 존재 확인, `git diff --check` 통과.
- 상세 로그:
  [docs/work-logs/2026-07-24-02-notification-sdk-integration-docs.md](docs/work-logs/2026-07-24-02-notification-sdk-integration-docs.md)

## 2026-07-24 — iOS Notification SDK remote alignment

- 목적: 집컴의 local-only 초기 커밋과 GitHub `origin/main`의 실제 Notification SDK 구현 이력을 충돌 없이 정렬한다.
- 결과: local-only 초기 커밋은 `backup/home-notification-sdk-ios-f82417c` 브랜치에 보존하고, `main`은 `origin/main` 기준으로 맞췄다. 저장소 연속성 문서 `HANDOFF.md`, `WORKLOG.md`와 상세 작업 로그를 원격 main 위에 추가했다.
- 검증: `swift test` 7 tests 통과, `git diff --check` 통과.
- 상세 로그:
  [docs/work-logs/2026-07-24-01-notification-sdk-ios-local.md](docs/work-logs/2026-07-24-01-notification-sdk-ios-local.md)

## 2026-07-24 — iOS Notification SDK local package bootstrap

- 목적: Console Email/Notification E2E 이후 iOS 앱에서 Platform Push 기능을 로컬
  Swift Package로 연결할 수 있는 첫 SDK 경계를 만든다.
- 결과: local-only git repository와 `SpectraNotificationSDK` Swift Package를
  생성했다. Bearer token provider 주입, APNs device registration/deactivation,
  device-bound test push, dynamic sound manifest 조회와 설치 보고 API를 구현했다.
- 검증: `swift test`, `git diff --check` 통과.
- 상세 로그:
  [docs/work-logs/2026-07-24-01-notification-sdk-ios-local.md](docs/work-logs/2026-07-24-01-notification-sdk-ios-local.md)
