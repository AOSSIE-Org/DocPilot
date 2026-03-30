# Development Guide

This guide provides comprehensive information for developing DocPilot.

## Quick Start

### Prerequisites
- Flutter 3.22.0 or later
- Dart 3.6.0 or later
- Git

### Setup in 5 Minutes

```bash
# Clone repository
git clone https://github.com/AOSSIE-Org/DocPilot.git
cd DocPilot

# Install dependencies
flutter pub get
cd ios && pod install && cd ..  # macOS only

# Run the app
flutter run
```

## Project Structure

### Core Directories

**`lib/`** - Main application code
- **`main.dart`** - App initialization and routing
- **`screens/`** - UI screens (transcription, summary, prescription)
- **`features/`** - Feature modules with isolated logic
- **`services/`** - External service integrations (APIs, storage)
- **`utils/`** - Shared utilities (retry logic, networking, helpers)
- **`models/`** - Data models and domain entities
- **`widgets/`** - Reusable UI widgets

**`test/`** - Test files
- Unit tests for services
- Widget tests for screens
- Integration tests

**`docs/`** - Documentation
- Architecture guide
- Feature documentation
- API integration guides

**`.github/workflows/`** - CI/CD pipelines
- Continuous integration (testing, analysis, building)
- Continuous deployment (releases)
- PR quality checks

## Development Workflow

### 1. Creating a Feature

**Step 1: Create Feature Branch**
```bash
git checkout -b feature/your-feature-name main
```

**Step 2: Create Feature Structure**
```
lib/features/your_feature/
├── data/
│   ├── services/
│   └── models/
├── domain/
│   └── models/
└── presentation/
    ├── screens/
    ├── widgets/
    └── controllers/
```

**Step 3: Implement Feature**
- Start with domain models (entities)
- Implement services/data layer
- Create UI screens and widgets
- Add business logic controllers

**Step 4: Add Tests**
```dart
// test/features/your_feature/...
void main() {
  group('YourFeature', () {
    test('should do something', () {
      // Test implementation
    });
  });
}
```

**Step 5: Documentation**
- Update README with new feature
- Add code comments for complex logic
- Update API docs if applicable

### 2. Fixing a Bug

**Step 1: Reproduce the Bug**
- Create minimal reproduction steps
- Note error messages and stack traces
- Test on different devices/platforms if possible

**Step 2: Identify Root Cause**
- Use debugger or logging
- Review related code
- Check recent changes

**Step 3: Implement Fix**
- Make minimal, focused changes
- Add a test that reproduces the bug
- Verify test fails before fix, passes after

**Step 4: Verify Fix**
```bash
flutter clean
flutter pub get
flutter test
flutter analyze
```

### 3. Refactoring Code

**Best Practices**
- Refactor in small, incremental steps
- Keep tests passing throughout
- Don't mix refactoring with feature development
- Document any architectural changes

**Process**
```bash
# 1. Run tests before refactoring
flutter test

# 2. Make small changes
# ... refactor code ...

# 3. Run tests after each change
flutter test

# 4. Commit incremental changes
git commit -m "refactor: simplify [component] logic"
```

## Common Development Tasks

### Adding a New Service

```dart
// services/my_service.dart
import 'dart:developer' as developer;
import 'utils/retry_utility.dart';
import 'utils/network_utility.dart';

class MyService {
  final String _apiKey;
  final http.Client _httpClient;

  MyService({required String apiKey, http.Client? httpClient})
    : _apiKey = apiKey?.trim(),
      _httpClient = httpClient ?? http.Client();

  Future<String> performOperation(String input) async {
    developer.log('Starting operation', name: 'MyService');

    return await RetryUtility.execute<String>(
      () => _performRequest(input),
      config: RetryConfig.apiDefault,
      retryIf: RetryUtility.apiRetryCondition,
    );
  }

  Future<String> _performRequest(String input) async {
    // Check network connectivity
    final networkInfo = await NetworkUtility.checkConnectivity();
    if (!networkInfo.isReachable) {
      throw NetworkException('No internet connection');
    }

    // Make API call
    final response = await _httpClient.post(/* ... */);

    // Handle response
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('API error: ${response.statusCode}');
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
```

### Adding Unit Tests

```dart
// test/services/my_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([http.Client])
void main() {
  group('MyService', () {
    late MyService service;
    late MockHttpClient mockClient;

    setUp(() {
      mockClient = MockHttpClient();
      service = MyService(apiKey: 'test-key', httpClient: mockClient);
    });

    tearDown(() {
      service.dispose();
    });

    test('should return result on success', () async {
      // Arrange
      when(mockClient.post(any)).thenAnswer(
        (_) async => http.Response('success', 200),
      );

      // Act
      final result = await service.performOperation('input');

      // Assert
      expect(result, equals('success'));
    });

    test('should retry on failure', () async {
      // Arrange
      when(mockClient.post(any))
        .thenThrow(SocketException('Connection failed'))
        .thenAnswer((_) async => http.Response('success', 200));

      // Act
      final result = await service.performOperation('input');

      // Assert
      expect(result, equals('success'));
      verify(mockClient.post(any)).called(2);  // Called twice due to retry
    });
  });
}
```

### Integrating with UI

```dart
// lib/screens/my_screen.dart
import 'package:provider/provider.dart';

class MyScreen extends StatefulWidget {
  @override
  _MyScreenState createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  String _result = '';
  bool _isLoading = false;
  String _error = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Feature')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            if (_error.isNotEmpty)
              Container(
                color: Colors.red.shade100,
                padding: EdgeInsets.all(8),
                child: Text(_error, style: TextStyle(color: Colors.red)),
              ),
            if (_isLoading)
              CircularProgressIndicator()
            else if (_result.isNotEmpty)
              Text(_result)
            else
              Text('No data yet'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _performOperation,
              child: Text('Perform Operation'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performOperation() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final service = context.read<MyService>();
      final result = await service.performOperation('input');

      setState(() {
        _result = result;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
```

