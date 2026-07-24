# Spectra Notification SDK for iOS

Local Swift Package for Spectra Platform Push/Notification integration.

For app integration, use [iOS NotificationSDK integration guide](docs/guides/ios-notification-sdk-integration.md).

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
