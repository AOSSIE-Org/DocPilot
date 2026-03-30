# DocPilot Architecture

## Overview

DocPilot is built using Flutter with a layered architecture that separates concerns and promotes maintainability, testability, and scalability.

## Architecture Layers

```
┌─────────────────────────────────────┐
│         UI/Presentation Layer       │    Screens, Widgets, State Management
├─────────────────────────────────────┤
│       Business Logic Layer          │    Controllers, ViewModels, Use Cases
├─────────────────────────────────────┤
│         Service Layer               │    API Services, Data Processing
├─────────────────────────────────────┤
│         Utility Layer               │    Retry Logic, Network Utils, Helpers
├─────────────────────────────────────┤
│         Data Layer                  │    Models, API Clients, Local Storage
└─────────────────────────────────────┘
```

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── screens/                           # UI Screens
│   ├── transcription_screen.dart
│   ├── summary_screen.dart
│   ├── prescription_screen.dart
│   └── transcription_detail_screen.dart
├── features/                          # Feature modules with isolated logic
│   └── transcription/
│       ├── data/                      # Data layer for transcription
│       │   ├── deepgram_service.dart
│       │   ├── enhanced_deepgram_service.dart
│       │   └── gemini_service.dart
│       ├── domain/                    # Domain models and entities
│       │   └── transcription_model.dart
│       └── presentation/              # UI layer for transcription
│           ├── transcription_controller.dart
│           └── transcription_screen.dart
├── services/                          # Core services
│   ├── chatbot_service.dart
│   ├── enhanced_chatbot_service.dart
│   ├── pdf_service.dart
│   └── pdf_settings_service.dart
├── utils/                             # Utility functions and helpers
│   ├── retry_utility.dart             # Retry logic with exponential backoff
│   ├── network_utility.dart           # Network connectivity management
│   └── [other utilities]
├── models/                            # Data models
│   └── pdf_settings.dart
├── examples/                          # Example implementations
│   └── resilient_service_example.dart
└── widgets/                           # Reusable widgets
```

## Design Patterns

### 1. **Layered Architecture**
Each layer has a specific responsibility:
- **UI Layer**: Displays data and captures user input
- **Business Logic**: Orchestrates services and implements use cases
- **Service Layer**: Handles external integrations (APIs, databases)
- **Utility Layer**: Provides cross-cutting concerns (retry, logging, network)
- **Data Layer**: Manages data access and transformation

### 2. **Dependency Injection**
```dart
// Using Provider pattern
final chatbotServiceProvider = Provider<ChatbotService>((ref) {
  return ChatbotService(apiKey: dotenv.env['GEMINI_API_KEY']);
});
```

### 3. **Repository Pattern**
Services act as repositories for external data:
```dart
class ChatbotService {
  Future<String> getResponse(String prompt) async {
    // Fetch from external API
  }
}
```

### 4. **Error Handling**
Custom exceptions for different error types:
```dart
class NetworkException implements Exception { }
class ValidationException implements Exception { }
class TranscriptionException implements Exception { }
```

### 5. **Retry Strategy**
Configurable retry logic with exponential backoff:
```dart
await RetryUtility.execute<String>(
  () => apiCall(),
  config: RetryConfig.apiDefault,
  retryIf: RetryUtility.apiRetryCondition,
);
```

## Key Components

### Services

#### ChatbotService & EnhancedChatbotService
- Manages communication with Gemini AI API
- Handles API key resolution
- Enhanced version includes retry logic and error recovery

#### DeepgramService & EnhancedDeepgramService
- Processes audio transcription
- Supports multiple audio formats
- Enhanced version with file validation and retry logic

#### PdfService
- Generates PDF documents from text
- Handles markdown parsing
- Supports customizable templates

#### PdfSettingsService
- Persists user preferences using SharedPreferences
- Manages doctor info, clinic info, and PDF templates

### Utilities

#### RetryUtility
- Implements exponential backoff with jitter
- Supports multiple retry configuration profiles
- Provides intelligent error categorization

#### NetworkUtility
- Checks network connectivity
- Supports multi-host validation
- Implements smart caching

### Models

#### Domain Models
- `TranscriptionModel`: Represents transcription data
- `DoctorInfo`: Doctor information for PDF generation
- `ClinicInfo`: Clinic information for PDF generation
- `PdfTemplate`: PDF template configuration

### Controllers

#### TranscriptionController
- Manages transcription state
- Handles recording and processing
- Orchestrates service calls

## Data Flow

### Typical User Interaction Flow

```
1. User Input (UI)
   ↓
2. Controller/ViewModel processes input
   ↓
3. Service layer resolves which service to use
   ↓
4. Service makes API call with RetryUtility
   ↓
5. NetworkUtility checks connectivity
   ↓
6. API call with exponential backoff retry
   ↓
7. Response processed and model created
   ↓
8. Result returned to UI
   ↓
9. UI updates with data or error message
```

### Example: Audio Transcription Flow

```
User records audio
   ↓
TranscriptionScreen triggers recording
   ↓
TranscriptionController calls transcribeAudio()
   ↓
