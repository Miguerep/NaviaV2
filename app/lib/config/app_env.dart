import 'package:flutter/foundation.dart';

class AppEnv {
  static String get apiUrl {
    const fromEnv = String.fromEnvironment('API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8787'; // Android emulator localhost alias
    }
    return 'http://127.0.0.1:8787';
  }
}
