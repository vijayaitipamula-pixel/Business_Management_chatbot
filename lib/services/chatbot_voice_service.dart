import 'package:speech_to_text/speech_to_text.dart';

class ChatbotVoiceService {
  ChatbotVoiceService({this.onListeningChanged, this.onTranscript});
  final SpeechToText _speechToText = SpeechToText();
  final void Function(bool)? onListeningChanged;
  final void Function(String)? onTranscript;
  bool _isListening = false;
  bool _disposed = false;
  String _lastWords = '';
  final String _selectedLocale = 'en_US';

  bool get isListening => _isListening;
  String get lastWords => _lastWords;
  bool get isAvailable => _speechToText.isAvailable;

  void _setListening(bool listening) {
    _isListening = listening;
    if (!_disposed) onListeningChanged?.call(listening);
  }

  Future<bool> initializeVoice() async {
    if (_disposed) return false;
    try {
      return await _speechToText.initialize(
        onError: (_) => _setListening(false),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _setListening(false);
          }
        },
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> startListening() async {
    if (_isListening || _disposed) return;
    if (!await initializeVoice() || _disposed) return;
    _lastWords = '';
    _setListening(true);
    try {
      await _speechToText.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
          if (!_disposed) onTranscript?.call(_lastWords);
        },
        localeId: _selectedLocale,
      );
      if (_disposed) await _speechToText.cancel();
    } catch (_) {
      _setListening(false);
    }
  }

  Future<void> stopListening() async {
    try {
      await _speechToText.stop();
    } finally {
      _setListening(false);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _speechToText.cancel();
    } catch (_) {
      // The plugin may be unavailable on this platform.
    }
    _isListening = false;
  }
}
