import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../api/navia_api.dart';
import '../../providers/trip_provider.dart';
import '../../theme/navia_theme.dart';

class DestinationScreen extends StatefulWidget {
  const DestinationScreen({super.key});

  @override
  State<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends State<DestinationScreen> {
  final _controller = TextEditingController();
  List<PlaceResult> _results = const [];
  bool _loading = false;
  String? _error;
  DateTime? _lastQueryAt;
  int _querySeq = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String value) async {
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
        _error = null;
      });
      return;
    }

    final seq = ++_querySeq;
    _lastQueryAt = DateTime.now();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    if (seq != _querySeq) return;
    final last = _lastQueryAt;
    if (last == null) return;
    if (DateTime.now().difference(last) < const Duration(milliseconds: 450)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<NaviaApi>();
      final trip = context.read<TripProvider>();
      final results = await api.searchPlaces(
        query: q,
        acceptLanguage: trip.acceptLanguage,
      );
      if (!mounted) return;
      if (seq != _querySeq) return;
      setState(() {
        _results = results;
      });
    } catch (e) {
      if (!mounted) return;
      if (seq != _querySeq) return;
      setState(() {
        _error = e.toString();
        _results = const [];
      });
    } finally {
      if (mounted && seq == _querySeq) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _submit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    context.read<TripProvider>().setDestination(trimmed);
    context.go('/onboarding/dates');
  }

  void _selectPlace(PlaceResult p) {
    final label = (p.name.isEmpty ? p.placeName : p.name).trim();
    if (label.isEmpty) return;
    if (p.center != null) {
      context
          .read<TripProvider>()
          .setStartLocation(lat: p.center!.lat, lng: p.center!.lng);
    }
    _controller.text = label;
    _submit(label);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 1 of 2'),
      ),
      body: Padding(
        padding: NaviaThemeTokens.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Where are you heading?',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: NaviaThemeTokens.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select your next adventure or search for a specific destination.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: NaviaThemeTokens.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
              onChanged: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search city or country',
              ),
            ),
            const SizedBox(height: 10),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: NaviaThemeTokens.error,
                    ),
              ),
            ],
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: NaviaThemeTokens.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _results.length.clamp(0, 6),
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final p = _results[idx];
                    final title = (p.name.isEmpty ? p.placeName : p.name).trim();
                    return ListTile(
                      title: Text(title.isEmpty ? p.placeName : title),
                      subtitle: (p.placeName.trim().isEmpty)
                          ? null
                          : Text(p.placeName),
                      onTap: () => _selectPlace(p),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Popular Destinations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _chip(context, 'Paris'),
                _chip(context, 'Rome'),
                _chip(context, 'Tokyo'),
                _chip(context, 'New York'),
              ],
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => _submit(_controller.text),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Next Step'),
                  SizedBox(width: 8),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label) {
    return InkWell(
      onTap: () => _submit(label),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: NaviaThemeTokens.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: NaviaThemeTokens.onSurface,
              ),
        ),
      ),
    );
  }
}
