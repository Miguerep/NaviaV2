import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  bool _ttsReady = false;

  Future<void> speak(String text, {required double speed}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _ensureTtsReady();
    try {
      await _tts.setSpeechRate(speed);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.stop();
      await _tts.speak(t);
    } catch (_) {
      // Best-effort: caller UI should fallback gracefully.
      rethrow;
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> _ensureTtsReady() async {
    if (_ttsReady) return;
    try {
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {
      // Some platforms may not support it; ignore.
    }
    _ttsReady = true;
  }

  Future<bool> startListening({
    required void Function(String words) onWords,
  }) async {
    try {
      final available = await _stt.initialize();
      if (!available) return false;
      await _stt.listen(
        onResult: (result) => onWords(result.recognizedWords),
        // ignore: deprecated_member_use
        listenMode: ListenMode.confirmation,
        // ignore: deprecated_member_use
        partialResults: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stopListening() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }
}
