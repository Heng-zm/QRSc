# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is a Flutter mobile application for scanning QR codes and barcodes using the device camera. It's a simple two-screen app with a welcome screen and a scanner screen that uses the device's camera with real-time scanning capabilities.

## Common Development Commands

### Dependencies and Setup
```bash
# Install Flutter dependencies
flutter pub get

# Clean build artifacts and reinstall dependencies
flutter clean && flutter pub get

# Check Flutter/project health
flutter doctor
```

### Running the Application
```bash
# Run in development mode (auto-selects connected device)
flutter run

# Run on specific platform
flutter run -d android
flutter run -d ios
flutter run -d chrome    # for web testing

# Run with hot reload enabled (default in debug mode)
flutter run --hot

# Run in release mode for performance testing
flutter run --release
```

### Building for Release
```bash
# Android APK
flutter build apk --release

# Android App Bundle (recommended for Play Store)
flutter build appbundle --release

# iOS (requires macOS and Xcode)
flutter build ios --release

# Web
flutter build web --release
```

### Testing and Quality
```bash
# Run tests (if test files exist)
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Static analysis
flutter analyze

# Format code
flutter format lib/

# Format specific file
flutter format lib/screens/scanner_screen.dart
```

### Development Tools
```bash
# List connected devices
flutter devices

# Open Flutter inspector (with app running)
flutter inspector

# Generate app icons (requires flutter_launcher_icons package)
flutter packages pub run flutter_launcher_icons:main
```

## Architecture and Code Structure

### Application Architecture
This is a simple Flutter app following a basic screen-based navigation pattern:

- **Entry Point**: `main.dart` - Sets up MaterialApp with blue theme and routes to HomeScreen
- **Navigation Flow**: HomeScreen → ScannerScreen (via Navigator.push)
- **State Management**: Uses StatefulWidget with setState for local state (scanner controls, flash toggle, scan results)

### Key Components

#### Main Application (`lib/main.dart`)
- `QRBarcodeScannerApp`: Root widget defining app theme and initial route
- Uses Material Design with primary blue color scheme
- Disables debug banner for cleaner UI

#### Home Screen (`lib/screens/home_screen.dart`)
- Welcome screen with app branding
- Single action button to navigate to scanner
- StatelessWidget - no state management needed

#### Scanner Screen (`lib/screens/scanner_screen.dart`)
- Core scanning functionality using `qr_code_scanner` package
- Manages QRViewController lifecycle with proper dispose
- Features:
  - Flash/torch toggle
  - Pause/Resume camera controls
  - Real-time scan result display
  - Custom overlay with blue border styling
- Platform-specific camera handling for Android/iOS

### Dependencies and Their Roles
- `qr_code_scanner ^1.0.1`: Core QR/barcode scanning functionality
- `permission_handler ^11.3.1`: Runtime camera permission management  
- `camera ^0.10.5+9`: Camera functionality support
- `flutter_lints ^3.0.0`: Code quality and style enforcement

### Platform-Specific Considerations

#### Android Requirements
Camera permission must be declared in `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
```

#### iOS Requirements  
Camera usage description must be added to `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>This app needs access to camera to scan QR codes and barcodes</string>
```

### State Management Pattern
The app uses Flutter's built-in state management:
- `StatelessWidget` for static screens (HomeScreen)
- `StatefulWidget` with `setState()` for interactive components (ScannerScreen)
- Local state variables: `result`, `isFlashOn`, `controller`

### Navigation Pattern
Simple imperative navigation using `Navigator.push()` with `MaterialPageRoute`. No named routes or complex routing needed for this two-screen app.

## Development Guidelines

### When Adding New Features
- Follow the existing screen-based structure in `lib/screens/`
- Use StatefulWidget for screens requiring state management
- Consider adding services in `lib/services/` for business logic
- Add custom widgets to `lib/widgets/` for reusable components

### Camera Integration Notes
- Always dispose QRViewController in dispose() method
- Handle platform differences (Android vs iOS) in reassemble()
- Use GlobalKey for QRView widget identification
- Test flash functionality on physical devices (not emulator)

### Testing Considerations
- Camera functionality requires physical devices
- Permission handling needs testing on fresh installs
- Test flash toggle on different device types
- Verify scan accuracy with various QR/barcode types

### Code Style
- Uses `flutter_lints` for consistent code style
- Key constructors follow `Key? key` pattern
- Const constructors where possible for performance
- Descriptive variable names (`isFlashOn`, `qrKey`, etc.)