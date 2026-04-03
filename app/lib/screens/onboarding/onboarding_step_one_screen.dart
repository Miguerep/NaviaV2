import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/trip_provider.dart';
import '../../theme/navia_theme.dart';

// ──────────────────────────────────────────────────────────────
// DATA
// ──────────────────────────────────────────────────────────────

class _InterestOption {
  const _InterestOption({
    required this.id,
    required this.icon,
    required this.label,
    required this.subtitle,
  });
  final String id;
  final IconData icon;
  final String label;
  final String subtitle;
}

const _kInterests = [
  _InterestOption(
    id: 'art_culture',
    icon: Icons.palette,
    label: 'Art & Culture',
    subtitle: 'Galleries, theaters, and local crafts.',
  ),
  _InterestOption(
    id: 'gastronomy',
    icon: Icons.restaurant,
    label: 'Gastronomy',
    subtitle: 'Street food, fine dining, and wine tours.',
  ),
  _InterestOption(
    id: 'history',
    icon: Icons.history_edu,
    label: 'History',
    subtitle: 'Landmarks, museums, and ancient ruins.',
  ),
  _InterestOption(
    id: 'nature',
    icon: Icons.forest,
    label: 'Nature',
    subtitle: 'Parks, coastal walks, and hidden trails.',
  ),
];

class _PaceOption {
  const _PaceOption({
    required this.label,
    required this.subtitle,
  });
  final String label;
  final String subtitle;
}

const _kPaces = [
  _PaceOption(label: 'Relaxed', subtitle: 'Easy walks, breaks'),
  _PaceOption(label: 'Balanced', subtitle: 'Mix energy/rest'),
  _PaceOption(label: 'Intensive', subtitle: 'Sunrise to sunset'),
];

// ──────────────────────────────────────────────────────────────
// SCREEN
// ──────────────────────────────────────────────────────────────

class OnboardingStepOneScreen extends StatelessWidget {
  const OnboardingStepOneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NaviaThemeTokens.surface,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Scrollable content
            CustomScrollView(
              slivers: [
                // ── Header ───────────────────────────────
                SliverToBoxAdapter(child: _OnboardingHeader()),

                // ── Body ─────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          'Tell us about\nyour trip',
                          style: GoogleFonts.lexend(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: NaviaThemeTokens.onSurface,
                            height: 1.1,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Let's craft an itinerary that perfectly matches your curiosity and comfort.",
                          style: GoogleFonts.lexend(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: NaviaThemeTokens.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Journey counter ──────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How long is your journey?',
                          style: GoogleFonts.lexend(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: NaviaThemeTokens.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _JourneyCounter(),
                      ],
                    ),
                  ),
                ),

                // ── Wanderlust grid ──────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What fuels your wanderlust?',
                          style: GoogleFonts.lexend(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: NaviaThemeTokens.onSurface,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const _WanderlustGrid(),
                      ],
                    ),
                  ),
                ),

                // ── Pace selector ────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "What's your preferred pace?",
                          style: GoogleFonts.lexend(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: NaviaThemeTokens.onSurface,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const _PaceSelector(),
                      ],
                    ),
                  ),
                ),

                // Bottom padding so content doesn't hide behind the bar
                const SliverPadding(
                  padding: EdgeInsets.only(bottom: 140),
                ),
              ],
            ),

            // ── Fixed bottom bar ─────────────────────────
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _NextStepBottomBar(),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// HEADER  (Back • Step 1 of 3 • progress dots)
// ──────────────────────────────────────────────────────────────

