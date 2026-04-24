import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_settings.dart';
import '../../providers/trip_provider.dart';
import '../../theme/navia_theme.dart';
import '../../l10n/app_localizations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  double _sliderTextSize = 2;
  double _sliderVoice = 2;
  String _lang = 'en';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<AppSettings>();
      setState(() {
        final current = settings.locale?.languageCode ??
            WidgetsBinding.instance.platformDispatcher.locale.languageCode;
        _lang = (current == 'es') ? 'es' : 'en';
        _sliderTextSize = settings.textScale <= 1.01
            ? 1
            : settings.textScale <= 1.2
                ? 2
                : 3;
        _sliderVoice = settings.voiceSpeed <= 0.45
            ? 1
            : settings.voiceSpeed <= 0.6
                ? 2
                : 3;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.profileTitle),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.mic),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NaviaThemeTokens.surfaceContainerHighest,
                  ),
                  child: const Icon(Icons.person, size: 52),
                ),
                const SizedBox(height: 12),
                Text(
                  'Eleanor Vance',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Text(
                  'Curious Wanderer since 2023',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: NaviaThemeTokens.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, Icons.accessibility_new, loc.profileAccessibility),
          const SizedBox(height: 10),
          _card(
            child: Column(
              children: [
                _sliderRow(
                  context,
                  label: loc.profileTextSize,
                  valueLabel: _sliderTextSize <= 1.5
                      ? loc.profileTextNormal
                      : _sliderTextSize <= 2.5
                          ? loc.profileTextLarge
                          : loc.profileTextExtra,
                  iconStart: const Text('A'),
                  iconEnd: const Text('A', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  value: _sliderTextSize,
                  min: 1,
                  max: 3,
                  onChanged: (v) {
                    setState(() => _sliderTextSize = v);
                    settings.setTextScale(v);
                  },
                ),
                const SizedBox(height: 22),
                _sliderRow(
                  context,
                  label: loc.profileVoiceSpeed,
                  valueLabel: _sliderVoice <= 1.5
                      ? loc.profileVoiceGentle
                      : _sliderVoice <= 2.5
                          ? loc.profileVoiceNormal
                          : loc.profileVoiceFast,
                  iconStart: const Icon(Icons.slow_motion_video),
                  iconEnd: const Icon(Icons.directions_run),
                  value: _sliderVoice,
                  min: 1,
                  max: 3,
                  onChanged: (v) {
                    setState(() => _sliderVoice = v);
                    settings.setVoiceSpeed(v);
                  },
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: NaviaThemeTokens.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.contrast, color: NaviaThemeTokens.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.profileHighContrast, style: Theme.of(context).textTheme.titleMedium),
                            Text(
                              loc.profileHighContrastDesc,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: NaviaThemeTokens.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: settings.highContrast,
                        onChanged: (v) {
                          settings.setHighContrast(v);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: NaviaThemeTokens.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.language, color: NaviaThemeTokens.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.profileLanguage, style: Theme.of(context).textTheme.titleMedium),
                            Text(
                              loc.profileLanguageDesc,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: NaviaThemeTokens.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      DropdownButton<String>(
                        value: _lang,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(value: 'es', child: Text('Español')),
                        ],
                        onChanged: (v) async {
                          final next = v ?? 'en';
                          setState(() => _lang = next);
                          await settings.setLocale(Locale(next));
                          if (!context.mounted) return;
                          context.read<TripProvider>().setAcceptLanguage(next);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, Icons.favorite, loc.profileTravelPrefs),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _prefChip(context, loc.profileHistory, selected: true, isHistory: true),
              _prefChip(context, loc.profileArt, selected: false, isArt: true),
              _prefChip(context, loc.profileFood, selected: true, isFood: true),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: () {
              context.read<TripProvider>().reset();
            },
            child: Text(loc.profileResetTrip),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: NaviaThemeTokens.surfaceContainerLowest,
              foregroundColor: NaviaThemeTokens.error,
            ),
            onPressed: () {},
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.logout),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    loc.profileSignOut,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: NaviaThemeTokens.primary),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleLarge,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NaviaThemeTokens.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: NaviaThemeTokens.onSurface.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sliderRow(
    BuildContext context, {
    required String label,
    required String valueLabel,
    required Widget iconStart,
    required Widget iconEnd,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              valueLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: NaviaThemeTokens.primary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Opacity(opacity: 0.6, child: iconStart),
            const SizedBox(width: 12),
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: (max - min).toInt(),
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 12),
            iconEnd,
          ],
        ),
      ],
    );
  }

  Widget _prefChip(BuildContext context, String label, {required bool selected, bool isHistory = false, bool isArt = false, bool isFood = false}) {
    return Container(
      // No fixed width — adapts to text length
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: selected
            ? NaviaThemeTokens.primary.withValues(alpha: 0.12)
            : NaviaThemeTokens.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHistory
                ? Icons.history_edu
                : isArt
                    ? Icons.palette
                    : Icons.restaurant,
            color: selected ? NaviaThemeTokens.primary : NaviaThemeTokens.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Icon(
            selected ? Icons.check_circle : Icons.circle_outlined,
            color: selected ? NaviaThemeTokens.primary : NaviaThemeTokens.outlineVariant,
          ),
        ],
      ),
    );
  }
}
