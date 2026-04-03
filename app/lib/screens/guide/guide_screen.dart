import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../../app/app_settings.dart';
import '../../config/app_env.dart';
import '../../providers/itinerary_provider.dart';
import '../../providers/trip_provider.dart';
import '../../services/speech_service.dart';
import '../../theme/navia_theme.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late SpeechService _speech;
  bool _isListening = false;
  bool _sending = false;

  final List<_ChatMsg> _msgs = [
    _ChatMsg.assistant('Hi! Tell me what you’d like to change today.'),
  ];

  @override
  void initState() {
    super.initState();
    _speech = context.read<SpeechService>();
  }

  @override
  void dispose() {
    // Only stop speaking if we were actively listening, otherwise let audio finish. 
    // _speech.stopSpeaking();
    if (_isListening) {
      _speech.stopListening();
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final settings = AppSettingsScope.of(context);
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final trip = context.read<TripProvider>();
    final tripId = trip.tripId;
    final itinerary = context.read<ItineraryProvider>();
    final activeDate = itinerary.activeDay;
    if (tripId == null) return;

    setState(() {
      _sending = true;
      _msgs.add(_ChatMsg.user(text));
      _msgs.add(_ChatMsg.assistant('...'));
    });
    _controller.clear();
    _streamChat(
      tripId: tripId,
      userMessage: text,
      activeDate: activeDate,
      acceptLanguage: trip.acceptLanguage,
      voiceSpeed: settings.voiceSpeed,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 240,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _streamChat({
    required String tripId,
    required String userMessage,
    required DateTime activeDate,
    required String? acceptLanguage,
    required double voiceSpeed,
  }) async {
    http.Client? client;
    try {
      client = http.Client();
      final yyyy = activeDate.year.toString().padLeft(4, '0');
      final mm = activeDate.month.toString().padLeft(2, '0');
      final dd = activeDate.day.toString().padLeft(2, '0');
      final dateIso = '$yyyy-$mm-$dd';

      final uri = Uri.parse('${AppEnv.apiUrl}/v1/chat');
      final req = http.Request('POST', uri);
      req.headers['Content-Type'] = 'application/json; charset=utf-8';
      if (acceptLanguage != null && acceptLanguage.trim().isNotEmpty) {
        req.headers['Accept-Language'] = acceptLanguage.trim();
      }
      req.body = jsonEncode({
        'tripId': tripId,
        'activeDate': dateIso,
        'userMessage': userMessage,
      });

      final res = await client.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Chat failed: ${res.statusCode}');
      }

      final stream = res.stream.transform(utf8.decoder);
      final buffer = StringBuffer();
      String? currentEvent;

      void applyAssistantText(String text) {
        if (!mounted) return;
        setState(() {
          final idx = _msgs.lastIndexWhere((m) => !m.isUser);
          if (idx >= 0) {
            _msgs[idx] = _ChatMsg.assistant(text);
          }
        });
      }

      Future<void> handleEvent(String event, String data) async {
        if (event == 'message.delta' || event == 'message.final') {
          final obj = jsonDecode(data);
          if (obj is Map && obj['text'] is String) {
            applyAssistantText(obj['text'] as String);
          }
          if (event == 'message.final') {
            final obj2 = jsonDecode(data);
            final finalText = (obj2 is Map && obj2['text'] is String)
                ? (obj2['text'] as String)
                : null;
            if (finalText != null && finalText.trim().isNotEmpty) {
              await _speech.speak(finalText, speed: voiceSpeed);
            }
          }
          return;
        }

        if (event == 'actions') {
          final obj = jsonDecode(data);
          final actions = (obj is Map) ? obj['actions'] : null;
          final hasReplace = (actions is List)
              ? actions.any((a) =>
                  a is Map && (a['type']?.toString() == 'ReplaceDayPlan'))
              : false;
          if (hasReplace) {
            final itinerary = context.read<ItineraryProvider>();
            final trip = context.read<TripProvider>();
            final tripId = trip.tripId;
            if (tripId != null) {
              await itinerary.loadDay(
                tripId: tripId,
                day: itinerary.activeDay,
                acceptLanguage: trip.acceptLanguage,
              );
            }
          }
          return;
        }
      }

      await for (final chunk in stream) {
        buffer.write(chunk);
        final text = buffer.toString();
        final parts = text.split('\n\n');
        if (parts.length == 1) continue;
        buffer
          ..clear()
          ..write(parts.removeLast());

        for (final rawEvent in parts) {
          final lines = rawEvent.split('\n');
          currentEvent = null;
          final dataLines = <String>[];
          for (final line in lines) {
            if (line.startsWith('event:')) {
              currentEvent = line.substring(6).trim();
            } else if (line.startsWith('data:')) {
              dataLines.add(line.substring(5).trim());
            }
          }
          final ev = currentEvent;
          if (ev == null) continue;
          final data = dataLines.join('\n');
          if (data.isEmpty) continue;
          await handleEvent(ev, data);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final idx = _msgs.lastIndexWhere((m) => !m.isUser);
        if (idx >= 0) {
          _msgs[idx] = _ChatMsg.assistant('Sorry — I could not reach the guide service.');
        }
      });
    } finally {
      client?.close();
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleListen() async {
    if (_isListening) {
      await _speech.stopListening();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    final started = await _speech.startListening(
      onWords: (words) {
        if (!mounted) return;
        setState(() => _controller.text = words);
      },
    );
    if (mounted) setState(() => _isListening = started);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guide'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.mic),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              itemCount: _msgs.length + 1,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 14),
              itemBuilder: (context, idx) {
                if (idx == 0) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: NaviaThemeTokens.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Today',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: NaviaThemeTokens.onSurfaceVariant,
                            ),
                      ),
                    ),
                  );
                }
                final msg = _msgs[idx - 1];
                return Align(
                  alignment:
                      msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: msg.isUser
                            ? NaviaThemeTokens.primary
                            : NaviaThemeTokens.surfaceContainerLowest,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                          bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                        ),
                        boxShadow: msg.isUser
                            ? null
                            : [
                                BoxShadow(
                                  color: NaviaThemeTokens.onSurface.withValues(alpha: 0.06),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                      ),
                      child: Text(
                        msg.text,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: msg.isUser ? Colors.white : NaviaThemeTokens.onSurface,
                              height: 1.25,
                            ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.add_circle),
                    color: NaviaThemeTokens.primaryDim,
                    iconSize: 32,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      enabled: !_sending,
                      decoration: const InputDecoration(
                        hintText: 'Type your request...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _toggleListen,
                    icon: Icon(_isListening ? Icons.stop : Icons.mic),
                    style: IconButton.styleFrom(
                      backgroundColor: NaviaThemeTokens.primary,
                      foregroundColor: Colors.white,
                      fixedSize: const Size(56, 56),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor: NaviaThemeTokens.primaryDim,
                      foregroundColor: Colors.white,
                      fixedSize: const Size(56, 56),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMsg {
  _ChatMsg(this.isUser, this.text);
  final bool isUser;
  final String text;

  static _ChatMsg user(String text) => _ChatMsg(true, text);
  static _ChatMsg assistant(String text) => _ChatMsg(false, text);
}
