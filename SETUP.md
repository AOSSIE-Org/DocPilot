# DocPilot — Contributor Setup Guide

This guide covers everything needed to get DocPilot running locally for development and testing. It includes extra detail for contributors on **Windows** and for **Android** device/emulator testing, where the setup has a few more steps than on macOS/Linux.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Flutter SDK Installation](#flutter-sdk-installation)
3. [Android Studio and SDK Setup](#android-studio-and-sdk-setup)
4. [Project Setup](#project-setup)
5. [API Keys](#api-keys)
6. [Running the App](#running-the-app)
7. [Common Issues](#common-issues)

---

## Prerequisites

| Tool | Minimum version | Notes |
|---|---|---|
| Flutter | 3.27.x (stable) | Check with `flutter --version` |
| Dart | 3.6.x | Included with Flutter |
| Android Studio | Hedgehog (2023.1) or newer | For Android SDK and AVD |
| Git | Any recent version | |
| VS Code (optional) | Any | With the Flutter + Dart extensions |

---

## Flutter SDK Installation

### Windows

1. Download the Flutter SDK zip from https://docs.flutter.dev/get-started/install/windows
2. Extract it to a path **without spaces**, e.g. `C:\dev\flutter`
3. Add `C:\dev\flutter\bin` to your `PATH` environment variable:
   - Open **System Properties** → **Environment Variables**
   - Edit the `Path` variable under **User variables**
   - Add the `bin` path and click OK
4. Open a **new** terminal and verify:
   ```
   flutter --version
   flutter doctor
   ```

### macOS / Linux

Use the official installer or `fvm` (Flutter Version Manager):
```bash
# macOS via Homebrew
brew install --cask flutter

# or via fvm
dart pub global activate fvm
fvm install stable
fvm use stable
```

Make sure to use the **stable** channel:
```bash
flutter channel stable
flutter upgrade
```

---

## Android Studio and SDK Setup

Even if you use VS Code as your editor, Android Studio is still needed to manage the Android SDK and create emulators.

1. Download and install Android Studio from https://developer.android.com/studio
2. On first launch, go through the **Setup Wizard** — it installs the default Android SDK
3. Open **SDK Manager** (Tools → SDK Manager):
   - Under **SDK Platforms**: install **Android 14 (API 34)** or newer
   - Under **SDK Tools**: make sure these are checked:
     - Android SDK Build-Tools
     - Android Emulator
     - Android SDK Platform-Tools
     - Intel HAXM *(Windows only — required for emulator acceleration)*
4. Accept all SDK licenses by running:
   ```bash
   flutter doctor --android-licenses
   ```
   Type `y` at each prompt.
5. Run `flutter doctor` again — the Android toolchain check should now pass.

### Creating a Virtual Device (Emulator)

For testing DocPilot's microphone features, a **physical Android device is strongly recommended** because microphone passthrough does not work reliably in most emulators.

To create an emulator anyway:
1. Open **Device Manager** in Android Studio (Tools → Device Manager)
2. Click **Create Virtual Device**
3. Choose a Pixel device (e.g. Pixel 6), click **Next**
4. Select a system image (API 34 recommended), download it if needed
5. Finish the wizard and start the emulator

> **Note for emulator users:** The `record` package used by DocPilot accesses the real microphone. Audio recording will not work inside an emulator unless you enable microphone passthrough in your hypervisor settings. Use a real device for end-to-end testing.

### Connecting a Physical Device (Windows)

1. Enable **Developer Options** on your phone: go to Settings → About → tap **Build Number** 7 times
2. Enable **USB Debugging** inside Developer Options
3. Connect via USB and accept the debugging prompt on the phone
4. Verify Flutter can see the device:
   ```bash
   flutter devices
   ```

---

## Project Setup

```bash
git clone https://github.com/AOSSIE-Org/DocPilot.git
cd DocPilot
flutter pub get
```

---

## API Keys

DocPilot requires two API keys. Copy the example env file and fill in your keys:

```bash
cp .env.example .env
```

Open `.env` and replace the placeholders:

```
GEMINI_API_KEY=your_gemini_api_key_here
DEEPGRAM_API_KEY=your_deepgram_api_key_here
```

**Getting a Deepgram key:**
1. Sign up at https://console.deepgram.com
2. Go to **API Keys** → **Create a new API key**
3. Copy the key into `.env`

**Getting a Gemini key:**
1. Go to https://aistudio.google.com/app/apikey
2. Click **Create API key**
3. Copy the key into `.env`

> **Important:** Never commit your `.env` file. It is listed in `.gitignore`. Only `.env.example` (with placeholder values) is tracked by git.

---

## Running the App

```bash
# List available devices
flutter devices

# Run on a connected Android device
flutter run

# Run on a specific device by ID
flutter run -d <device-id>

# Run in release mode (closer to production performance)
flutter run --release
```

To run the tests:
```bash
flutter test
```

To check for lint issues:
```bash
flutter analyze
```

---

## Common Issues

### `flutter doctor` shows Android SDK not found (Windows)
- Open Android Studio → Tools → SDK Manager and note the **Android SDK Location** path
- Run: `flutter config --android-sdk "C:\path\to\your\sdk"`

### `Unable to locate adb` or device not detected
- Make sure **Platform-Tools** is installed via SDK Manager
- Add `%LOCALAPPDATA%\Android\Sdk\platform-tools` to your `PATH` (Windows)
- Try unplugging and replugging the USB cable, and re-accepting the debug prompt

### `MissingPluginException` for microphone/record on first run
```bash
flutter clean
flutter pub get
flutter run
```

### API key errors at runtime
- Make sure `.env` exists at the project root (not inside `lib/`)
- Make sure the values are real keys, not the placeholder text from `.env.example`
- The app will show an inline banner on the main screen if it detects missing or placeholder keys

### `flutter pub get` fails behind a corporate proxy (Windows)
```bash
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PUB_HOSTED_URL=https://pub.flutter-io.cn
flutter pub get
```

### Gradle build fails with `Could not find` errors
```bash
cd android
./gradlew clean   # macOS/Linux
gradlew.bat clean # Windows
cd ..
flutter run
```
