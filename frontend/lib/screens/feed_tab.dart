import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

/// Feed tab: the Movara assistant. A simple chat with the backend, which
/// forwards to Claude. History lives for the session only.
class FeedTab extends StatefulWidget {
  const FeedTab({super.key, required this.api});

  final ApiService api;

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  final _messages = <ChatMessage>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _unavailable = false;

  static const _suggestions = [
    'Suggest a 20-minute workout',
    'How do I run my first 5K?',
    'What should I eat after a run?',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _input.clear();
      _sending = true;
      _unavailable = false;
    });
    _scrollToEnd();

    try {
      final reply = await widget.api.sendChat(_messages);
      if (!mounted) return;
      setState(() => _messages.add(ChatMessage(role: 'assistant', content: reply)));
    } on ChatUnavailable {
      if (mounted) setState(() => _unavailable = true);
    } catch (_) {
      if (mounted) {
        setState(() => _messages.add(const ChatMessage(
            role: 'assistant',
            content: "I couldn't reach the assistant just now. Try again in a moment.")));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return Container(
      color: c.bg,
      child: Column(
        children: [
          Expanded(
            child: _messages.isEmpty ? _intro(context) : _list(context),
          ),
          if (_unavailable) _unavailableNote(context),
          _composer(context),
        ],
      ),
    );
  }

  Widget _list(BuildContext context) {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _messages.length) return _typing(context);
        return _bubble(context, _messages[i]);
      },
    );
  }

  Widget _bubble(BuildContext context, ChatMessage m) {
    final c = context.movara;
    final user = m.isUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: user ? c.accent : c.surface,
          border: user ? null : Border.all(color: c.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(user ? 16 : 4),
            bottomRight: Radius.circular(user ? 4 : 16),
          ),
        ),
        child: Text(
          m.content,
          style: TextStyle(
            color: user ? Colors.white : c.textPrimary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _typing(BuildContext context) {
    final c = context.movara;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width: 34,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              3,
              (_) => Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: c.textMuted, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final c = context.movara;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
      children: [
        Center(
          child: Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
            child: const Text('💬', style: TextStyle(fontSize: 26)),
          ),
        ),
        const SizedBox(height: 16),
        Text('Movara Assistant',
            textAlign: TextAlign.center,
            style: AppTheme.display(
                color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          'Ask about workouts, running, hydration or recovery.',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),
        for (final s in _suggestions) ...[
          GestureDetector(
            onTap: () => _send(s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                      child: Text(s,
                          style: TextStyle(color: c.textPrimary, fontSize: 13))),
                  Icon(Icons.arrow_forward, size: 15, color: c.accent),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _unavailableNote(BuildContext context) {
    final c = context.movara;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: c.surface2,
      child: Text(
        "The assistant isn't set up on the server yet.",
        textAlign: TextAlign.center,
        style: TextStyle(color: c.textSecondary, fontSize: 12),
      ),
    );
  }

  Widget _composer(BuildContext context) {
    final c = context.movara;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _send(),
                style: TextStyle(color: c.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ask Movara…',
                  hintStyle: TextStyle(color: c.textMuted),
                  filled: true,
                  fillColor: c.surface2,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: c.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: c.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: c.accent),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : () => _send(),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _sending ? c.surface3 : c.accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_upward,
                    color: _sending ? c.textMuted : Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
