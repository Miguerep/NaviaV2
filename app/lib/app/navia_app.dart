import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';

import '../app/app_settings.dart';
import '../api/navia_api.dart';
import '../providers/trip_provider.dart';
import '../screens/explore/explore_screen.dart';
import '../screens/guide/guide_screen.dart';
import '../screens/itinerary/itinerary_screen.dart';
import '../screens/onboarding/destination_screen.dart';
import '../screens/onboarding/onboarding_step_one_screen.dart';
import '../screens/onboarding/trip_dates_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../theme/navia_theme.dart';

class NaviaApp extends StatefulWidget {
  const NaviaApp({super.key});

  @override
  State<NaviaApp> createState() => _NaviaAppState();
}

class _NaviaAppState extends State<NaviaApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _buildRouter();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final locale = WidgetsBinding.instance.platformDispatcher.locale;
      final languageTag = locale.toLanguageTag();
      final trip = context.read<TripProvider>();
      trip.setAcceptLanguage(languageTag);
      trip.restoreTripIdFromStorage();
      // Fire-and-forget: request permission + capture coords.
      trip.initLocation();
      // Touch NaviaApi so it's available in the tree.
      context.read<NaviaApi>();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppSettings>().restoreLocaleFromStorage();
    });
  }

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/onboarding/destination',
      refreshListenable: context.read<TripProvider>(),
      routes: [
        GoRoute(
          path: '/onboarding/step-one',
          builder: (context, state) => const OnboardingStepOneScreen(),
        ),
        GoRoute(
          path: '/onboarding/destination',
          builder: (context, state) => const DestinationScreen(),
        ),
        GoRoute(
          path: '/onboarding/dates',
          builder: (context, state) => const TripDatesScreen(),
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
                  builder: (context, state) => const ExploreScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/app/itinerary',
                  builder: (context, state) => const ItineraryScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/app/guide',
                  builder: (context, state) => const GuideScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/app/profile',
                  builder: (context, state) => const ProfileScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
      redirect: (context, state) {
        final tripProvider = context.read<TripProvider>();
        final hasTrip = tripProvider.hasTrip;
        final isInApp = state.matchedLocation.startsWith('/app/');
        final isInOnboarding = state.matchedLocation.startsWith('/onboarding/');

        if (!hasTrip && isInApp) return '/onboarding/step-one';
        if (hasTrip && isInOnboarding) return '/app/explore';

        if (state.matchedLocation == '/onboarding/dates' && tripProvider.destination == null) {
            return '/onboarding/destination';
        }
        if (state.matchedLocation == '/onboarding/step-one' && tripProvider.tripDates == null) {
            return '/onboarding/dates';
        }

        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();

    return AppSettingsScope(
      settings: settings,
      child: MaterialApp.router(
        title: 'Navia',
        theme: NaviaTheme.light(highContrast: settings.highContrast),
        locale: settings.locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(settings.textScale),
            ),
            child: child ?? const SizedBox.shrink(),
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
