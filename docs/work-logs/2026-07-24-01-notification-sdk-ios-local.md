# 2026-07-24 — iOS Notification SDK local package bootstrap

## 목적

사용자가 요청한 iOS Auth/Notification SDK 로컬 패키지 흐름 중 Notification SDK의
첫 package boundary를 만든다. 이후 GitHub remote가 생성되어 현재 `main`은
`origin/main`을 기준으로 정렬되었다.

## 기존 상태

- `Spectra-Platform/notification-sdk-ios`는 원래 원격 clone이 아니라 빈 local directory였다.
- Delivery Platform에는 APNs device, test push, dynamic sound manifest/install
  API가 구현되어 있었다.
- `spectra-ios`에는 동적 sound 다운로드와 `Library/Sounds` 저장 구현이 이미 있으나,
  아직 SDK package로 추출되지 않았다.

## 적용 내용

- `Package.swift` 생성
- `SpectraNotificationClient` 구현
  - `SpectraAccessTokenProviding` protocol로 AuthSDK token provider 경계 마련
  - device registration/deactivation
  - device-bound test push enqueue
  - dynamic sound manifest fetch
  - dynamic sound installation report
- Codable model과 SDK error type 추가
- URLProtocol mock 기반 unit test 추가
- README, HANDOFF, WORKLOG 작성

## 검증

- `swift test` 통과
- `git diff --check` 통과

## 남은 작업과 미검증 항목

- AuthSDK adapter 구현
- `spectra-ios` 기존 sound manager의 download/checksum/format/duration/
  `Library/Sounds` persistence 로직을 SDK로 추출
- Spectra iOS local package integration
- Simulator/real-device APNs registration and dynamic sound playback E2E

## 커밋 기록

- 이번 구현은 `feat: bootstrap ios notification sdk` 커밋에 포함한다.
