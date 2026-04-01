import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  SpeechService._();
  static final SpeechService instance = SpeechService._();

  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();

  Future<void> speak(String text, {required double speed}) async {
    await _tts.setSpeechRate(speed);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  Future<bool> startListening({
    required void Function(String words) onWords,
  }) async {
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
  }

  Future<void> stopListening() async {
    await _stt.stop();
  }
}

