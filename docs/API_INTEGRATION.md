# API Integration Guide

This guide explains how to integrate various APIs with DocPilot and how to use the built-in services.

## Overview of Integrated APIs

| API | Service | Purpose | Status |
|-----|---------|---------|--------|
| **Gemini** | ChatbotService | AI text generation and analysis | ✅ Active |
| **Deepgram** | DeepgramService | Audio transcription | ✅ Active |
| **Google Docs API** | Planned | Document synchronization | 🔄 Planned |
| **EHR Systems** | Planned | Clinical data integration | 🔄 Planned |

## Gemini API Integration

### Setup

1. **Obtain API Key**
   - Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
   - Create new API key
   - Copy the key

2. **Configure in App**
   ```bash
   # Add to .env file
   GEMINI_API_KEY=your_api_key_here
   ```

3. **Verify Setup**
   ```bash
   flutter run
   # App should initialize without API key errors
   ```

### Usage

#### Basic Usage
```dart
import 'package:doc_pilot/services/enhanced_chatbot_service.dart';

final chatbotService = EnhancedChatbotService(
  apiKey: 'your-api-key',
);

try {
  final response = await chatbotService.getGeminiResponse(
    'Generate a medical summary for patient with fever and cough.',
  );
  print('Response: $response');
} catch (e) {
  print('Error: $e');
} finally {
  chatbotService.dispose();
}
```

#### With Retry Configuration
```dart
final response = await chatbotService.getGeminiResponse(
  prompt,
  retryConfig: RetryConfig.critical,  // 5 attempts
  timeoutDuration: const Duration(seconds: 45),
);
```

#### Enhanced Error Handling
```dart
try {
  final response = await chatbotService.getEnhancedGeminiResponse(
    prompt,
    retryConfig: RetryConfig.critical,
  );
  return response;
} on MaxRetriesExceededException catch (e) {
  // Show user: "Service temporarily unavailable, please try again"
  return buildUserFriendlyError(e.lastException);
} on NetworkException catch (e) {
  // Show user: "Please check your internet connection"
  return 'Network Error: ${e.message}';
}
```

### Rate Limiting

Gemini API has rate limits:
- **Free tier**: 60 requests per minute
- **Paid tier**: Higher limits based on plan

The retry logic automatically handles rate limiting with exponential backoff.

### API Response Format

```json
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "Generated response text"
          }
        ]
      }
    }
  ]
}
```

### Common Errors

```
❌ 401 Unauthorized: Invalid API key
   → Check GEMINI_API_KEY in .env

❌ 429 Too Many Requests: Rate limited
   → Retry logic automatically handles this
   → Wait before retrying manually

❌ 500 Internal Server Error: Server issue
   → Retry with exponential backoff
   → Usually resolves quickly

❌ Timeout: Request took too long
   → Check internet connection
   → Try shorter prompts
   → Increase timeout duration if persistent
```

## Deepgram API Integration

### Setup

