Build test
# Hamza Jani - Real App (Flutter)

## What this is
Real native app - NOT browser test. Real mic, real camera, real Bluetooth, real voice via WebRTC.

## How it works
- Every phone gives signal to next phone (Bluetooth Mesh)
- Room Code links 2 phones for signaling
- Audio/Video via WebRTC (flutter_webrtc) - mic works in native app, not blocked like browser
- Messaging via mesh

## Run it
```
flutter pub get
flutter run
```

## Build for Play Store
```
flutter build appbundle --release
```
Upload `build/app/outputs/bundle/release/app-release.aab` to Google Play Console

## Build for App Store
```
flutter build ipa --release
```
Upload via Xcode to App Store Connect

## Permissions needed (already in code)
- Microphone, Camera, Bluetooth, Bluetooth Connect/Scan, Location (for Bluetooth scanning on Android)
