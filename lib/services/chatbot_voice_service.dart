import 'package:speech_to_text/speech_to_text.dart';

class ChatbotVoiceService {
  late final SpeechToText _speechToText;
  bool _isListening = false;
  String _lastWords = '';
  String _selectedLocale = 'en_US';

  ChatbotVoiceService() {
    _speechToText = SpeechToText();
  }

  bool get isListening => _isListening;
  String get lastWords => _lastWords;

  Future<bool> initializeVoice() async {
    try {
      final available = await _speechToText.initialize(
        onError: (error) {
          print('Speech recognition error: $error');
          _isListening = false;
        },
        onStatus: (status) {
          print('Speech recognition status: $status');
        },
      );

      if (!available) {
        print('Speech recognition not available on this device');
        return false;
      }

      return true;
    } catch (e) {
      print('Error initializing speech recognition: $e');
      return false;
    }
  }

  Future<void> startListening() async {
    if (_isListening) return;

    try {
      final initialized = await initializeVoice();

      if (!initialized) {
        print('Speech recognition not available');
        return;
      }

      _lastWords = '';
      _isListening = true;

      await _speechToText.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
          print('Recognized: $_lastWords');
        },
        localeId: _selectedLocale,
      );
    } catch (e) {
      print('Error starting speech recognition: $e');
      _isListening = false;
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speechToText.stop();
      _isListening = false;
    } catch (e) {
      print('Error stopping speech recognition: $e');
      _isListening = false;
    }
  }

  bool get isAvailable => _speechToText.isAvailable;

  Future<void> dispose() async {
    await stopListening();
  }
}
