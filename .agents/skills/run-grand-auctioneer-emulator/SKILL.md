---
name: run-grand-auctioneer-emulator
description: Build the Grand Auctioneer Flutter Android debug APK and install or launch it on a connected Android emulator. Use when the user asks to see, run, install, or debug-launch this app in the emulator.
---

# Run Grand Auctioneer on the Android Emulator

## Workflow

Run commands from the repository root.

1. Check the connected Android device:

   ```powershell
   flutter devices
   adb devices
   ```

   Use the emulator/device ID reported by these commands. Do not assume a previous ID is still valid.

2. Ensure Flutter, Android SDK, and Java are available. This workspace has used:

   ```powershell
   $env:PATH = "C:\src\flutter\bin;C:\Android\platform-tools;" + $env:PATH
   $env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.21.9-hotspot'
   $env:PATH = "$env:JAVA_HOME\bin;" + $env:PATH
   ```

   Confirm paths exist before setting them. If `JAVA_HOME` points to a missing directory, locate an installed JDK 17 and set it for the current shell only. Do not overwrite machine-wide environment configuration.

3. Resolve dependencies and build:

   ```powershell
   flutter pub get
   flutter build apk --debug
   ```

   The output should be `build\app\outputs\flutter-apk\app-debug.apk`.

4. Install and launch on the selected device:

   ```powershell
   flutter install -d <device-id>
   flutter run -d <device-id>
   ```

   `flutter run` installs if needed and opens the app with attached logs. To install the built APK without Flutter, use:

   ```powershell
   adb -s <device-id> install -r build\app\outputs\flutter-apk\app-debug.apk
   ```

   Launch the app from the emulator's app drawer if it was installed with `flutter install` or `adb install`.

5. If requested, copy a successful APK to the ignored test artifact path:

   ```powershell
   New-Item -ItemType Directory -Force tests-apks | Out-Null
   Copy-Item build\app\outputs\flutter-apk\app-debug.apk tests-apks\auction_empire-debug.apk -Force
   ```

   Verify the file exists and has nonzero size. Do not claim the APK is ready unless the build succeeds.

## Known project-specific build issues

- `android/app/src/main/AndroidManifest.xml` already contains the required `flutterEmbedding` metadata with value `2`. Check it before editing; do not duplicate the entry.
- The Windows checkout path may contain non-ASCII characters. If Gradle specifically rejects the path, temporarily add `android.overridePathCheck=true` to `android/gradle.properties` for the build, then remove that temporary line. Do not otherwise rewrite Android Gradle configuration.
- The previously observed `google_mobile_ads` 5.3.1 Gradle script failed at `configurations.all` under this project's Gradle 9.5 / Android Gradle Plugin 9.3.1 setup. If this persists, report the incompatible dependency/toolchain and inspect supported versions before changing package or Gradle versions. Do not patch Pub cache contents.
- `flutter pub get` may report that `synthetic-package` in `l10n.yaml` is obsolete. Treat this as a warning unless localization generation fails; avoid unrelated config changes.

## Report

State whether the build succeeded, which device ID was used, whether installation/launch succeeded, the APK path if present, and any blocking error. Keep user changes intact and inspect `git status` before finishing.
