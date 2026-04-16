// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get itineraryTitle => 'Daily Itinerary';

  @override
  String itineraryMapOverview(String destination) {
    return 'Map overview · Tap to Explore\nDestination: $destination';
  }

  @override
  String get itineraryNoPlan => 'No itinerary yet.';

  @override
  String itineraryAudioError(String error) {
    return 'Could not play audio: $error';
  }

  @override
  String get itineraryAudioGuide => 'Audio guide';

  @override
  String get guideWelcome => 'Hi! Tell me what you\'d like to change today.';

  @override
  String get guideTitle => 'Guide';

  @override
  String get guideToday => 'Today';

  @override
  String get guideHint => 'Type your request...';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileAccessibility => 'Accessibility Tools';

  @override
  String get profileTextSize => 'Text Size';

  @override
  String get profileTextNormal => 'Normal';

  @override
  String get profileTextLarge => 'Large';

  @override
  String get profileTextExtra => 'Extra';

  @override
  String get profileVoiceSpeed => 'Voice Speed';

  @override
  String get profileVoiceGentle => 'Gentle';

  @override
  String get profileVoiceNormal => 'Normal';

  @override
  String get profileVoiceFast => 'Fast';

  @override
  String get profileHighContrast => 'High Contrast';

  @override
  String get profileHighContrastDesc => 'Easier to read text';

  @override
  String get profileLanguage => 'Language';

  @override
  String get profileLanguageDesc => 'Choose the app language';

  @override
  String get profileTravelPrefs => 'Travel Preferences';

  @override
  String get profileHistory => 'History';

  @override
  String get profileArt => 'Art';

  @override
  String get profileFood => 'Food';

  @override
  String get profileResetTrip => 'Reset trip (go to onboarding)';

  @override
  String get profileSignOut => 'Sign Out of Explorer';
}
