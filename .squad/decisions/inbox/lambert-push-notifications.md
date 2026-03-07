# Decision: Push Notification Infrastructure

**Author:** Lambert (Networking)
**Date:** 2026-07-17
**Status:** Implemented (client-side); backend endpoint pending

## Context
Push notifications are needed for the iOS app to alert users about print job completions, failures, and other events without requiring the app to be open.

## Decision

### Architecture
- **PushNotificationManager** is a `@MainActor @Observable` singleton (`PushNotificationManager.shared`) that owns all APNs lifecycle.
- **AppDelegate** adapter handles system callbacks and forwards to PushNotificationManager.
- **NotificationService** (existing actor) extended with `registerDeviceToken` / `unregisterDeviceToken` methods.

### Backend Endpoint (Placeholder)
- The backend (`NotificationsController.cs`) has an `EnablePushNotifications` preference flag but **no device token registration endpoint**.
- Client uses placeholder paths: `POST /api/notifications/device-token` (register) and `DELETE /api/notifications/device-token/{token}` (unregister).
- **Action needed from Dallas:** Add device token registration endpoint to the backend. Suggested DTO: `{ token: string, platform: "ios" | "android" }`.

### Deep-Link Hook
- Tapped notifications post `Notification.Name.pushNotificationTapped` with the push payload's `userInfo`.
- **Ripley** can observe this in `AppRouter` to navigate to the relevant printer/job detail screen.

## Impact
- **Ripley:** SettingsView now has a push notification toggle. Deep-link notification available for navigation wiring.
- **Dallas:** Backend needs a device token registration endpoint (suggested path above).
- **Ash:** MockNotificationService updated with new protocol methods; existing tests unaffected.

## Files Changed
- `PrintFarmer/Services/PushNotificationManager.swift` (new)
- `PrintFarmer/App/AppDelegate.swift` (new)
- `PrintFarmer/Services/NotificationService.swift` (extended)
- `PrintFarmer/Services/APIClient.swift` (new `postVoid` overload)
- `PrintFarmer/Protocols/NotificationServiceProtocol.swift` (extended)
- `PrintFarmer/Models/RequestModels.swift` (new `DeviceTokenRegistration` DTO)
- `PrintFarmer/PFarmApp.swift` (AppDelegate adaptor + push config)
- `PrintFarmer/Views/Settings/SettingsView.swift` (notification toggle)
- `PrintFarmerTests/Mocks/MockNotificationService.swift` (new mock methods)
