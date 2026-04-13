import 'package:flutter/material.dart';
import '../api/navia_api.dart';

class ChatMessage {
  ChatMessage({required this.isUser, required this.text});
  final bool isUser;
  String text;
}

class ChatProvider extends ChangeNotifier {
  ChatProvider(this.api);
  final NaviaApi api;

  final List<ChatMessage> _messages = [];
  bool _loading = false;
  String? _error;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;
  String? get error => _error;

  void addSystemMessage(String text) {
    _messages.add(ChatMessage(isUser: false, text: text));
    notifyListeners();
  }

  Future<void> sendMessage({
    required String tripId,
    required DateTime activeDate,
    required String text,
    String? acceptLanguage,
    required Future<void> Function() onItineraryModified,
    void Function(String)? onAssistantMessageComplete,
  }) async {
    if (text.trim().isEmpty) return;

    _messages.add(ChatMessage(isUser: true, text: text));
    _messages.add(ChatMessage(isUser: false, text: ''));
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final stream = api.sendChatMessage(
        tripId: tripId,
        userMessage: text,
        activeDate: activeDate,
        acceptLanguage: acceptLanguage,
      );

      await for (final event in stream) {
        if (!_loading) break; // In case of cancel

        if (event is ChatEventText) {
          _messages.last.text = event.text;
          notifyListeners();
          if (event.isFinal && onAssistantMessageComplete != null) {
            onAssistantMessageComplete(event.text);
          }
        } else if (event is ChatEventActions) {
          if (event.actions.isNotEmpty) {
            await onItineraryModified();
          }
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void cancel() {
    _loading = false;
    notifyListeners();
  }
}
