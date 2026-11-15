# LY Homes

Room-based Flutter home controls, redesigned for clear reading and everyday ease.

## Run

Use Flutter 3.35 or newer with Dart 3.9.2 or newer:

```sh
flutter pub get
flutter run
```

Normal mode uses the repository’s existing Firebase configuration and Firestore schema. No production data migration is required. Favourites add an optional `isFavorite` boolean to device documents (missing means false); existing Firestore rules must allow this field.

## Explore without hardware

```sh
flutter run -d chrome --dart-define=PREVIEW=true
```

Preview mode skips Firebase initialization and uses a clearly labelled in-memory sample home. Commands, room edits and favourites affect sample data only; reloading resets them. Controller setup is informational in preview mode; it does not call real hardware. Build a static preview with:

```sh
flutter build web --dart-define=PREVIEW=true
python3 -m http.server 8741 --directory build/web
```

## What changed

- Warm cream and forest-green Material 3 theme, bundled Atkinson Hyperlegible fonts (license in `assets/fonts/OFL.txt`), and a persisted dark appearance option.
- Home opens first. Favourites provide one-tap control; rooms, current issues and settings have separate navigation destinations.
- Large, labelled device controls with subtle state transitions, haptic feedback, duplicate-command protection, pending and retry states.
- Controller status refreshes every ten seconds; rooms without a heartbeat for thirty seconds are unavailable. A missing timestamp is labelled unknown.
- Existing room and device add, rename and remove flows remain connected to Firestore. Destructive actions require confirmation. Errors use plain language.
- Persistent larger-text and reduced-motion settings; the system’s text scale and reduced-motion preference are respected.
- Wi-Fi setup retains its scan/connect/reset APIs, gains clearer copy, and avoids updates after leaving the screen. Android release internet access and cleartext exceptions are scoped to the existing local controller addresses.

## Honest status and remaining product work

The existing device schema has `isOn` but no command ID, controller acknowledgement, reported relay state or sensor verification. The UI therefore says **Last set to On/Off** and **Saving command**, never claims physical operation. The five-second timeout is for saving the Firestore command, not a controller acknowledgement. A timed-out write may still complete later.

Alerts shows current controller issues; it does not invent alert history. Speech, language selection, Android Quick Settings tiles, notification controls, role-based administration, sensor verification and pairing workflows from the broader UI specification are not implemented in this UI refresh. The original Wi-Fi reset address remains `192.168.10.11`; make that configurable before supporting controllers on other addresses.

The supplied UI spec was readable. The PRD attachment path was unavailable during implementation, so this work does not claim a complete PRD audit.

## Verify

```sh
flutter analyze
flutter test
flutter build web --dart-define=PREVIEW=true
```

Tests cover duplicate-command blocking and timeout feedback, unavailable devices, navigation from current issues to a room, mobile layouts at 200% text in dark mode, and display preference persistence. Real hardware commands, native Android builds and production Firestore rules require testing against your environment.
