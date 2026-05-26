import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../app/app_settings.dart';
import '../../api/navia_api.dart';
import '../../components/external/osm_map_view.dart';
import '../../providers/explore_provider.dart';
import '../../providers/itinerary_provider.dart';
import '../../providers/trip_provider.dart';
import '../../services/speech_service.dart';
import '../../theme/navia_theme.dart';
import '../../l10n/app_localizations.dart';

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

  /// Get the user's current live GPS position.
  Future<Position?> _getCurrentPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Handle the walk button: get live GPS, geocode POI, fetch route, navigate
  /// to Explore tab with the route drawn on the map.
  Future<void> _onWalkRoute(Stop stop) async {
    final trip = context.read<TripProvider>();
    final api = context.read<NaviaApi>();
    final explore = context.read<ExploreProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    // Show loading indicator
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text('Getting route to ${stop.title}…')),
          ],
        ),
        duration: const Duration(seconds: 10),
        backgroundColor: NaviaThemeTokens.primary,
      ),
    );

    try {
      // 1. Get the user's current live GPS location
      final pos = await _getCurrentPosition();
      LatLng origin;
      if (pos != null) {
        origin = LatLng(pos.latitude, pos.longitude);
      } else if (trip.startLat != null && trip.startLng != null) {
        // Fallback to saved location
        origin = LatLng(trip.startLat!, trip.startLng!);
      } else {
        // Fallback: Geocode the trip destination city to use as a starting point
        final fallbackQuery = trip.destination ?? 'Paris';
        final fallbackResults = await api.searchPlaces(
          query: fallbackQuery,
          limit: 1,
          acceptLanguage: trip.acceptLanguage,
        );
        if (fallbackResults.isNotEmpty) {
          origin = LatLng(
            fallbackResults.first.center?.lat ?? 48.8566,
            fallbackResults.first.center?.lng ?? 2.3522,
          );
        } else {
          origin = const LatLng(48.8566, 2.3522); // Safe fallback (Paris)
        }
      }

      // 2. Geocode the stop title to get its coordinates
      final query = [
        stop.title,
        trip.destination,
      ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');

      final results = await api.searchPlaces(
        query: query,
        nearLatLng: '${origin.latitude},${origin.longitude}',
        limit: 1,
        acceptLanguage: trip.acceptLanguage,
      );

      final place = results.isEmpty ? null : results.first;
      final dest = place?.center;

      if (dest == null) {
        if (!mounted) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not find "${stop.title}" on the map.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final destLatLng = LatLng(dest.lat, dest.lng);

      // 3. Fetch the walking route
      final route = await api.getRouteWalking(
        from: GeoPoint(lat: origin.latitude, lng: origin.longitude),
        to: dest,
      );

      if (!mounted) return;
      messenger.hideCurrentSnackBar();

      // 4. Set the route on the shared ExploreProvider
      explore.setActiveRoute(
        route: route,
        origin: origin,
        destination: destLatLng,
        destinationName: stop.title,
      );

      // 5. Navigate to the Explore tab (index 0 in the shell)
      router.go('/app/explore');
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Route error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final trip = context.watch<TripProvider>();
    final provider = context.watch<ItineraryProvider>();
    final plan = provider.plan;
    final speech = context.read<SpeechService>();
    final api = context.read<NaviaApi>();

    final lat = trip.startLat;
    final lng = trip.startLng;
    final mapCenter = (lat != null && lng != null)
        ? LatLng(lat, lng)
        : const LatLng(48.8566, 2.3522); // Safe fallback (Paris)

    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.itineraryTitle),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.mic)),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: OsmMapView(
                      center: mapCenter,
                      zoom: 13,
                      interactiveFlags: 0, // preview-only
                    ),
                  ),
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          context.go('/app/explore');
                        },
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: NaviaThemeTokens.surfaceContainerLowest
                                    .withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                loc.itineraryMapOverview(
                                  trip.destination ?? '-',
                                ),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: NaviaThemeTokens.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (provider.loading) const LinearProgressIndicator(),
          if (provider.error != null) ...[
            const SizedBox(height: 12),
            Text(
              provider.error!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: NaviaThemeTokens.error),
            ),
          ],
          if (plan == null && !provider.loading) ...[
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.itineraryNoPlan,
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
                onRoute: () => _onWalkRoute(stop),
                onAudio: () async {
                  final tripId = trip.tripId;
                  if (tripId == null) return;
                  try {
                    final audioRes = await api.getNarrationAudio(
                      payload: NarrationSummaryRequest(
                        tripId: tripId,
                        stopTitle: stop.title,
                        stopSubtitle: stop.subtitle,
                      ),
                      acceptLanguage: trip.acceptLanguage,
                    );
                    if (audioRes.audioBytes != null) {
                      await speech.playAudioBytes(audioRes.audioBytes!);
                    } else if (audioRes.textFallback != null) {
                      await speech.speak(
                        audioRes.textFallback!,
                        speed: settings.voiceSpeed,
                      );
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(
                            context,
                          )!.itineraryAudioError(e.toString()),
                        ),
                        backgroundColor: NaviaThemeTokens.error,
                      ),
                    );
                    // Best-effort fallback
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
  const _StopCard({
    required this.stop,
    required this.onAudio,
    required this.onRoute,
  });

  final Stop stop;
  final VoidCallback onAudio;
  final VoidCallback onRoute;

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
          IconButton.outlined(
            style: IconButton.styleFrom(
              foregroundColor: NaviaThemeTokens.primary,
              fixedSize: const Size(52, 52),
            ),
            onPressed: onRoute,
            icon: const Icon(Icons.directions_walk),
            tooltip: 'Walk there',
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: NaviaThemeTokens.primary,
              foregroundColor: Colors.white,
              fixedSize: const Size(52, 52),
            ),
            onPressed: onAudio,
            icon: const Icon(Icons.headphones),
            tooltip: AppLocalizations.of(context)!.itineraryAudioGuide,
          ),
        ],
      ),
    );
  }
}
