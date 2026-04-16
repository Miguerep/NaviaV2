import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_settings.dart';
import '../../providers/chat_provider.dart';
import '../../providers/itinerary_provider.dart';
import '../../providers/trip_provider.dart';
import '../../services/speech_service.dart';
import '../../theme/navia_theme.dart';
import '../../l10n/app_localizations.dart';

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
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      _isInit = true;
      final chat = context.read<ChatProvider>();
      if (chat.messages.isEmpty) {
        chat.addSystemMessage(AppLocalizations.of(context)!.guideWelcome);
      }
    }
  }

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

  void _send() async {
    final settings = AppSettingsScope.of(context);
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final trip = context.read<TripProvider>();
    final tripId = trip.tripId;
    final itinerary = context.read<ItineraryProvider>();
    final activeDate = itinerary.activeDay;
    final chat = context.read<ChatProvider>();
    
    if (tripId == null) return;

    _controller.clear();
    FocusScope.of(context).unfocus();
    
    _scrollToBottom();
    
    await chat.sendMessage(
      tripId: tripId,
      activeDate: activeDate,
      text: text,
      acceptLanguage: trip.acceptLanguage,
      onItineraryModified: () async {
        await itinerary.loadDay(
          tripId: tripId,
          day: activeDate,
          acceptLanguage: trip.acceptLanguage,
        );
      },
      onAssistantMessageComplete: (finalText) {
        if (finalText.isNotEmpty) {
          _speech.speak(finalText, speed: settings.voiceSpeed);
        }
      },
    );
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 240,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
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
    final chat = context.watch<ChatProvider>();
    final sending = chat.loading;
    final msgs = chat.messages;

    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.guideTitle),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.mic),
          ),
        ],
      ),
      body: Column(
        children: [
          if (chat.error != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: NaviaThemeTokens.error.withValues(alpha: 0.1),
              child: Text(
                'Error: ${chat.error}',
                style: TextStyle(color: NaviaThemeTokens.error),
              ),
            ),
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              itemCount: msgs.length + 1,
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
                        loc.guideToday,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: NaviaThemeTokens.onSurfaceVariant,
                            ),
                      ),
                    ),
                  );
                }
                final msg = msgs[idx - 1];
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
                        msg.text.isEmpty && !msg.isUser ? '...' : msg.text,
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
                      enabled: !sending,
                      decoration: InputDecoration(
                        hintText: loc.guideHint,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending ? null : _toggleListen,
                    icon: Icon(_isListening ? Icons.stop : Icons.mic),
                    style: IconButton.styleFrom(
                      backgroundColor: NaviaThemeTokens.primary,
                      foregroundColor: Colors.white,
                      fixedSize: const Size(56, 56),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending ? chat.cancel : _send,
                    icon: Icon(sending ? Icons.stop : Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor: sending ? NaviaThemeTokens.surfaceContainerHighest : NaviaThemeTokens.primaryDim,
                      foregroundColor: sending ? NaviaThemeTokens.onSurface : Colors.white,
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

