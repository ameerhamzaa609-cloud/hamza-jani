# Hamza Jani

Hamza Jani is a Flutter Android messaging and calling app backed by Firebase.

## Current app capabilities

- Phone-number authentication through Firebase Authentication.
- User profiles and phone-number discoverability settings.
- One-to-one text messaging with image and video attachments.
- Text and photo status posts with a 24-hour expiry timestamp.
- One-to-one voice/video call signaling and media through WebRTC.

## Calling requirements and limitations

- Calls currently use Google's public STUN server when no TURN endpoint is configured.
- STUN-only calls can work on some networks, but may fail on restrictive mobile or Wi-Fi networks.
- To improve reliability, configure the Cloudflare TURN Worker and provide its URL at build time using `TURN_CONFIG_URL`. Do not put TURN API secrets in the app.
- Incoming call handling while the app is backgrounded or closed needs end-to-end testing and a correctly configured server-side push sender.
- Group calls are not implemented yet.

## Authentication notes

Firebase test phone numbers can be used for development without sending an SMS. Real SMS delivery depends on Firebase phone-auth configuration, region policy, quotas, and any billing requirements shown by Firebase.

## Build

Install Flutter and Android SDK, then run:

```sh
flutter pub get
flutter run
```

Build an Android APK:

```sh
flutter build apk --release
```

Build an Android App Bundle for Google Play:

```sh
flutter build appbundle --release
```

## Security

Firestore rules are in `firestore.rules`. They are exercised by the emulator tests under `tools/firestore_rules_tests`. Passing those tests does not automatically deploy the rules to the production Firebase project.
