# Service Tests Documentation

This directory contains comprehensive unit tests for all the service classes in the DocPilot application.

## Test Structure

### Services Tested

1. **ChatbotService** - Tests for Gemini AI integration
2. **DeepgramService** - Tests for audio transcription service
3. **GeminiService** - Tests for medical text processing
4. **PdfService** - Tests for PDF document generation
5. **PdfSettingsService** - Tests for settings persistence

### Models Tested

1. **DoctorInfo** - Tests for doctor information model
2. **ClinicInfo** - Tests for clinic information model
3. **PdfTemplate** - Tests for PDF template configuration model

## Test Categories

Each service test file includes the following test categories:

### 1. Constructor Tests
- Validates proper initialization
- Tests parameter handling
- Verifies default values

### 2. Core Functionality Tests
- Tests main service methods
- Validates input/output behavior
- Tests edge cases and boundary conditions

### 3. Error Handling Tests
- Network error scenarios
- Invalid input handling
- Exception propagation
- Graceful degradation

### 4. JSON Serialization Tests (for models)
- roundtrip serialization integrity
- Null value handling
- Missing field scenarios
- Type safety validation

### 5. Integration Tests
- Multi-service interactions
- Concurrent operation safety
- State management verification

## Test Coverage Areas

### API Integration Tests
- **ChatbotService**: Gemini API request formatting, response parsing, error handling
- **DeepgramService**: Audio file processing, transcription accuracy, timeout handling

### Data Persistence Tests
- **PdfSettingsService**: SharedPreferences integration, data integrity, error recovery

### Document Generation Tests
- **PdfService**: Markdown parsing, PDF structure, file operations

### Business Logic Tests
- **GeminiService**: Medical text processing, prompt formatting, workflow integration

## Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/chatbot_service_test.dart

# Run tests with coverage
flutter test --coverage

# Generate test reports
genhtml coverage/lcov.info -o coverage/html
```

## Mock Usage

Tests use the `mockito` package for mocking external dependencies:

- **HTTP requests**: Mocked using `http.Client`
- **File operations**: Mocked using `File` and `Directory`
- **SharedPreferences**: Mocked for settings persistence tests

## Test Naming Convention

Tests follow the pattern:
```dart
group('ServiceName', () {
  group('methodName', () {
    test('should [expected behavior] when [condition]', () {
      // Test implementation
    });
  });
});
```

## Key Testing Principles

1. **Isolation**: Each test is independent and doesn't rely on external state
2. **Deterministic**: Tests produce consistent results across runs
3. **Comprehensive**: Cover happy paths, edge cases, and error scenarios
4. **Fast**: Tests execute quickly without real network/file operations
5. **Readable**: Clear test descriptions and well-organized code

## Test Data

Test data is kept minimal and focused:
- Use const values for predictable inputs
- Generate dynamic data only when testing edge cases
- Keep test data realistic but not sensitive

## Error Testing Strategy

1. **Network Errors**: Simulate connection failures, timeouts, HTTP errors
2. **Data Errors**: Test malformed JSON, missing fields, type mismatches
3. **File Errors**: Test missing files, permission issues, disk space
4. **API Errors**: Test rate limits, invalid keys, service unavailability

## Continuous Integration

These tests are designed to run in CI/CD pipelines:
- No external dependencies
- No file system requirements
- No network access needed
- Fast execution (< 60 seconds total)

## Maintenance

- Update tests when service interfaces change
- Add tests for new error scenarios discovered in production
- Regularly review test coverage to ensure comprehensive protection
- Keep mocks updated with real API changes

## Test Quality Metrics

- **Coverage**: Aim for >90% code coverage
- **Assertions**: Each test should have clear, specific assertions
- **Independence**: Tests should pass when run in any order
- **Reliability**: Tests should have <0.1% flake rate