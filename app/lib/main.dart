import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api/navia_api.dart';
import 'app/app_settings.dart';
import 'app/navia_app.dart';
import 'config/app_env.dart';
import 'providers/chat_provider.dart';
import 'providers/itinerary_provider.dart';
import 'providers/trip_provider.dart';
import 'services/speech_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        Provider<NaviaApi>(create: (_) => NaviaApi(baseUrl: AppEnv.apiUrl)),
        Provider<SpeechService>(create: (_) => SpeechService()),
        ChangeNotifierProvider<TripProvider>(create: (_) => TripProvider()),
        ChangeNotifierProvider<ItineraryProvider>(
          create: (context) => ItineraryProvider(api: context.read<NaviaApi>()),
        ),
        ChangeNotifierProvider<ChatProvider>(
          create: (context) => ChatProvider(context.read<NaviaApi>()),
        ),
        ChangeNotifierProvider<AppSettings>(create: (_) => AppSettings()),
      ],
      child: const NaviaApp(),
    ),
  );
}
