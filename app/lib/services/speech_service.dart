import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _ttsReady = false;

  /// Set the TTS language (BCP-47 tag, e.g. "en-US", "es-ES").
  Future<void> setLanguage(String? languageTag) async {
    if (languageTag == null || languageTag.trim().isEmpty) return;
    await _ensureTtsReady();
    try {
      // flutter_tts expects codes like "en-US" or just "en"
      final tag = languageTag.trim();
      await _tts.setLanguage(tag);
    } catch (_) {
      // Unsupported locale on this device – ignore, will use default.
    }
  }

  Future<void> playAudioBytes(Uint8List bytes) async {
    try {
      await _tts.stop();
      await _audioPlayer.stop();
      await _audioPlayer.play(BytesSource(bytes));
    } catch (_) {
      rethrow;
    }
  }

  Future<void> speak(String text, {required double speed}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _ensureTtsReady();
    try {
      await _tts.setSpeechRate(speed);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _audioPlayer.stop();
      await _tts.stop();
      await _tts.speak(t);
    } catch (_) {
      // Best-effort: caller UI should fallback gracefully.
      rethrow;
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _audioPlayer.stop();
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
