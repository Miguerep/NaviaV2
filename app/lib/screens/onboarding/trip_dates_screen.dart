import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../api/navia_api.dart';
import '../../providers/trip_provider.dart';
import '../../theme/navia_theme.dart';

class TripDatesScreen extends StatefulWidget {
  const TripDatesScreen({super.key});

  @override
  State<TripDatesScreen> createState() => _TripDatesScreenState();
}

class _TripDatesScreenState extends State<TripDatesScreen> {
  DateTimeRange? _range;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: now, end: now.add(const Duration(days: 3)));
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: _range,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          datePickerTheme: const DatePickerThemeData(
            backgroundColor: NaviaThemeTokens.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    final trip = context.watch<TripProvider>();
    final destination = trip.destination ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Dates'),
      ),
      body: Padding(
        padding: NaviaThemeTokens.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'When are you going?',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: NaviaThemeTokens.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Trip to $destination',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: NaviaThemeTokens.onSurface,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pick your dates',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    range == null
                        ? 'No dates selected'
                        : '${_fmt(range.start)} → ${_fmt(range.end)}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: NaviaThemeTokens.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _pick,
                    icon: const Icon(Icons.date_range),
                    label: const Text('Select dates'),
                  ),
                ],
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: (range == null || _submitting)
                  ? null
                  : () async {
                      final dest = trip.destination?.trim() ?? '';
                      if (dest.isEmpty) return;
                      setState(() => _submitting = true);
                      try {
                        trip.setDates(range);
                        final api = context.read<NaviaApi>();
                        final created = await api.createTrip(
                          payload: CreateTripRequest(
                            destination: dest,
                            startDate: range.start,
                            endDate: range.end,
                            tripDuration: trip.tripDuration,
                            interests: trip.interests.toList(growable: false),
                            pace: trip.pace,
                            startLat: trip.startLat,
                            startLng: trip.startLng,
                          ),
                          acceptLanguage: trip.acceptLanguage,
                        );
                        trip.setTripId(created.id);
                        if (!mounted) return;
                        context.go('/app/explore');
                      } catch (_) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not create trip. Please try again.')),
                        );
                      } finally {
                        if (mounted) setState(() => _submitting = false);
                      }
                    },
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Continue'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd';
  }
}
