# 2026-07-24-04 Auth token 기반 Email delivery surface

## 작업 목적과 이해한 내용

- 모든 Platform SDK는 앱에 secret을 넣지 않고 AuthSDK가 제공하는 token provider를 통해 서버 기능을 사용한다.
- NotificationSDK는 push뿐 아니라 이메일 발송 요청 표면도 제공해야 한다.
- SDK가 직접 SMTP를 수행하지 않고 Delivery Platform의 Project API에 요청하면, 서버가 Auth Platform token introspection으로 project·scope·audience를 검증한 뒤 queue한다.

## 문제 진단 또는 기존 동작

- `SpectraNotificationClient`는 Project device registration, test push, sound manifest/reporting만 제공했다.
- 이메일 발송 요청 API와 privacy-safe 상태 조회 모델이 없어 iOS 앱에서 같은 SDK 인증 패턴으로 Email 기능을 호출할 수 없었다.
- Delivery Platform의 공개 Project Email API는 fractional seconds가 포함된 RFC3339 timestamp를 반환하므로 기존 `.iso8601` decoder만으로는 일부 응답 decoding 실패 가능성이 있었다.

## 적용한 내용과 주요 변경 파일

- `Sources/SpectraNotificationSDK/SpectraNotificationClient.swift`
  - `sendEmail(_:)` 추가: `POST /platform/v1/projects/{project_id}/email/delivery-requests`.
  - `fetchEmailDeliveryRequest(_:)` 추가: `GET /platform/v1/projects/{project_id}/email/delivery-requests/{request_id}`.
  - fractional seconds와 non-fractional RFC3339 timestamp를 모두 decode하도록 보강.
- `Sources/SpectraNotificationSDK/SpectraNotificationModels.swift`
  - `SpectraEmailDeliveryRequest`, `SpectraEmailQueuedDelivery`, `SpectraEmailDeliveryStatus`, `SpectraEmailDeliveryStatusValue` 추가.
- `Tests/SpectraNotificationSDKTests/SpectraNotificationClientTests.swift`
  - Auth token header, Project Email path, idempotency header, JSON body와 privacy-safe status decoding 회귀 테스트 추가.
- `README.md`, `HANDOFF.md`, `WORKLOG.md`
  - SDK가 SMTP를 직접 보내지 않고 Auth token provider로 Delivery Platform API를 호출하는 경계를 기록.

## 실행한 검증과 결과

- `swift test`
  - 결과: 통과, 9 tests.

## 남은 작업, 미검증 항목 또는 주의사항

- 실제 Delivery Platform API와 Auth Platform token introspection E2E는 별도 통합 환경에서 검증해야 한다.
- Spectra iOS는 기존 OIDC session을 AuthSDK token provider surface로 bridge하고 있으므로, 실제 Platform Auth app-user token producer가 준비되면 provider 구현을 교체한다.
- 보호자 인증 코드는 현재 Community Core API가 `verification_id`와 확인 상태를 소유하므로, 이 SDK email surface로 앱이 임의 코드를 생성해 보내는 방식으로 대체하지 않는다.

## 커밋 기록

- 이번 작업 완료 후 별도 커밋에 기록한다.
