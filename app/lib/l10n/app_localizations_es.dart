// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get itineraryTitle => 'Itinerario Diario';

  @override
  String itineraryMapOverview(String destination) {
    return 'Mapa · Toca para Explorar\nDestino: $destination';
  }

  @override
  String get itineraryNoPlan => 'Aún no hay itinerario.';

  @override
  String itineraryAudioError(String error) {
    return 'No se pudo reproducir el audio: $error';
  }

  @override
  String get itineraryAudioGuide => 'Audioguía';

  @override
  String get guideWelcome => '¡Hola! Dime qué te gustaría cambiar hoy.';

  @override
  String get guideTitle => 'Guía';

  @override
  String get guideToday => 'Hoy';

  @override
  String get guideHint => 'Escribe tu petición...';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get profileAccessibility => 'Herramientas de Accesibilidad';

  @override
  String get profileTextSize => 'Tamaño del Texto';

  @override
  String get profileTextNormal => 'Normal';

  @override
  String get profileTextLarge => 'Grande';

  @override
  String get profileTextExtra => 'Extra';

  @override
  String get profileVoiceSpeed => 'Velocidad de Voz';

  @override
  String get profileVoiceGentle => 'Suave';

  @override
  String get profileVoiceNormal => 'Normal';

  @override
  String get profileVoiceFast => 'Rápido';

  @override
  String get profileHighContrast => 'Alto Contraste';

  @override
  String get profileHighContrastDesc => 'Texto más fácil de leer';

  @override
  String get profileLanguage => 'Idioma';

  @override
  String get profileLanguageDesc => 'Elige el idioma de la app';

  @override
  String get profileTravelPrefs => 'Preferencias de Viaje';

  @override
  String get profileHistory => 'Historia';

  @override
  String get profileArt => 'Arte';

  @override
  String get profileFood => 'Comida';

  @override
  String get profileResetTrip => 'Reiniciar viaje (ir al inicio)';

  @override
  String get profileSignOut => 'Cerrar sesión de Explorer';
}
