# SafeHer

A personal safety app built with Flutter. It works without a backend or a paid
SMS gateway: everything runs on the phone, using GPS and the SIM's own SMS.

## Features

| Feature | What it does |
|---|---|
| **SOS** | Press and hold, or shake. After a cancellable countdown, your location goes to every trusted contact by SMS, with no further taps on Android |
| **Honest status** | Shows per contact whether the network accepted the alert, with retry. Never says "sent" unless it was |
| **Live updates** | While an SOS runs, location updates continue by SMS with the screen off, until you hold "I'm safe", which also tells your contacts |
| **Safe Walk** | Set a time for a journey. Miss it, ignore the loud check-in, and the SOS fires by itself and says where you were going |
| **Fake Call** | A realistic incoming call to help you leave an uncomfortable situation |
| **Siren** | Loud alarm on the alarm stream. Off by default, because it isn't safe in every situation |
| **Live Location** | In-app OpenStreetMap view, with sharing through any app |
| **Safety Check** | Shows what an SOS needs (contacts, permissions, GPS) and fixes each gap |
| **Contacts** | Add, edit, remove, call, and send a test alert |
| **Helplines** | One-tap Indian national helplines |
| **History** | On-device log of past alerts |
| **Safety Tips**, dark mode, screen reader support | |

## How the SOS works

`EmergencyController` is the core of the app, and follows two rules: nothing may
stop the alert going out, and the status shown is what actually happened.

1. Hold the button (or shake) to start the countdown. Cancelling sends nothing.
2. It tries for a fresh GPS fix for up to 8 seconds, then falls back to the last
   known position (labelled as such), and then to no position at all. A missing
   fix never blocks the alert. When a real fix arrives, a follow-up goes out.
3. Each contact is sent to concurrently and retried up to twice, so one bad
   number can't delay the others.
4. On Android the SMS goes straight out through `SmsManager`
   (`MainActivity.kt`), and only counts as sent once the radio reports success.
   Without the SMS permission, and always on iOS (which doesn't allow it), the
   messaging app opens pre-filled and the screen says the user must press send.
5. Failed alerts retry every 30 seconds for as long as the SOS runs, because
   lost signal is often temporary and the user may not be able to tap Retry.
6. Updates keep going with the phone locked or the app swiped away. On Android,
   `SafetyForegroundService` keeps the process alive and `MainActivity` keeps one
   Flutter engine for the life of the process, so Dart outlives the screen.
7. If the process is killed anyway, or the phone restarts, the SOS resumes on
   next launch without alerting everyone again.

## Project structure

```
lib/
  main.dart                     entry point, shows SOS screens above every route
  theme.dart                    colors, light & dark themes
  models/                       contacts, incidents, settings, location fixes
  services/
    emergency_controller.dart   the SOS state machine
    safe_walk_controller.dart   the Safe Walk dead-man's switch
    sms_service.dart            direct SMS and composer fallback
    location_service.dart       GPS, permissions, background location
    shake_service.dart          shake detection
    readiness_service.dart      checks that an SOS would work
    sos_service.dart            the text of every message
    auth_service.dart           local account, PBKDF2 password hash
    siren_service.dart          alarm-stream audio
    storage_service.dart        SharedPreferences persistence
  screens/                      one file per screen
  widgets/                      hold-to-confirm button, live map
android/app/src/main/kotlin/    native SMS sender and foreground service
assets/audio/                   siren and ringtone
test/                           unit and widget tests
```

## Running it

```bash
flutter pub get
flutter test
flutter run
```

## Building for Android and iOS

- **Android:** run `flutter build apk --release` on any PC.
- **iOS:** this needs a Mac. `.github/workflows/build.yml` builds both platforms
  on GitHub, and its iOS result is unsigned. To install on an iPhone, open
  `ios/Runner.xcworkspace` in Xcode on a Mac, set your Team and a unique bundle
  ID under Signing & Capabilities, then run it on the phone. A free Apple ID
  works for your own phone, with the app expiring after 7 days. Sharing it needs
  the $99 per year Apple Developer Program.

## Limits to know about

- **Automatic SMS is Android only.** iOS requires the user to press send.
- **Google Play restricts `SEND_SMS`.** Publishing needs a permissions
  declaration, which Google may refuse. Installing the APK directly is unaffected.
- **Before a store release:** change the `com.example` application ID, set up
  release signing, and move off the public OpenStreetMap tile server, whose usage
  policy doesn't allow heavy production traffic.
- **Contacts get snapshots, not a live map.** Following a moving position
  remotely needs a server, so contacts get a link in each SMS update.
- **Background running isn't guaranteed everywhere.** Some manufacturers' battery
  savers kill foreground services, so test on your phone, and exempt the app from
  battery optimisation. A phone restart ends protection until the app is reopened.
- **Background protection needs location permission.** Android refuses this kind
  of service without it.
- **Login is local.** It keeps casual users out of the app, but the account only
  exists on the phone.
- **Emergency SMS needs mobile signal.** The app can't help with no coverage.
- SafeHer is a tool to help alert people you trust. It doesn't replace emergency
  services.
