import 'package:flutter/material.dart';

class AppSettings extends ChangeNotifier {
  double textScale = 1.0;
  double voiceSpeed = 0.45;
  bool highContrast = false;

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