## Running Tests

### Unit Tests
```bash
# All tests
flutter test

# Specific test file
flutter test test/services/my_service_test.dart

# With coverage
flutter test --coverage

# Generate HTML coverage report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Widget Tests
```bash
# Run only widget tests
flutter test --tags widget

# Run with specific pattern
flutter test test/screens/
```

### Integration Tests
```bash
# Run integration tests (device required)
flutter drive --target=test_driver/app.dart
```

## Debugging

### Using Debugger

```dart
// Add breakpoint in VS Code by clicking line number
Future<void> myFunction() {
  int myVar = 5;  // Click here to set breakpoint
  print(myVar);
}
```

### Logging

```dart
import 'dart:developer' as developer;

// Log messages
developer.log('Debug message', name: 'my_service');
developer.log('Error occurred: $error', name: 'my_service');

// Use Timeline profiling
developer.Timeline.startSync('operation_name');
// ... operation ...
developer.Timeline.finishSync();
```

### Using DevTools

```bash
# Launch DevTools
flutter pub global activate devtools
devtools

# Connect running app
# Visit http://localhost:9100 in browser
```

### Common Debug Commands

```bash
# Run with verbose logging
flutter run -v

# Run with checked mode on release
flutter run -c release --debug-symbols-dir=symbols

# Attach to existing app
flutter attach

# Show build output details
flutter build apk -v
```

## Code Quality

### Static Analysis

```bash
# Run analyzer
flutter analyze

# Fix issues automatically
dart fix --apply
```

### Code Formatting

```bash
# Check formatting
dart format --set-exit-if-changed lib test

# Auto-format code
dart format lib test

# Format in VS Code
Ctrl+Shift+P → Format Document
```

### Linting

```bash
# See all linting issues
flutter analyze --fatal-warnings

# Fix common issues
dart fix --apply
```

## Performance Profiling

### Memory Profiling

```bash
# Run app with memory profiling
flutter run --profile

# Use DevTools Memory tab to:
# - Monitor memory usage
# - Detect memory leaks
# - Take heap snapshots
```

### CPU Profiling

```bash
# View CPU usage in DevTools
# Use Timeline tab to profile frame rendering
# Identify janky frames and optimize
```

### Build Performance

```bash
# Analyze build time
flutter build apk --analyze-size

# View release build size
flutter build apk --release --split-per-abi
```

## Troubleshooting

### Common Issues

**Issue: `flutter pub get` fails**
```bash
# Solution 1: Update pub cache
flutter pub cache repair

# Solution 2: Clean and retry
flutter clean
flutter pub get
```

**Issue: Build fails with pod install error**
```bash
# Solution: Reinstall pods
cd ios
rm -rf Pods
pod install
cd ..
```

**Issue: Tests fail locally but pass in CI**
```bash
# Causes:
# - Platform differences (mock behavior)
# - Environment variables not set
# - Race conditions in async code
# - File system differences

# Debug:
flutter test -v  # See detailed output
flutter test --concurrency=1  # Disable parallel execution
```

**Issue: App crashes on startup**
```bash
# Debug:
flutter run -v  # See verbose output
flutter logs    # Monitor log output
flutter attach  # Debug running app
```

## Git Workflow

### Feature Development

```bash
# Start new feature
git checkout main
git pull upstream main
git checkout -b feature/my-feature

# Make changes and commit
git add .
git commit -m "feat: add new feature description"

# Push to remote
git push -u origin feature/my-feature

# Create pull request
gh pr create --title "feat: feature title" --body "Description"
```

### Keeping Branch Updated

```bash
# Fetch latest from main
git fetch upstream main

# Rebase on main
git rebase upstream/main

# If conflicts occur, resolve them
git add resolved_file.dart
git rebase --continue
```

### Squashing Commits

```bash
# Interactive rebase
git rebase -i HEAD~3  # Last 3 commits

# In editor: change 'pick' to 'squash' for commits to merge
# Save and merge commit messages
```

## Release Process

### Creating a Release

```bash
# Update version in pubspec.yaml
# Update CHANGELOG.md
# Create version tag
git tag v1.2.0

# Push tag (triggers CD pipeline)
git push origin v1.2.0

# GitHub Actions automatically:
# 1. Builds all platforms
# 2. Generates release notes
# 3. Creates GitHub Release
# 4. Uploads artifacts
```

### Hotfix Process

```bash
# Create hotfix branch from main
git checkout -b hotfix/bug-fix main

# Fix bug and test
# Create PR with hotfix label
# Merge to main
# Tag release

git tag v1.2.1
git push origin v1.2.1
```

## Resources

### Documentation
- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Documentation](https://dart.dev)
- [Provider Package](https://pub.dev/packages/provider)
- [Mockito Package](https://pub.dev/packages/mockito)

### Tools
- [VS Code Flutter Extension](https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter)
- [Android Studio](https://developer.android.com/studio)
- [Xcode](https://developer.apple.com/xcode/)

### Learning Resources
- [Flutter Codelabs](https://flutter.dev/docs/codelabs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Architecture Patterns](https://resocoder.com/flutter-clean-architecture)

## Getting Help

- **Issues**: Check existing GitHub issues
- **Discussions**: Ask in GitHub Discussions
- **Docs**: Read project documentation
- **Code Examples**: Check `lib/examples/` directory

---

Happy coding! 🚀