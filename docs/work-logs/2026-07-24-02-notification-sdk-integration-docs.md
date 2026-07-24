# 2026-07-24 — NotificationSDK iOS integration guide

## 작업 목적

`notification-sdk-ios`를 iOS 앱에 local Swift Package로 붙이고 AuthSDK token provider와 연결하는 흐름을 문서화한다.

## 기존 상태

- README에는 구현된 첫 slice 목록만 있었다.
- AuthSDK token provider adapter, community device registration, project-token client, test push, sound manifest 사용 예제가 별도 문서로 정리되어 있지 않았다.

## 적용 내용

- `README.md`
  - integration guide 링크 추가
- `HANDOFF.md`
  - iOS integration guide 위치 기록
- `WORKLOG.md`
  - 이번 문서 작업 인덱스 추가
- `docs/guides/ios-notification-sdk-integration.md`
  - local Swift Package 연결 방법
  - AuthSDK adapter 예제
  - community APNs device registration/deactivation 예제
  - project-token client와 test push 예제
  - sound manifest/install report 예제
  - dynamic sound download/persistence 미구현 경계 정리

## 검증

- `swift test` 7 tests 통과.
- 문서 파일 존재 확인 통과.
- `git diff --check` 통과.

## 남은 작업

- AuthSDK adapter를 SDK product로 제공할지 결정
- `spectra-ios` dynamic sound manager를 SDK로 추출
- 실제 APNs 실기기 E2E 후 guide 보정
- Storage Platform sound binary 저장소 연동 후 guide 갱신

## 커밋 기록

- `docs: add notification sdk integration guide`
