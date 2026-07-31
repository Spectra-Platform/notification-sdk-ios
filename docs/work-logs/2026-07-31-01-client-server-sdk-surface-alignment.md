# Client/server SDK surface alignment

## 작업 목적과 이해한 내용

Notification SDK는 내부적으로 Delivery API를 호출하더라도 앱 개발자에게는 Notification 경험으로 보여야 한다.
사용자가 직접 다루는 모바일 SDK 표면은 알림 권한 요청, APNs device registration, 수신/open 이벤트 처리와
동적 알림음·rich notification helper가 중심이다. Project API token이 필요한 email send, push send, 운영성
발송은 Server SDK 또는 app backend 경계로 분리해야 한다.

## 문제 진단 또는 기존 동작

- README와 integration guide가 `Delivery Platform`, `Project-token client`, email delivery request를 앱 통합 흐름 안에 크게 노출했다.
- `SpectraNotificationClient`에는 project-scoped device/test push/email send/status helper가 있고, 이 API가 모바일 앱 기본 표면처럼 보일 수 있었다.
- 기존 소비자나 테스트를 깨지 않기 위해 해당 helper를 바로 삭제하기보다는 compatibility surface로 남기고 server/testing 경계를 명확히 해야 했다.

## 적용한 내용과 주요 변경 파일

- `Sources/SpectraNotificationSDK/SpectraNotificationClient.swift`
  - `registerDevice`, `deactivateDevice`, `sendTestPush`, `sendEmail`, `fetchEmailDeliveryRequest`를 deprecated로 표시했다.
  - deprecation message에 server-side/testing surface이며 모바일 앱이 Project API token을 보유하면 안 된다는 경계를 남겼다.
- `Sources/SpectraNotificationSDK/SpectraNotificationModels.swift`
  - project-scoped push device와 push/email delivery request/status response 모델을 deprecated로 표시했다.
- `README.md`
  - app-facing first slice를 APNs permission/device registration, sound/rich notification 중심으로 재정렬했다.
  - legacy project-scoped helpers는 compatibility/internal tooling으로만 남긴다고 명시했다.
- `Tests/SpectraNotificationSDKTests/SpectraNotificationClientTests.swift`
  - production endpoint 테스트 이름을 Delivery가 아니라 Notification 기준으로 정리했다.
- `docs/guides/ios-notification-sdk-integration.md`
  - 앱 통합 설명에서 내부 Delivery 서버 구조를 첫 개념으로 보여주지 않도록 수정했다.
  - project-scoped test push/email helper는 앱 기본 흐름이 아니라 server/testing surface로 분리했다.
- `HANDOFF.md`, `WORKLOG.md`
  - client/server SDK 권한 경계와 Server SDK 분리 방향을 기록했다.

## 실행한 검증과 결과

- `swift test`
  - 통과: 19 tests, 0 failures
  - deprecated server/testing surface를 검증하는 기존 테스트에서 deprecation warning이 발생했지만 실패하지 않았다.
- `git diff --check`
  - 통과

## 남은 작업, 미검증 항목 또는 주의사항

- Deprecated project-scoped device/test push/email helper를 실제 Server SDK 또는 backend helper로 이동하는 작업은 아직 수행하지 않았다.
- Notification receive/open event handler의 app-facing API는 아직 별도 slice로 구현하지 않았다.
- 실제 APNs 실기기 수신, 알림 tap/open E2E는 별도 검증이 필요하다.