1. **Obtain API Key**
   - Visit [Deepgram Console](https://console.deepgram.com)
   - Create project
   - Generate API key
   - Copy the key

2. **Configure in App**
   ```bash
   # Add to .env file
   DEEPGRAM_API_KEY=your_api_key_here
   ```

### Supported Audio Formats

| Format | MIME Type | Sample Rate | Bit Depth |
|--------|-----------|-------------|-----------|
| MP3 | audio/mp3 | 8-48 kHz | 16-bit |
| WAV | audio/wav | 8-48 kHz | 16-bit |
| M4A | audio/m4a | 8-48 kHz | 16-bit |
| FLAC | audio/flac | 8-48 kHz | 16-bit |
| OGG | audio/ogg | 8-48 kHz | 16-bit |

### Usage

#### Basic Transcription
```dart
import 'package:doc_pilot/features/transcription/data/enhanced_deepgram_service.dart';

final deepgramService = EnhancedDeepgramService(
  apiKey: 'your-api-key',
);

try {
  final result = await deepgramService.transcribeWithRetry(
    '/path/to/audio/file.m4a',
  );

  print('Transcript: ${result.transcript}');
  print('Confidence: ${result.confidencePercent}%');
  print('Duration: ${result.durationSeconds}s');
} catch (e) {
  print('Error: $e');
}
```

#### With Custom Configuration
```dart
final result = await deepgramService.transcribeWithRetry(
  audioPath,
  model: 'nova-2',  // Deepgram model
  language: 'en',   // Language code
  includeConfidence: true,  // Include confidence scores
  retryConfig: RetryConfig.critical,  // Retry config
  timeoutDuration: const Duration(seconds: 60),
);
```

#### File Validation
The service automatically validates:
- ✅ File exists
- ✅ File format supported
- ✅ File size (<150MB)
- ✅ File not empty

```dart
// Triggers validation automatically
final result = await deepgramService.transcribeWithRetry(
  '/path/to/file.m4a',  // Validates before transcription
);
```

### Response Format

```dart
class TranscriptionResult {
  final String transcript;           // Transcribed text
  final double? confidence;          // 0.0 to 1.0
  final double? durationSeconds;     // Audio duration
  final String? model;               // Model used
  final String? language;            // Detected language
}
```

### API Response Structure

```json
{
  "results": {
    "channels": [
      {
        "alternatives": [
          {
            "transcript": "This is the transcribed text",
            "confidence": 0.9532
          }
        ]
      }
    ],
    "metadata": {
      "duration": 45.23,
      "model": "nova-2"
    }
  }
}
```

### Common Errors

```
❌ 401 Unauthorized: Invalid API key
   → Verify DEEPGRAM_API_KEY in .env

❌ 413 Payload Too Large: File >150MB
   → Use shorter audio files
   → Split large files

❌ 415 Unsupported Media Type: Wrong format
   → Use supported formats: MP3, WAV, M4A, FLAC, OGG
   → Convert audio file if needed

❌ 429 Rate Limited: Too many requests
   → Built-in retry handles this
   → Space out requests if manual

❌ Timeout: Transcription taking too long
   → Check file size
   → Ensure stable internet
   → Increase timeout duration
```

## Network Connectivity Management

### Checking Connectivity

```dart
// Quick check (uses cache if available)
final isConnected = await NetworkUtility.isConnected();

// Detailed check
final networkInfo = await NetworkUtility.checkConnectivity();
print('Status: ${networkInfo.status}');
print('Response time: ${networkInfo.responseTimeMs}ms');

// Force fresh check (bypass cache)
final freshInfo = await NetworkUtility.forceCheck();

// Multi-host check
final bestInfo = await NetworkUtility.checkMultipleHosts();
```

### Waiting for Connectivity

```dart
// Wait up to 2 minutes for connection
bool recovered = await NetworkUtility.waitForConnectivity(
  maxWaitTime: Duration(minutes: 2),
  onCheck: (info) {
    print('Connection check: ${info.status}');
  },
);

if (recovered) {
  // Connectivity restored, retry operation
} else {
  // Still no connection after waiting
}
```

## Implementing Retry Logic

### Simple Retry

```dart
// Uses default API configuration
await RetryUtility.execute<String>(
  () => apiCall(),
  config: RetryConfig.apiDefault,
);
```

### Custom Retry Configuration

```dart
await RetryUtility.execute<String>(
  () => criticalOperation(),
  config: const RetryConfig(
    maxAttempts: 5,
    baseDelay: Duration(milliseconds: 1000),
    backoffMultiplier: 2.0,
    maxDelay: Duration(seconds: 30),
    useJitter: true,
  ),
);
```

### Conditional Retry

```dart
await RetryUtility.execute<String>(
  () => apiCall(),
  config: RetryConfig.apiDefault,
  retryIf: (exception) {
    // Custom retry conditions
    if (exception.toString().contains('rate limit')) return true;
    if (exception.toString().contains('timeout')) return true;
    return RetryUtility.isRetryableException(exception);
  },
);
```

### Progress Tracking

```dart
await RetryUtility.execute<String>(
  () => apiCall(),
  config: RetryConfig.apiDefault,
  onRetry: (exception, attempt) {
    print('Attempt $attempt failed: $exception');
    print('Retrying in ${delay}ms...');
  },
);
```

## Implementation Patterns

### Pattern 1: Service Wrapper

```dart
class ApiWrapper {
  Future<T> call<T>(Future<T> Function() operation) {
    return RetryUtility.execute(
      operation,
      config: RetryConfig.apiDefault,
      retryIf: RetryUtility.apiRetryCondition,
    );
  }
}

// Usage
final wrapper = ApiWrapper();
final result = await wrapper.call(() => myService.operation());
```

### Pattern 2: Decorated Service

```dart
class ResilientChatbotService extends ChatbotService {
  @override
  Future<String> getGeminiResponse(String prompt) {
    return RetryUtility.execute(
      () => super.getGeminiResponse(prompt),
      config: RetryConfig.apiDefault,
      retryIf: RetryUtility.apiRetryCondition,
    );
  }
}
```

### Pattern 3: Middleware

```dart
class NetworkMiddleware {
  Future<T> execute<T>(Future<T> Function() operation) async {
    // Check network first
    final connected = await NetworkUtility.isConnected();
    if (!connected) {
      throw NetworkException('No internet connection');
    }

    // Retry if needed
    return await RetryUtility.execute(
      operation,
      config: RetryConfig.apiDefault,
    );
  }
}
```

## Best Practices

### ✅ Do's
- Check network connectivity before expensive operations
- Use appropriate retry configurations for different operations
- Handle specific exceptions with clear error messages
- Log API calls for debugging
- Dispose of resources properly

### ❌ Don'ts
- Don't retry non-idempotent operations
- Don't ignore rate limit errors
- Don't hardcode API keys
- Don't retry authentication errors
- Don't make unnecessary API calls

## Troubleshooting

### Issue: "Missing API Key" Error

**Solution**:
```bash
# 1. Check .env file exists
ls -la .env

# 2. Verify key in .env
cat .env | grep GEMINI_API_KEY

# 3. Reload app
flutter run
```

### Issue: API Request Timeout

**Solution**:
```dart
// 1. Increase timeout
await service.operation(
  timeoutDuration: Duration(seconds: 60),  // Default 30s
);

// 2. Check network quality
final info = await NetworkUtility.checkConnectivity();
print('Response time: ${info.responseTimeMs}ms');

// 3. Try shorter requests
```

### Issue: Rate Limiting

**Solution**: The retry logic handles this automatically with exponential backoff. If manual retries needed:

```dart
// Implement manual rate limit handling
const rateLimitDelay = Duration(minutes: 1);
await Future.delayed(rateLimitDelay);
// Retry operation
```

## Resources

- [Gemini API Docs](https://ai.google.dev)
- [Deepgram API Docs](https://developers.deepgram.com)
- [API Security Best Practices](https://owasp.org)
- [OAuth Implementation Guide](https://oauth.net)

---

For questions or issues, see the [Contributing Guide](CONTRIBUTING.md).