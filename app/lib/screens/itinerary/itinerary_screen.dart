import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_settings.dart';
import '../../api/navia_api.dart';
import '../../providers/trip_provider.dart';
import '../../services/speech_service.dart';
import '../../theme/navia_theme.dart';

class ItineraryScreen extends StatelessWidget {
  const ItineraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ItineraryScreenBody();
  }
}

class _ItineraryScreenBody extends StatefulWidget {
  const _ItineraryScreenBody();

  @override
  State<_ItineraryScreenBody> createState() => _ItineraryScreenBodyState();
}

class _ItineraryScreenBodyState extends State<_ItineraryScreenBody> {
  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedOnce) return;
    _loadedOnce = true;

    final trip = context.read<TripProvider>();
    final tripId = trip.tripId;
    final range = trip.tripDates;
    if (tripId == null) return;

    final day = range?.start ?? DateTime.now();
    context.read<ItineraryProvider>().loadDay(
          tripId: tripId,
          day: day,
          acceptLanguage: trip.acceptLanguage,
        );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final trip = context.watch<TripProvider>();
    final provider = context.watch<ItineraryProvider>();
    final plan = provider.plan;
    final speech = context.read<SpeechService>();
    final api = context.read<NaviaApi>();

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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: NaviaThemeTokens.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                'Map overview (tap to open Explore)\nDestination: ${trip.destination ?? '-'}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: NaviaThemeTokens.onSurfaceVariant,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (provider.loading) const LinearProgressIndicator(),
          if (provider.error != null) ...[
            const SizedBox(height: 12),
            Text(
              provider.error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: NaviaThemeTokens.error,
                  ),
            ),
          ],
          if (plan == null && !provider.loading) ...[
            const SizedBox(height: 12),
            Text(
              'No itinerary yet.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: NaviaThemeTokens.onSurfaceVariant,
                  ),
            ),
          ],
          if (plan != null) ...[
            for (final stop in plan.stops) ...[
              const SizedBox(height: 14),
              _StopCard(
                stop: stop,
                onAudio: () async {
                  final tripId = trip.tripId;
                  if (tripId == null) return;
                  try {
                    final summary = await api.getNarrationSummary(
                      payload: NarrationSummaryRequest(
                        tripId: tripId,
                        stopTitle: stop.title,
                        stopSubtitle: stop.subtitle,
                      ),
                      acceptLanguage: trip.acceptLanguage,
                    );
                    await speech.speak(summary.text, speed: settings.voiceSpeed);
                  } catch (_) {
                    await speech.speak(
                      '${stop.title}. ${stop.subtitle ?? ''}'.trim(),
                      speed: settings.voiceSpeed,
                    );
                  }
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({required this.stop, required this.onAudio});

  final Stop stop;
  final VoidCallback onAudio;

  @override
  Widget build(BuildContext context) {
    final time = (stop.startTimeLocal?.trim().isNotEmpty ?? false)
        ? stop.startTimeLocal!
        : '--:--';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NaviaThemeTokens.surfaceContainerLowest,
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
                        color: NaviaThemeTokens.primary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  stop.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: NaviaThemeTokens.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if ((stop.subtitle ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    stop.subtitle!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: NaviaThemeTokens.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: NaviaThemeTokens.primary,
              foregroundColor: Colors.white,
              fixedSize: const Size(56, 56),
            ),
            onPressed: onAudio,
            icon: const Icon(Icons.headphones),
            tooltip: 'Audio guide',
          ),
        ],
      ),
    );
  }
}
