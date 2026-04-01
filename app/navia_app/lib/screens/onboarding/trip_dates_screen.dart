import 'package:flutter/material.dart';

import '../../theme/navia_theme.dart';

class TripDatesScreen extends StatefulWidget {
  const TripDatesScreen({
    super.key,
    required this.destination,
    required this.onSelected,
  });

  final String destination;
  final ValueChanged<DateTimeRange> onSelected;

  @override
  State<TripDatesScreen> createState() => _TripDatesScreenState();
}

class _TripDatesScreenState extends State<TripDatesScreen> {
  DateTimeRange? _range;

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
                    'Trip to ${widget.destination}',
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
              onPressed: range == null ? null : () => widget.onSelected(range),
              child: const Text('Continue'),
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

