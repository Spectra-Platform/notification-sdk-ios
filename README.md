# Spectra Notification SDK for iOS

Local Swift Package for Spectra Platform Push/Notification integration.

Implemented first slice:

- Project-token based device registration
- Device deactivation
- Test push delivery request
- Future-facing dynamic notification sound manifest/reporting surface

The SDK does not persist downloaded sound files yet. iOS `Library/Sounds`
download and checksum management remains a later implementation slice.
