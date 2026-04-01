import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../../services/speech_service.dart';
import '../../theme/navia_theme.dart';

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({super.key, required this.destination, required this.tripDates});

  final String? destination;
  final DateTimeRange? tripDates;

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  final _speech = SpeechService.instance;

  @override
  void dispose() {
    _speech.stopSpeaking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final destination = widget.destination;
    final items = [
      ('09:30', 'The Louvre Museum', 'Glass Pyramid Entrance'),
      ('11:45', 'Jardin des Tuileries', 'Historic Garden Walk'),
      ('13:15', 'Place de la Concorde', 'The Egyptian Obelisk'),
      ('15:00', 'Musée de l\'Orangerie', 'Monet\'s Water Lilies'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Itinerary'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.mic),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        itemCount: items.length + 1,
        separatorBuilder: (context, index) =>
            const SizedBox(height: 14),
        itemBuilder: (context, idx) {
          if (idx == 0) {
            return Container(
              height: 160,
              decoration: BoxDecoration(
                color: NaviaThemeTokens.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  'Map overview (tap to open Explore)\nDestination: ${destination ?? '-'}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: NaviaThemeTokens.onSurfaceVariant,
                      ),
                ),
              ),
            );
          }

          final (time, title, subtitle) = items[idx - 1];
          final isNow = idx == 3;
          final bg = isNow ? NaviaThemeTokens.primary : NaviaThemeTokens.surfaceContainerLowest;
          final fg = isNow ? Colors.white : NaviaThemeTokens.onSurface;

          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: NaviaThemeTokens.onSurface.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        time,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: isNow ? Colors.white : NaviaThemeTokens.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: fg,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: isNow ? Colors.white70 : NaviaThemeTokens.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: isNow ? Colors.white : NaviaThemeTokens.primary,
                    foregroundColor: isNow ? NaviaThemeTokens.primary : Colors.white,
                    fixedSize: const Size(56, 56),
                  ),
                  onPressed: () {
                    _speech.speak(
                      '$title. $subtitle.',
                      speed: settings.voiceSpeed,
                    );
                  },
                  icon: const Icon(Icons.headphones),
                  tooltip: 'Audio guide',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

