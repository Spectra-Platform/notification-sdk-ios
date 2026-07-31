# HANDOFF — notification-sdk-ios

## Purpose and ownership

`notification-sdk-ios` is the iOS client SDK for Spectra Platform Push. It is
owned by `50 Spectra — 인증·알림 개발자` until the app-facing package surface is
stable enough for `20 Spectra — 앱 개발자` to integrate into Spectra iOS.

## Confirmed decisions

- The app must not embed Project API tokens.
- App-facing Notification SDK surface is permission request, APNs device registration,
  notification receive/open handling and sound/rich-notification helpers. Internal Delivery
  server naming should not be the first concept shown to app developers.
- The SDK accepts a token provider protocol so AuthSDK can supply short-lived
  access tokens later without creating a hard package dependency in this first
  slice.
- Legacy project-scoped device registration uses the Delivery Platform contract:
  `PUT /platform/v1/projects/{project_id}/notification/devices/{device_id}`.
- App-facing device registration uses `SpectraCommunityNotificationClient` and
  `SpectraAPNsDeviceRegistrationManager` with app-user tokens.
- Legacy test push uses device-bound enqueue:
  `POST /platform/v1/projects/{project_id}/notification/delivery-requests`.
- Single email send uses the Delivery Platform project API:
  `POST /platform/v1/projects/{project_id}/email/delivery-requests`.
  The SDK never sends SMTP itself and never stores project secrets; it only asks
  the injected AuthSDK-compatible token provider for a short-lived access token.
  Delivery Platform must verify the token against Auth Platform and the requested
  project/scope before enqueueing.
  This project-scoped email surface is now treated as legacy/server-side compatibility and
  should move to a future Server SDK or backend helper before mobile SDK release.
- Email status recovery uses:
  `GET /platform/v1/projects/{project_id}/email/delivery-requests/{request_id}`
  and exposes privacy-safe metadata only.
  This status helper follows the same server-side boundary as email send.
- Dynamic notification sound sync uses:
  - `GET /platform/v1/projects/{project_id}/notification/devices/{device_id}/sound-manifest`
  - `PUT /platform/v1/projects/{project_id}/notification/devices/{device_id}/sound-installations`
- Sound binary download, HTTPS/checksum/basic format validation and
  `Library/Sounds` persistence are implemented in `SpectraNotificationSoundSyncManager`.
- iOS app integration guide lives at `docs/guides/ios-notification-sdk-integration.md`.
- Swift Package Manager 배포는 Git URL 기반으로 시작한다. repository URL은 `https://github.com/Spectra-Platform/notification-sdk-ios.git`, product 이름은 `SpectraNotificationSDK`다.
- release tag는 `vMAJOR.MINOR.PATCH` 형식으로 만들며, 최초 tag는 공개 버전 번호를 확정한 뒤 생성한다. 현재 문서와 CI는 tag 배포가 가능한 상태를 준비하지만 tag 자체는 만들지 않는다.

## Current implementation boundary

- Local Swift Package only.
- Unit tests use `URLProtocol` mock; no real network, APNs, simulator or device
  E2E is performed.
- GitHub remote is configured as `https://github.com/Spectra-Platform/notification-sdk-ios.git`.
- Local `main` tracks `origin/main`.
- `.github/workflows/ci.yml` validates SwiftPM resolve/describe/test.
- SwiftPM release checklist lives at `docs/guides/release-checklist.md`.

## Next checks before integration

1. Keep project-scoped test push/email helpers out of app-facing examples and move them to a
   Server SDK/backend package when that package exists.
2. Add an AuthSDK adapter for `SpectraAccessTokenProviding`.
3. Confirm the app-user sound manifest endpoint contract with Delivery/Notification producer.
4. Integrate this local package into `spectra-ios` and run simulator/real device
   tests only after user confirmation.

Last code comparison: 2026-07-31.
