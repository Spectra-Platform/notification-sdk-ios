# HANDOFF — notification-sdk-ios

## Purpose and ownership

`notification-sdk-ios` is the iOS client SDK for Spectra Platform Push. It is
owned by `50 Spectra — 인증·알림 개발자` until the app-facing package surface is
stable enough for `20 Spectra — 앱 개발자` to integrate into Spectra iOS.

## Confirmed decisions

- The app must not embed Project API tokens.
- The SDK accepts a token provider protocol so AuthSDK can supply short-lived
  access tokens later without creating a hard package dependency in this first
  slice.
- Device registration uses the current Delivery Platform contract:
  `PUT /platform/v1/projects/{project_id}/notification/devices/{device_id}`.
- Test push uses device-bound enqueue:
  `POST /platform/v1/projects/{project_id}/notification/delivery-requests`.
- Dynamic notification sound sync uses:
  - `GET /platform/v1/projects/{project_id}/notification/devices/{device_id}/sound-manifest`
  - `PUT /platform/v1/projects/{project_id}/notification/devices/{device_id}/sound-installations`
- Sound binary download and `Library/Sounds` persistence are not implemented in
  this package yet; the existing `spectra-ios` manager remains the implementation
  reference for that behavior.

## Current implementation boundary

- Local Swift Package only.
- Unit tests use `URLProtocol` mock; no real network, APNs, simulator or device
  E2E is performed.
- GitHub remote is configured as `https://github.com/Spectra-Platform/notification-sdk-ios.git`.
- Local `main` tracks `origin/main`.

## Next checks before integration

1. Add an AuthSDK adapter for `SpectraAccessTokenProviding`.
2. Extract the already implemented Spectra iOS dynamic sound downloader into
   this SDK, preserving checksum, format, duration and bundled fallback guards.
3. Integrate this local package into `spectra-ios` and run simulator/real device
   tests only after user confirmation.

Last code comparison: 2026-07-24.
