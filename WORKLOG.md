# WORKLOG — notification-sdk-ios

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
