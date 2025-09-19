# Flutter QR & Barcode Scanner

A Flutter mobile application for scanning QR codes and barcodes using the device camera.

## Features

- 📱 Scan QR codes and barcodes
- 🔦 Toggle flashlight for better scanning in low light
- ⏸️ Pause/Resume camera functionality
- 🎨 Clean and intuitive UI
- 📋 Display scanned results

## Dependencies

This app uses the following Flutter packages:
- `qr_code_scanner` - For QR code and barcode scanning functionality
- `permission_handler` - For camera permissions
- `camera` - Camera functionality support

## Prerequisites

Before running this project, make sure you have:

1. **Flutter SDK installed** - If Flutter is not installed, follow these steps:
   
   ### Windows Installation:
   1. Download Flutter SDK from [flutter.dev](https://flutter.dev/docs/get-started/install/windows)
   2. Extract the zip file to a location like `C:\flutter`
   3. Add Flutter to your PATH environment variable: `C:\flutter\bin`
   4. Run `flutter doctor` in command prompt to verify installation

   ### Alternative: Using Chocolatey (Windows)
   ```bash
   choco install flutter
   ```

   ### macOS Installation:
   ```bash
   # Using Homebrew
   brew install --cask flutter
   ```

   ### Linux Installation:
   ```bash
   # Download and extract Flutter
   wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.x.x-stable.tar.xz
   tar xf flutter_linux_3.x.x-stable.tar.xz
   
   # Add to PATH in ~/.bashrc or ~/.zshrc
   export PATH="$PATH:`pwd`/flutter/bin"
   ```

2. **Android Studio or VS Code** with Flutter extension
3. **Android SDK** (for Android development)
4. **Xcode** (for iOS development on macOS)

## Setup Instructions

1. **Clone or navigate to the project directory:**
   ```bash
   cd ~/projects/flutter_qr_barcode_scanner
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   # For development
   flutter run
   
   # For specific platform
   flutter run -d android
   flutter run -d ios
   ```

## Android Permissions

The app requires camera permission. Make sure the following is added to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
```

## iOS Permissions

For iOS, add the following to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs access to camera to scan QR codes and barcodes</string>
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── screens/
│   ├── home_screen.dart      # Welcome screen
│   └── scanner_screen.dart   # Scanner functionality
├── widgets/                  # Custom widgets (for future use)
└── services/                 # Business logic services (for future use)
```

## Building for Release

### Android APK:
```bash
flutter build apk --release
```

### iOS:
```bash
flutter build ios --release
```

## Troubleshooting

1. **"flutter: command not found"** - Flutter is not installed or not in PATH
2. **Camera permission issues** - Check permissions in device settings
3. **Build issues** - Run `flutter clean && flutter pub get`

## Next Steps

After Flutter is installed, you can:
1. Run `flutter doctor` to check for any setup issues
2. Run `flutter pub get` to install dependencies
3. Connect a device or start an emulator
4. Run `flutter run` to launch the app

## Contributing

Feel free to contribute to this project by:
- Adding new features
- Fixing bugs
- Improving UI/UX
- Adding tests

## License

This project is open source and available under the [MIT License](LICENSE).