EnhancedDeepgramService.transcribeWithRetry()
   ↓
RetryUtility.execute with critical config
   ↓ (attempt 1, 2, 3, etc.)
NetworkUtility.checkConnectivity()
   ↓
HTTP POST to Deepgram API
   ↓
Response parsing and TranscriptionResult creation
   ↓
UI displays transcript with confidence score
```

## State Management

### Provider Pattern
Uses the `provider` package for dependency injection and state management:

```dart
// Define provider
final transcriptionControllerProvider =
  ChangeNotifierProvider<TranscriptionController>((ref) {
    return TranscriptionController();
  });

// Use in UI
final controller = ref.watch(transcriptionControllerProvider);
```

### ChangeNotifier Pattern
Services extend `ChangeNotifier` for reactive state:

```dart
class TranscriptionController extends ChangeNotifier {
  String _status = 'idle';

  void updateStatus(String newStatus) {
    _status = newStatus;
    notifyListeners(); // Triggers UI rebuild
  }
}
```

## Error Handling Strategy

### Hierarchical Error Handling

```
User-Facing Error Message
   ↓
Service-Level Exception (specific to domain)
   ↓
Network/HTTP Exception (transport layer)
   ↓
Platform Exception (OS level)
```

### Recovery Strategies

1. **Network Errors**: Retry with exponential backoff
2. **Rate Limiting**: Wait and retry
3. **Authentication Errors**: Prompt for credential update
4. **Validation Errors**: Show user-friendly message
5. **Server Errors**: Display status and suggest retry

## Testing Architecture

### Test Organization

```
test/
├── services/
│   ├── chatbot_service_test.dart
│   ├── deepgram_service_test.dart
│   └── [service tests]
├── models/
│   └── pdf_settings_test.dart
└── utils/
    ├── retry_utility_test.dart
    └── network_utility_test.dart
```

### Mocking Strategy

```dart
// Mock external dependencies
@GenerateMocks([http.Client, SharedPreferences])
void main() {
  group('Service Tests', () {
    late MockHttpClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
    });

    test('should call API with correct parameters', () {
      // Verify calls to mocked client
    });
  });
}
```

## Performance Considerations

### Optimization Strategies

1. **Caching**
   - Network responses cached in memory
   - Connectivity checks cached for 30 seconds
   - User preferences cached in SharedPreferences

2. **Lazy Loading**
   - Screens load data on demand
   - Large lists use ListView with lazy loading
   - Heavy computations deferred to background

3. **Memory Management**
   - Audio files processed in chunks
   - PDF generation streamed when possible
   - Proper resource disposal in lifecycle methods

4. **Network Optimization**
   - Connection pooling in HTTP client
   - Request timeout configuration
   - Response compression support

## Security Considerations

### API Key Management
- API keys stored in environment variables
- Never hardcoded in source code
- Sensitive data not logged

### Data Privacy
- User data processed locally when possible
- API communication over HTTPS
- Audio data not cached permanently

### Authentication
- API key validation before requests
- Token refresh handling
- Secure error messages (no sensitive data leaked)

## Deployment Architecture

### Build Pipeline

```
Source Code
   ↓
CI Pipeline (GitHub Actions)
   ↓
┌─────────────┬──────────────┬─────────┬──────────┐
│             │              │         │          │
Android      iOS           Web      Linux
Build        Build        Build       Build
   │             │              │         │
   └─────────────┴──────────────┴─────────┴──────────┐
                                                      ↓
                                           Artifact Generation
                                                      ↓
                                           GitHub Releases
```

### Platform-Specific Considerations

#### Android
- Multi-APK support (split by ABI)
- Proguard/R8 optimization
- Keystore for signing

#### iOS
- Code signing configuration
- Framework linking
- Simulator vs device builds

#### Web
- CanvasKit renderer for performance
- Service worker caching
- PWA capabilities

## Future Architectural Improvements

### Planned Enhancements
1. **Clean Architecture**: Stricter separation of concerns
2. **MVVM Pattern**: For complex UI logic
3. **Bloc Pattern**: Advanced state management
4. **Feature-First Structure**: Enhance modularity
5. **Micro-frontends**: Decompose into independent features

### Scalability Plans
1. **Service Layer Expansion**: Add more AI providers
2. **Offline Support**: Local processing capabilities
3. **Real-time Features**: WebSocket integration
4. **Analytics Integration**: User behavior tracking
5. **Internationalization**: Multi-language support

## Architecture Decision Records (ADRs)

### ADR-001: Use RetryUtility for All API Calls
**Decision**: All external API calls use RetryUtility with exponential backoff
**Rationale**: Improves reliability and user experience in poor network conditions
**Consequences**: Increased latency for failed requests, but much better UX

### ADR-002: Provider for State Management
**Decision**: Use Provider package for dependency injection and state management
**Rationale**: Simple, lightweight, and integrates well with Riverpod ecosystem
**Consequences**: Requires understanding of Provider patterns

### ADR-003: Feature Module Organization
**Decision**: Organize code by features rather than layers
**Rationale**: Makes feature development independent and maintainable
**Consequences**: Slightly more complex folder structure initially