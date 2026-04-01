import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_settings.dart';
import '../screens/explore/explore_screen.dart';
import '../screens/guide/guide_screen.dart';
import '../screens/itinerary/itinerary_screen.dart';
import '../screens/onboarding/destination_screen.dart';
import '../screens/onboarding/trip_dates_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../theme/navia_theme.dart';

class NaviaApp extends StatefulWidget {
  const NaviaApp({super.key});

  @override
  State<NaviaApp> createState() => _NaviaAppState();
}

class _NaviaAppState extends State<NaviaApp> {
  String? _destination;
  DateTimeRange? _tripDates;
  final AppSettings _settings = AppSettings();

  late final GoRouter _router = GoRouter(
    initialLocation: '/onboarding/destination',
    routes: [
      GoRoute(
        path: '/onboarding/destination',
        builder: (context, state) => DestinationScreen(
          onSelected: (destination) {
            setState(() => _destination = destination);
            context.go('/onboarding/dates');
          },
        ),
      ),
      GoRoute(
        path: '/onboarding/dates',
        redirect: (context, state) =>
            _destination == null ? '/onboarding/destination' : null,
        builder: (context, state) => TripDatesScreen(
          destination: _destination!,
          onSelected: (dates) {
            setState(() => _tripDates = dates);
            context.go('/app/explore');
          },
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => _AppShell(
          navigationShell: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/explore',
                builder: (context, state) => ExploreScreen(
                  destination: _destination,
                  tripDates: _tripDates,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/itinerary',
                builder: (context, state) => ItineraryScreen(
                  destination: _destination,
                  tripDates: _tripDates,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/guide',
                builder: (context, state) => GuideScreen(
                  destination: _destination,
                  tripDates: _tripDates,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/profile',
                builder: (context, state) => ProfileScreen(
                  destination: _destination,
                  tripDates: _tripDates,
                  settings: _settings,
                  onResetTrip: () {
                    setState(() {
                      _destination = null;
                      _tripDates = null;
                    });
                    context.go('/onboarding/destination');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final hasTrip = _destination != null && _tripDates != null;
      final isInApp = state.matchedLocation.startsWith('/app/');

      if (!hasTrip && isInApp) return '/onboarding/destination';
      if (hasTrip && state.matchedLocation.startsWith('/onboarding/')) {
        return '/app/explore';
      }
      return null;
    },
  );

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: _settings,
      child: AnimatedBuilder(
        animation: _settings,
        builder: (context, _) {
          return MaterialApp.router(
            title: 'Navia',
            theme: NaviaTheme.light(highContrast: _settings.highContrast),
            routerConfig: _router,
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: TextScaler.linear(_settings.textScale),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: NaviaThemeTokens.surface.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(48),
              topRight: Radius.circular(48),
            ),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (idx) => navigationShell.goBranch(
              idx,
              initialLocation: idx == navigationShell.currentIndex,
            ),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Explore',
              ),
              NavigationDestination(
                icon: Icon(Icons.event_note_outlined),
                selectedIcon: Icon(Icons.event_note),
                label: 'Itinerary',
              ),
              NavigationDestination(
                icon: Icon(Icons.forum_outlined),
                selectedIcon: Icon(Icons.forum),
                label: 'Guide',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

