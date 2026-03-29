# 🔧 FLUTTER RUN TROUBLESHOOTING GUIDE

## Quick Fixes (Try These First)

### **Step 1: Clean Build**
```bash
flutter clean
flutter pub get
flutter pub upgrade
```

### **Step 2: Check Flutter Setup**
```bash
flutter doctor -v
```
Make sure all checks pass (✓).

### **Step 3: Try Running on Device/Emulator**
```bash
# List connected devices
flutter devices

# Run on specific device
flutter run -d <device_id>
```

### **Step 4: Check for Dart Analysis Errors**
```bash
# Run full analysis
dart analyze lib/

# Or use flutter
flutter analyze lib/
```

---

## Common Issues & Solutions

### **Issue 1: Build Cache Issues**
**Symptoms**: "Build failed", "File not found", "Cache error"

**Solution**:
```bash
# Hard clean
rm -rf build/
rm -rf pubspec.lock
rm -rf .dart_tool/

# Fresh install
flutter clean
flutter pub get
flutter pub upgrade --major-versions
```

### **Issue 2: Gradle Issues (Android)**
**Symptoms**: "Gradle task assembleDebug failed"

**Solution**:
```bash
# Navigate to android directory
cd android

# Clean gradle
./gradlew clean
./gradlew build --refresh-dependencies

# Go back
cd ..

# Try running again
flutter run
```

### **Issue 3: Pod/CocoaPods Issues (iOS)**
**Symptoms**: "Pod install failed", "CocoaPods error"

**Solution**:
```bash
# Navigate to iOS
cd ios

# Clean pods
rm -rf Pods/
rm Podfile.lock

# Reinstall
pod install --repo-update
pod update

# Go back
cd ..

# Try running again
flutter run
```

### **Issue 4: SDK/Emulator Not Available**
**Symptoms**: "No devices detected", "Please start an emulator"

**Solution for Android**:
```bash
# List available emulators
emulator -list-avds

# Start emulator
emulator -avd <emulator_name>

# Or create new one
avdmanager create avd -n my_device -k "system-images;android-34;google_apis;x86_64"
emulator -avd my_device
```

**Solution for iOS**:
```bash
# List simulators
xcrun simctl list devices

# Start iOS simulator
open -a Simulator

# Then run
flutter run
```

### **Issue 5: Port Already in Use**
**Symptoms**: "Port 8888 is already in use", "Device port is in use"

**Solution**:
```bash
# Kill existing flutter processes
pkill flutter

# Or specify different port
flutter run --host-vmservice-port 8889
```

### **Issue 6: Dependency Issues**
**Symptoms**: "Package not found", "Import error", "Version conflict"

**Solution**:
```bash
# Get latest versions
flutter pub get

# Upgrade dependencies
flutter pub upgrade

# Check for issues
flutter pub outdated
```

---

## Complete Reset (Nuclear Option)

If nothing else works:

```bash
# 1. Clean everything
flutter clean
cd android && ./gradlew clean && cd ..
cd ios && rm -rf Pods/ && rm Podfile.lock && cd ..
rm -rf pubspec.lock
rm -rf .dart_tool/

# 2. Get fresh dependencies
flutter pub get
flutter pub upgrade

# 3. Rebuild iOS pods
cd ios
pod install --repo-update
pod update
cd ..

# 4. Try to run
flutter run -v
```

---

## Specific Fixes for Recent Changes

Since we just made changes to the app, make sure:

### 1. Check the files we modified compile
```bash
dart analyze lib/services/firebase/api_credentials_service.dart
dart analyze lib/services/chatbot_service.dart
dart analyze lib/services/gemini_api_diagnostic.dart
```

### 2. Check imports in main.dart
The following imports should be present:
```dart
import 'core/cache/cache_manager.dart';
import 'core/storage/local_storage_service.dart';
import 'core/providers/enhanced_connection_provider.dart';
import 'core/providers/patient_provider.dart';
import 'core/providers/clinical_notes_provider.dart';
import 'services/firebase/firebase_bootstrap_service.dart';
import 'services/firebase/notification_service.dart';
import 'theme/app_theme.dart';
import 'screens/auth/auth_gate_screen.dart';
```

### 3. Verify all providers are defined
The providers used in main.dart must exist:
- `EnhancedConnectionProvider` ✓
- `PatientProvider` ✓
- `ClinicalNotesProvider` ✓

---

## Getting Detailed Error Information

### Run with Verbose Output
```bash
flutter run -v > flutter_run.log 2>&1
cat flutter_run.log | tail -200
```

### Check Specific Errors
```bash
# For Android issues
cd android && ./gradlew tasks && cd ..

# For iOS issues
cd ios && pod update && cd ..

# For Dart issues
dart analyze lib/ --fatal-infos
```

---

## If Still Stuck

1. **Share the exact error message** from `flutter run -v`
2. **Check `flutter doctor -v`** output
3. **Verify device is connected**: `flutter devices`
4. **Try on different device/emulator**

---

## Quick Diagnostic Commands

Run these to diagnose:

```bash
# Check Flutter installation
flutter --version

# Check environment
flutter doctor -v

# List devices
flutter devices

# List emulators
emulator -list-avds
xcrun simctl list devices

# Check dependencies
flutter pub get
flutter pub check

# Analyze code
flutter analyze

# Check build
flutter build linux --profile --target lib/main.dart (dry run)
```

---

## What Specific Error Are You Seeing?

Share the error message and I'll provide the exact fix!

Common errors to look for:
- `FAILURE: Build failed with an exception`
- `Error: A value of type...`
- `File not found`
- `Permission denied`
- `Pod install failed`
- `Gradle build failed`
- `SIGSEGV`
- `Process 'command /path/to/flutter' exited with non-zero value`

