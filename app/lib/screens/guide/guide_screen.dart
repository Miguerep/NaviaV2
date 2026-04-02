import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_settings.dart';
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

  final List<_ChatMsg> _msgs = [
    _ChatMsg.user('It\'s raining, change today\'s plan to indoor museums'),
    _ChatMsg.assistant(
      'Of course! I\'ve updated your itinerary with the Capitoline Museums and a cozy coffee shop nearby.',
    ),
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
    const assistant = 'Got it — I\'ll update your itinerary.';
    setState(() {
      _msgs.add(_ChatMsg.user(text));
      _msgs.add(_ChatMsg.assistant(assistant));
    });
    _speech.speak(assistant, speed: settings.voiceSpeed);
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 240,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
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
                      decoration: const InputDecoration(
                        hintText: 'Type your request...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _toggleListen,
                    icon: Icon(_isListening ? Icons.stop : Icons.mic),
                    style: IconButton.styleFrom(
                      backgroundColor: NaviaThemeTokens.primary,
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
