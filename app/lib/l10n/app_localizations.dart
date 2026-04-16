import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @itineraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Itinerary'**
  String get itineraryTitle;

  /// No description provided for @itineraryMapOverview.
  ///
  /// In en, this message translates to:
  /// **'Map overview · Tap to Explore\nDestination: {destination}'**
  String itineraryMapOverview(String destination);

  /// No description provided for @itineraryNoPlan.
  ///
  /// In en, this message translates to:
  /// **'No itinerary yet.'**
  String get itineraryNoPlan;

  /// No description provided for @itineraryAudioError.
  ///
  /// In en, this message translates to:
  /// **'Could not play audio: {error}'**
  String itineraryAudioError(String error);

  /// No description provided for @itineraryAudioGuide.
  ///
  /// In en, this message translates to:
  /// **'Audio guide'**
  String get itineraryAudioGuide;

  /// No description provided for @guideWelcome.
  ///
  /// In en, this message translates to:
  /// **'Hi! Tell me what you\'d like to change today.'**
  String get guideWelcome;

  /// No description provided for @guideTitle.
  ///
  /// In en, this message translates to:
  /// **'Guide'**
  String get guideTitle;

  /// No description provided for @guideToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get guideToday;

  /// No description provided for @guideHint.
  ///
  /// In en, this message translates to:
  /// **'Type your request...'**
  String get guideHint;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility Tools'**
  String get profileAccessibility;

  /// No description provided for @profileTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text Size'**
  String get profileTextSize;

  /// No description provided for @profileTextNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get profileTextNormal;

  /// No description provided for @profileTextLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get profileTextLarge;

  /// No description provided for @profileTextExtra.
  ///
  /// In en, this message translates to:
  /// **'Extra'**
  String get profileTextExtra;

  /// No description provided for @profileVoiceSpeed.
  ///
  /// In en, this message translates to:
  /// **'Voice Speed'**
  String get profileVoiceSpeed;

  /// No description provided for @profileVoiceGentle.
  ///
  /// In en, this message translates to:
  /// **'Gentle'**
  String get profileVoiceGentle;

  /// No description provided for @profileVoiceNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get profileVoiceNormal;

  /// No description provided for @profileVoiceFast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get profileVoiceFast;

  /// No description provided for @profileHighContrast.
  ///
  /// In en, this message translates to:
  /// **'High Contrast'**
  String get profileHighContrast;

  /// No description provided for @profileHighContrastDesc.
  ///
  /// In en, this message translates to:
  /// **'Easier to read text'**
  String get profileHighContrastDesc;

  /// No description provided for @profileLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLanguage;

  /// No description provided for @profileLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose the app language'**
  String get profileLanguageDesc;

  /// No description provided for @profileTravelPrefs.
  ///
  /// In en, this message translates to:
  /// **'Travel Preferences'**
  String get profileTravelPrefs;

  /// No description provided for @profileHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get profileHistory;

  /// No description provided for @profileArt.
  ///
  /// In en, this message translates to:
  /// **'Art'**
  String get profileArt;

  /// No description provided for @profileFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get profileFood;

  /// No description provided for @profileResetTrip.
  ///
  /// In en, this message translates to:
  /// **'Reset trip (go to onboarding)'**
  String get profileResetTrip;

  /// No description provided for @profileSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out of Explorer'**
  String get profileSignOut;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
