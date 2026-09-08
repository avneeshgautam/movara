import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import 'api_service.dart';

/// Owns the assistant conversation and its in-flight request, independent of
/// any screen. Living above the chat view means history survives closing the
/// chat, and a slow reply keeps streaming (and typing out) in the background
/// so it's there when the user comes back.
class ChatController extends ChangeNotifier {
  ChatController({required this.api});

  final ApiService api;

  final List<ChatMessage> messages = [];
  bool sending = false;
  bool unavailable = false;

  // Typewriter reveal state.
  Timer? _typer;
  String _streamFull = '';
  int _revealed = 0;
  bool _streamDone = false;
  int? _assistantIndex;

  Future<void> send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || sending) return;

    messages.add(ChatMessage(role: 'user', content: text));
    sending = true;
    unavailable = false;
    _streamFull = '';
    _revealed = 0;
    _streamDone = false;
    _assistantIndex = null;
    notifyListeners();

    final toSend = List<ChatMessage>.of(messages);
    _startTyper();

    try {
      // Cap the wait between chunks: if the stream connects but stalls (it can
      // hang without sending anything), time out and use the reliable
      // non-streaming path below instead of sitting on the dots forever.
      await for (final delta
          in api.sendChatStream(toSend).timeout(const Duration(seconds: 12))) {
        _streamFull += delta;
      }
    } on ChatUnavailable {
      _typer?.cancel();
      unavailable = true;
      _finish();
      return;
    } on TimeoutException {
      // Streaming stalled; fall back below.
    } catch (_) {
      // Streaming failed; fall back below.
    }

    if (_streamFull.trim().isEmpty) {
      try {
        _streamFull = await api.sendChat(toSend);
      } on ChatUnavailable {
        _typer?.cancel();
        unavailable = true;
        _finish();
        return;
      } catch (_) {
        // fall through
      }
    }
    if (_streamFull.trim().isEmpty) {
      _streamFull =
          "I couldn't reach the assistant just now. Try again in a moment.";
    }
    _streamDone = true;
  }

  void _startTyper() {
    _typer?.cancel();
    _typer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_revealed < _streamFull.length) {
        final remaining = _streamFull.length - _revealed;
        _revealed += (remaining ~/ 20).clamp(1, remaining);
        final shown = _streamFull.substring(0, _revealed);
        if (_assistantIndex == null) {
          messages.add(ChatMessage(role: 'assistant', content: shown));
          _assistantIndex = messages.length - 1;
        } else {
          messages[_assistantIndex!] =
              ChatMessage(role: 'assistant', content: shown);
        }
        notifyListeners();
      } else if (_streamDone) {
        _finish();
      }
    });
  }

  void _finish() {
    _typer?.cancel();
    _typer = null;
    sending = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _typer?.cancel();
    super.dispose();
  }
}
