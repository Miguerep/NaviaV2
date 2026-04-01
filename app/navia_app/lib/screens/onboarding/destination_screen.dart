import 'package:flutter/material.dart';

import '../../theme/navia_theme.dart';

class DestinationScreen extends StatefulWidget {
  const DestinationScreen({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  State<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends State<DestinationScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    widget.onSelected(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 3 of 3'),
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
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search city or country',
              ),
            ),
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
                  Text('Start My Journey'),
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
      onTap: () => widget.onSelected(label),
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

