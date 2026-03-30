# Contributing to DocPilot

We're thrilled that you're interested in contributing to DocPilot! This guide will help you get started with contributing to our AI-powered medical documentation assistant.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contributing Process](#contributing-process)
- [Code Standards](#code-standards)
- [Testing Guidelines](#testing-guidelines)
- [Pull Request Process](#pull-request-process)
- [Issue Guidelines](#issue-guidelines)
- [Documentation](#documentation)
- [Community](#community)

## 📜 Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

## 🚀 Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK**: Version 3.22.0 or later
- **Dart**: Version 3.6.0 or later
- **Android Studio** or **VS Code** with Flutter extensions
- **Git**: For version control
- **Java JDK**: Version 17 or later (for Android builds)
- **Xcode**: Latest version (for iOS builds, macOS only)

### Quick Start

1. **Fork the Repository**
   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/YOUR_USERNAME/DocPilot.git
   cd DocPilot
   ```

2. **Set Up Upstream Remote**
   ```bash
   git remote add upstream https://github.com/AOSSIE-Org/DocPilot.git
   ```

3. **Install Dependencies**
   ```bash
   flutter pub get
   cd ios && pod install && cd ..  # macOS only
   ```

4. **Run the App**
   ```bash
   flutter run
   ```

## 🛠️ Development Setup

### Environment Configuration

1. **Create Environment File**
   ```bash
   cp .env.example .env
   ```

2. **Configure API Keys** (Optional for basic development)
   ```env
   GEMINI_API_KEY=your_gemini_api_key_here
   DEEPGRAM_API_KEY=your_deepgram_api_key_here
   ```

3. **Verify Setup**
   ```bash
   flutter doctor
   flutter analyze
   flutter test
   ```

### IDE Setup

#### VS Code
Install these extensions:
- Flutter
- Dart
- GitLens
- Error Lens
- Bracket Pair Colorizer

#### Android Studio
- Install Flutter and Dart plugins
- Configure Flutter SDK path
- Enable Dart Analysis Server

### Build Verification

Ensure you can build for your target platforms:

```bash
# Android
flutter build apk --debug

# iOS (macOS only)
flutter build ios --debug --no-codesign

# Web
flutter build web

# Desktop (Ubuntu/macOS/Windows)
flutter build linux    # or macos/windows
```

## 🔄 Contributing Process

### 1. Find an Issue

- Browse [open issues](https://github.com/AOSSIE-Org/DocPilot/issues)
- Look for issues labeled `good first issue` for newcomers
- Check `help wanted` for areas needing assistance
- Propose new features by creating an issue first

### 2. Create a Branch

```bash
# Sync with upstream
git checkout main
git pull upstream main

# Create feature branch
git checkout -b feature/your-feature-name
```

### 3. Make Changes

- Follow our [code standards](#code-standards)
- Write tests for new functionality
- Update documentation as needed
- Keep commits focused and atomic

### 4. Test Your Changes

```bash
# Run tests
flutter test

# Run analysis
flutter analyze

# Format code
dart format lib test

# Generate mocks if needed
dart run build_runner build
```

### 5. Commit Changes

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Examples of good commit messages
git commit -m "feat: add audio transcription retry logic"
git commit -m "fix: resolve PDF generation memory leak"
git commit -m "docs: update API integration guide"
git commit -m "test: add unit tests for ChatbotService"
git commit -m "refactor: simplify network utility logic"
```

### 6. Push and Create PR

```bash
git push origin feature/your-feature-name
# Create PR via GitHub UI or gh CLI
gh pr create --title "feat: your feature title" --body "Description of changes"
```

## 📏 Code Standards

### Code Style

We follow [Dart's official style guide](https://dart.dev/guides/language/effective-dart).

#### Formatting
- Use `dart format` to format your code
- Line length: 80 characters (flexible for readability)
- Use trailing commas for better diffs

#### Naming Conventions
```dart
// Classes: PascalCase
class ChatbotService {}

// Variables and functions: camelCase
String userInput;
void processResponse() {}

// Constants: camelCase with const
const int maxRetries = 3;

// Files: snake_case
chat_service.dart
network_utility.dart
```

#### Code Organization
```dart
// Import order: dart, flutter, packages, local
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../utils/network_utility.dart';
import 'base_service.dart';
```

### Architecture Patterns

#### Service Layer
```dart
class ApiService {
  // Private fields with underscore
  final String _apiKey;
  final http.Client _httpClient;

  // Constructor with named parameters
  ApiService({
    required String apiKey,
    http.Client? httpClient,
  }) : _apiKey = apiKey,
       _httpClient = httpClient ?? http.Client();

  // Public methods with clear documentation
  /// Processes user input and returns AI response
  ///
  /// [input] The user's text input
  /// Returns processed response or error message
  Future<String> processInput(String input) async {
    // Implementation
  }

  // Dispose resources
  void dispose() {
    _httpClient.close();
  }
}
```

#### Error Handling
```dart
// Use specific exception types
class ValidationException implements Exception {
  final String message;
  const ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}

// Handle errors gracefully
try {
  final result = await service.operation();
  return result;
} on ValidationException catch (e) {
  return 'Invalid input: ${e.message}';
} on NetworkException catch (e) {
  return 'Connection error: ${e.message}';
} catch (e) {
  return 'Unexpected error: $e';
}
```

#### State Management
- Use `provider` for dependency injection
- Keep state classes simple and focused
- Use `changeNotifier` for reactive state updates

### Documentation

#### Code Comments
```dart
/// Service for handling AI chat interactions
///
/// This service manages communication with the Gemini API,
/// including retry logic and error handling.
class ChatService {
  /// Creates a new chat service with the given [apiKey]
  ///
  /// Optionally accepts a custom [httpClient] for testing
  ChatService({required String apiKey, http.Client? httpClient});

  /// Sends a message to the AI and returns the response
  ///
  /// [message] The user's message to process
  ///
  /// Throws [ValidationException] if message is empty
  /// Throws [NetworkException] if connection fails
  ///
  /// Returns AI response or user-friendly error message
  Future<String> sendMessage(String message) async {
    // Implementation
  }
}
```

#### README Updates
When adding features, update relevant sections:
- Features list
- Installation instructions
- Usage examples
- API documentation

## 🧪 Testing Guidelines

### Test Structure

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('ChatService', () {
    late ChatService chatService;

    setUp(() {
      chatService = ChatService(apiKey: 'test-key');
    });

    tearDown(() {
      chatService.dispose();
    });

    group('sendMessage', () {
      test('should return response for valid input', () async {
        // Arrange
        const input = 'Hello, AI!';

        // Act
        final result = await chatService.sendMessage(input);

        // Assert
        expect(result, isNotEmpty);
        expect(result, isNot(startsWith('Error:')));
      });

      test('should handle empty input gracefully', () async {
        // Arrange
        const input = '';

        // Act
        final result = await chatService.sendMessage(input);

        // Assert
        expect(result, startsWith('Error:'));
      });
    });
  });
}
```

### Test Categories

#### Unit Tests
- Test individual functions and methods
- Mock external dependencies
- Cover edge cases and error conditions
- Aim for >90% code coverage

#### Widget Tests
- Test UI components in isolation
- Verify user interactions
- Test state changes and rebuilds

#### Integration Tests
- Test complete user workflows
- Verify service integrations
- Test with real network calls (sparingly)

### Running Tests

```bash
# All tests
flutter test

# Specific test file
flutter test test/services/chat_service_test.dart

# With coverage
flutter test --coverage

# Generate coverage report
genhtml coverage/lcov.info -o coverage/html
```

## 🔍 Pull Request Process

### Before Creating a PR

✅ **Pre-flight Checklist:**
- [ ] Code follows style guidelines
- [ ] All tests pass locally
- [ ] New tests cover your changes
- [ ] Documentation is updated
- [ ] No new warnings from `flutter analyze`
- [ ] Commits follow conventional format

### PR Requirements

#### Title Format
Use [Conventional Commits](https://www.conventionalcommits.org/):
- `feat: add voice transcription feature`
- `fix: resolve API timeout issue`
- `docs: update installation guide`
- `test: add integration tests for auth`

#### Description Template
```markdown
## Description
Brief description of changes and motivation.

## Type of Change
- [ ] 🐛 Bug fix (non-breaking change which fixes an issue)
- [ ] ✨ New feature (non-breaking change which adds functionality)
- [ ] 💥 Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] 📚 Documentation (changes to documentation)
- [ ] 🧪 Tests (add missing tests or update existing ones)
- [ ] 🔧 Refactor (code change that doesn't add features or fix bugs)

## Testing
- [ ] Unit tests pass
- [ ] Widget tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Screenshots/Videos
If applicable, add screenshots or videos to help explain your changes.

## Checklist
- [ ] My code follows the style guidelines
- [ ] I have performed a self-review
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
```

### Review Process

1. **Automated Checks**
   - CI/CD pipeline runs automatically
   - Code quality gate must pass
   - All tests must pass

2. **Code Review**
   - At least one maintainer review required
   - Address feedback promptly
   - Keep discussions constructive

3. **Testing**
   - Manual testing by reviewers
   - Regression testing for critical changes
   - Performance impact assessment

## 🐛 Issue Guidelines

### Creating Issues

#### Bug Reports
```markdown
**Bug Description**
A clear description of what the bug is.

**Steps to Reproduce**
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected Behavior**
What you expected to happen.

**Actual Behavior**
What actually happened.

**Screenshots**
If applicable, add screenshots.

**Environment**
- Device: [e.g. iPhone 12, Pixel 6]
- OS: [e.g. iOS 15.0, Android 12]
- App Version: [e.g. 1.2.0]
- Flutter Version: [e.g. 3.22.0]

**Additional Context**
Any other context about the problem.
```

#### Feature Requests
```markdown
**Feature Description**
A clear description of what you want to happen.

**Problem Statement**
Explain the problem this feature would solve.

**Proposed Solution**
Describe the solution you'd like.

**Alternatives Considered**
Describe alternatives you've considered.

**Additional Context**
Any other context or screenshots.
```

### Issue Labels

- `bug` - Something isn't working
- `enhancement` - New feature or request
- `documentation` - Improvements or additions to documentation
- `good first issue` - Good for newcomers
- `help wanted` - Extra attention is needed
- `priority: high` - High priority issue
- `priority: low` - Low priority issue
- `wontfix` - This will not be worked on

## 📚 Documentation

### Types of Documentation

#### Code Documentation
- Inline comments for complex logic
- Class and method documentation
- API documentation
- Architecture decisions (ADRs)

#### User Documentation
- Installation guides
- Feature usage guides
- Troubleshooting guides
- FAQ

#### Developer Documentation
- Contributing guidelines (this file)
- Development setup
- Testing procedures
- Deployment process

### Documentation Standards

#### Markdown Style
- Use clear, descriptive headings
- Include table of contents for long documents
- Use code blocks with language specification
- Include screenshots for UI-related docs

#### Code Examples
```dart
// ✅ Good: Clear, commented example
/// Example of using the ChatService
Future<void> exampleUsage() async {
  // Initialize service with API key
  final chatService = ChatService(apiKey: 'your-api-key');

  try {
    // Send message and handle response
    final response = await chatService.sendMessage('Hello AI');
    print('Response: $response');
  } catch (e) {
    print('Error: $e');
  } finally {
    // Always dispose of resources
    chatService.dispose();
  }
}
```

#### API Documentation
Use comprehensive dartdoc comments:

```dart
/// Manages AI chat interactions with retry logic and error handling
///
/// This service provides a high-level interface for communicating with
/// AI services while handling network issues, rate limiting, and errors.
///
/// Example usage:
/// ```dart
/// final service = ChatService(apiKey: 'your-key');
/// final response = await service.sendMessage('Hello');
/// ```
class ChatService {
  /// Creates a chat service with the specified [apiKey]
  ///
  /// The [httpClient] parameter is optional and mainly used for testing.
  /// If not provided, a default HTTP client will be used.
  ///
  /// Throws [ArgumentError] if [apiKey] is empty.
  ChatService({
    required String apiKey,
    http.Client? httpClient,
  });
}
```

## 🌟 Community

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and ideas
- **Discord**: Real-time chat and collaboration
- **Email**: maintainers@docpilot.app

### Getting Help

1. **Search Existing Issues**: Others might have had the same question
2. **Check Documentation**: README, wiki, and docs/ folder
3. **Ask in Discussions**: For general questions
4. **Create an Issue**: For bugs or feature requests

### Recognition

We believe in recognizing our contributors:

- **Contributors**: Listed in our README
- **Special Recognition**: For significant contributions
- **Maintainer Status**: For consistent, quality contributions

## 🎯 Areas for Contribution

### High-Priority Areas
- 🧪 **Testing**: Increase test coverage
- 🔧 **Performance**: Optimize app performance
- 🌐 **Accessibility**: Improve accessibility features
- 📱 **Platform Support**: iOS/Android improvements
- 🎨 **UI/UX**: Enhance user interface

### Beginner-Friendly Areas
- 📚 **Documentation**: Improve guides and examples
- 🐛 **Bug Fixes**: Fix small, well-defined bugs
- 🎨 **Styling**: Improve UI consistency
- 🧹 **Code Cleanup**: Refactor and improve code quality

### Advanced Areas
- 🏗️ **Architecture**: Improve app architecture
- 🔒 **Security**: Enhance security measures
- ⚡ **Performance**: Advanced optimizations
- 🚀 **DevOps**: Improve CI/CD pipeline

## ❓ Frequently Asked Questions

### General

**Q: How long does review take?**
A: Typically 1-3 days for small changes, up to a week for larger features.

**Q: Can I work on multiple issues?**
A: Yes, but please update the issues to avoid duplication of effort.

**Q: How do I become a maintainer?**
A: Consistent, quality contributions over time. Reach out to current maintainers.

### Technical

**Q: Which Flutter version should I use?**
A: Use Flutter 3.22.0 or later. Check `.fvmrc` for the exact version.

**Q: How do I run tests locally?**
A: Use `flutter test` for unit/widget tests, see testing section above.

**Q: Where should I put new features?**
A: Follow the existing folder structure in `lib/`. Ask if unsure.

### Process

**Q: Should I create an issue before starting work?**
A: Yes, especially for new features. This helps avoid duplicate work.

**Q: Can I change the commit history?**
A: Yes, please clean up your commits before submitting PR.

**Q: What if tests fail in CI but pass locally?**
A: Check for environment differences, missing dependencies, or race conditions.

---

Thank you for contributing to DocPilot! Your efforts help make medical documentation more accessible and efficient for healthcare professionals worldwide. 🏥✨