class _OnboardingHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: NaviaThemeTokens.surface.withValues(alpha: 0.9),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () {
              if (context.canPop()) context.pop();
            },
            child: const Icon(
              Icons.arrow_back,
              color: NaviaThemeTokens.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Step label
          Text(
            'Step 1 of 3',
            style: GoogleFonts.lexend(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: NaviaThemeTokens.onSurface,
            ),
          ),

          const Spacer(),

          // Progress indicator
          Row(
            children: [
              _progressDot(active: true),
              const SizedBox(width: 8),
              _progressDot(active: false),
              const SizedBox(width: 8),
              _progressDot(active: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressDot({required bool active}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 48,
      height: 6,
      decoration: BoxDecoration(
        color: active
            ? NaviaThemeTokens.primary
            : NaviaThemeTokens.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// JOURNEY COUNTER – stepper
// ──────────────────────────────────────────────────────────────

class _JourneyCounter extends StatelessWidget {
  const _JourneyCounter();

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripProvider>();

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: NaviaThemeTokens.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: NaviaThemeTokens.primary,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: NaviaThemeTokens.primary.withValues(alpha: 0.05),
            blurRadius: 16,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          // Minus button
          _StepperButton(
            icon: Icons.remove,
            onTap: () => trip.setTripDuration(trip.tripDuration - 1),
          ),

          // Value
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${trip.tripDuration}',
                  style: GoogleFonts.lexend(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: NaviaThemeTokens.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Day(s)',
                  style: GoogleFonts.lexend(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: NaviaThemeTokens.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Plus button
          _StepperButton(
            icon: Icons.add,
            onTap: () => trip.setTripDuration(trip.tripDuration + 1),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NaviaThemeTokens.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            icon,
            color: NaviaThemeTokens.primary,
            size: 24,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// WANDERLUST GRID – 2×2 interest cards
// ──────────────────────────────────────────────────────────────

class _WanderlustGrid extends StatelessWidget {
  const _WanderlustGrid();

  @override
  Widget build(BuildContext context) {
    final selected = context.watch<TripProvider>().interests;

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.78,
      children: _kInterests.map((opt) {
        final isActive = selected.contains(opt.id);
        return _InterestCard(option: opt, isActive: isActive);
      }).toList(),
    );
  }
}

class _InterestCard extends StatelessWidget {
  const _InterestCard({required this.option, required this.isActive});
  final _InterestOption option;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<TripProvider>().toggleInterest(option.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive
              ? NaviaThemeTokens.primary.withValues(alpha: 0.04)
              : NaviaThemeTokens.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: isActive
                ? NaviaThemeTokens.primary
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: NaviaThemeTokens.primary.withValues(alpha: 0.05),
                    blurRadius: 16,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              option.icon,
              size: 36,
              color: NaviaThemeTokens.primary,
            ),
            const SizedBox(height: 20),
            Text(
              option.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: NaviaThemeTokens.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              option.subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: NaviaThemeTokens.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// PACE SELECTOR – segmented toggle
// ──────────────────────────────────────────────────────────────

class _PaceSelector extends StatelessWidget {
  const _PaceSelector();

  @override
  Widget build(BuildContext context) {
    final currentPace = context.watch<TripProvider>().pace;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: NaviaThemeTokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: _kPaces.map((opt) {
          final isActive = currentPace == opt.label;
          return Expanded(
            child: _PaceChip(
              option: opt,
              isActive: isActive,
              onTap: () =>
                  context.read<TripProvider>().setPace(opt.label),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PaceChip extends StatelessWidget {
  const _PaceChip({
    required this.option,
    required this.isActive,
    required this.onTap,
  });
  final _PaceOption option;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive
              ? NaviaThemeTokens.surfaceContainerLowest
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: NaviaThemeTokens.onSurface.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              option.label,
              style: GoogleFonts.lexend(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? NaviaThemeTokens.primary
                    : NaviaThemeTokens.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              option.subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: NaviaThemeTokens.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// BOTTOM BAR – glassmorphic with gradient button
// ──────────────────────────────────────────────────────────────

class _NextStepBottomBar extends StatelessWidget {
  const _NextStepBottomBar();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: NaviaThemeTokens.surface.withValues(alpha: 0.8),
            border: Border(
              top: BorderSide(
                color: NaviaThemeTokens.surfaceContainerHighest.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: _GradientButton(
            label: 'Next Step',
            icon: Icons.arrow_forward,
            onTap: () {
              context.go('/onboarding/destination');
            },
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// GRADIENT BUTTON – primary → primaryDim at 135°
// ──────────────────────────────────────────────────────────────

class _GradientButton extends StatefulWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails _) => setState(() => _scale = 0.97);
  void _onTapUp(TapUpDetails _) => setState(() => _scale = 1.0);
  void _onTapCancel() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                NaviaThemeTokens.primary,
                NaviaThemeTokens.primaryDim,
              ],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: NaviaThemeTokens.onSurface.withValues(alpha: 0.06),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: GoogleFonts.lexend(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
