# Platform integration checklist

## iOS

1. Add the two Swift files in `ios/Runner/` to the Runner target.
2. The included `AppDelegate.swift` registers the scanner channel.
3. Add `NSCameraUsageDescription` to `Info.plist`.
4. Test VisionKit scanning on iPhone and iPad.

## Android

1. Add the two Kotlin files in `android/app/src/main/kotlin/com/esigndocpro/` to the app module.
2. The included `MainActivity.kt` registers the import channel.
3. Add camera permission and test Android 13+ document access.
4. Connect the `scanDocument` method to the selected ML Kit or CameraX scanner implementation.

The Flutter channel is already defined in `lib/services/native_document_scanner.dart`.
