import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const _kLocaleKey = 'navia_locale_tag';

  double textScale = 1.0;
  double voiceSpeed = 0.45;
  bool highContrast = false;
  Locale? locale;

  Future<void> restoreLocaleFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tag = prefs.getString(_kLocaleKey)?.trim();
      if (tag == null || tag.isEmpty) return;
      final parts = tag.split('-');
      locale = parts.length >= 2 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setLocale(Locale? value) async {
    locale = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(_kLocaleKey);
      } else {
        final tag = value.countryCode == null || value.countryCode!.isEmpty
            ? value.languageCode
            : '${value.languageCode}-${value.countryCode}';
        await prefs.setString(_kLocaleKey, tag);
      }
    } catch (_) {}
  }

  void setTextScale(double sliderValue) {
    textScale = sliderValue <= 1.5
        ? 1.0
        : sliderValue <= 2.5
            ? 1.15
            : 1.3;
    notifyListeners();
  }

  void setVoiceSpeed(double sliderValue) {
    voiceSpeed = sliderValue <= 1.5
        ? 0.4
        : sliderValue <= 2.5
            ? 0.55
            : 0.75;
    notifyListeners();
  }

  void setHighContrast(bool value) {
    highContrast = value;
    notifyListeners();
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'AppSettingsScope not found in widget tree');
    return scope!.notifier!;
  }
}

