# Women Safety App (Flutter)

A Flutter app matching the feature spec:

| Feature | What it does |
|---|---|
| **Login** | Simple phone/password login screen, session persisted locally |
| **Home** | Big SOS button + quick-access cards to every feature |
| **SOS** | One-tap emergency alert: grabs live GPS location and sends it via SMS to all trusted contacts |
| **Live Tracking** | Streams the user's live coordinates and lets them open/share their position on Google Maps |
| **Emergency Contacts** | Add / edit / delete trusted contacts, call them directly |
| **Profile** | Name, phone, blood group, logout |

## Project structure
```
lib/
  main.dart                  # entry point, routes to Login or Home based on session
  theme.dart                 # colors & Material theme
  models/
    emergency_contact.dart
  services/
    storage_service.dart     # SharedPreferences persistence (contacts, profile, session)
    location_service.dart    # geolocator wrapper (permissions + current/live position)
    sos_service.dart         # builds SOS message + opens SMS/phone app
  screens/
    login_screen.dart
    home_screen.dart
    sos_screen.dart
    tracking_screen.dart
    contacts_screen.dart
    profile_screen.dart
pubspec.yaml
```

## Getting started

1. **Install Flutter** (if you haven't): https://docs.flutter.dev/get-started/install
2. **Create/copy the project**, then install dependencies:
   ```bash
   flutter pub get
   ```
3. **Run it**:
   ```bash
   flutter run
   ```

## Required native permissions

### Android — `android/app/src/main/AndroidManifest.xml`
Add inside `<manifest>`, before `<application>`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.SEND_SMS"/>
<uses-permission android:name="android.permission.CALL_PHONE"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

### iOS — `ios/Runner/Info.plist`
Add these keys:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to send it to your emergency contacts during an SOS.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need your location to send it to your emergency contacts during an SOS.</string>
```

## How the SOS flow works
1. User taps the SOS button on Home or the dedicated SOS screen.
2. `LocationService` fetches the current GPS position (requesting permission if needed).
3. `SosService` builds a message containing a Google Maps link to that position.
4. The device's native SMS app opens, pre-addressed to every saved emergency contact, with the message pre-filled — the user just taps send (this keeps it free, and avoids needing a paid SMS gateway or backend server).

## Notes & next steps for production
- **Login** here is a local-only placeholder. Swap in real authentication (Firebase Auth, or your own backend) before shipping.
- **Auto-send SMS** without the user tapping "send" requires either a native platform channel (Android `SmsManager`) or a backend + Twilio-style SMS API — the `sms:` URL scheme used here always opens the messaging app for the user to confirm, which is the safest cross-platform default.
- **Live Tracking** currently shows raw coordinates + a "open in Maps" link. For an in-app map view, add `google_maps_flutter` and feed it the same `LocationService.watchLocation()` stream as a marker.
- Consider adding: shake-to-SOS gesture, a countdown/cancel timer before sending (to avoid accidental alerts), and background location sharing during an active emergency.
