# DocPilot

DocPilot is a Flutter application designed to assist healthcare providers in recording, transcribing, and analyzing doctor-patient conversations. It leverages voice recognition, natural language processing, and AI to streamline medical documentation workflows.

## Features

- **Voice Recording**: Capture doctor-patient conversations with a simple, intuitive interface
- **Real-time Voice Transcription**: Convert spoken conversations to text using Deepgram's Nova-2 model
- **AI-Powered Analysis**: Process transcribed conversations with Google's Gemini to generate:
    - Conversation summaries
    - Prescription suggestions
- **Elegant UI**: Beautiful gradient design with animated waveform visualization
- **Export & Share**: Save and share prescriptions with patients or other healthcare providers

## Getting Started

### Prerequisites

- Flutter SDK (latest version recommended)
- Dart SDK
- Android Studio / VS Code with Flutter extensions
- API keys for:
    - Deepgram (for speech-to-text)
    - Google Gemini (for AI processing)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/docpilot.git
   cd docpilot
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Create a `.env` file in the root directory with your API keys:
   ```
   DEEPGRAM_API_KEY=your_deepgram_api_key
   GEMINI_API_KEY=your_gemini_api_key
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart             # App entry point and main screen
├── screens/
│   ├── transcription_detail_screen.dart    # Displays raw transcription
│   ├── summary_screen.dart                 # Displays AI-generated summary
│   ├── prescription_screen.dart            # Displays AI-generated prescription
└── services/
    └── chatbot_service.dart                # Handles Gemini API integration
```

## How It Works

1. **Recording**: The app uses the `record` package to capture audio from the device's microphone.
2. **Transcription**: Recorded audio is sent to Deepgram's API for accurate speech-to-text conversion.
3. **AI Processing**: The transcription is sent to Google's Gemini AI for:
    - Generating a concise summary of the medical conversation
    - Creating a prescription based on the conversation content
4. **Visualization**: Results are displayed in separate screens with Markdown formatting for better readability.
5. **Export**: Prescriptions can be saved and shared with the patient via various apps.

## Dependencies

- `flutter_dotenv`: For managing environment variables
- `record`: For audio recording
- `path_provider`: For file management
- `permission_handler`: For handling device permissions
- `http`: For API requests
- `flutter_markdown`: For rendering formatted text
- `share_plus`: For sharing functionality

## Permissions

The app requires the following permissions:

- **Microphone**: For recording audio
- **Storage**: For saving prescriptions (Android)

## Customization

You can customize the app by:

- Modifying the theme colors in `main.dart`
- Adjusting the recording parameters in the `_startRecording()` method
- Changing the Gemini prompts in the `_processWithGemini()` method to get different outputs

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Deepgram](https://deepgram.com/) for speech-to-text capabilities
- [Google Gemini](https://ai.google.dev/) for AI processing
- Flutter team for the amazing framework

## Future Enhancements

- Multi-language support
- Patient history integration
- Cloud synchronization
- Custom AI model fine-tuning for medical terminology
- Appointment scheduling integration
- Medical image analysis