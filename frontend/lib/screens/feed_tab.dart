import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/chat_message.dart';
import '../services/chat_controller.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

/// Feed tab: the Movara assistant. A simple chat with the backend, which
/// forwards to Claude. History lives for the session only.
class FeedTab extends StatefulWidget {
  const FeedTab({super.key, required this.controller});

  final ChatController controller;

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  ChatController get _chat => widget.controller;
  List<ChatMessage> get _messages => _chat.messages;
  final _input = TextEditingController();
  final _scroll = ScrollController();

  static const _suggestions = [
    'Suggest a 20-minute workout',
    'How do I run my first 5K?',
    'What should I eat after a run?',
  ];

  @override
  void initState() {
    super.initState();
    _chat.addListener(_onChat);
    // Jump to the latest message when the chat is reopened.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _onChat() {
    if (mounted) {
      setState(() {});
      _scrollToEnd();
    }
  }

  @override
  void dispose() {
    _chat.removeListener(_onChat);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _chat.sending) return;
    _input.clear();
    _chat.send(text);
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
          if (_chat.unavailable) _unavailableNote(context),
          _composer(context),
        ],
      ),
    );
  }

  Widget _list(BuildContext context) {
    final awaitingFirst =
        _chat.sending && (_messages.isEmpty || _messages.last.isUser);
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length + (awaitingFirst ? 1 : 0),
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
        child: user
            ? Text(
                m.content,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
              )
            : MarkdownBody(
                data: m.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(color: c.textPrimary, fontSize: 14, height: 1.45),
                  strong: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w700),
                  em: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontStyle: FontStyle.italic),
                  listBullet: TextStyle(color: c.textPrimary, fontSize: 14),
                  h1: AppTheme.display(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                  h2: AppTheme.display(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
                  h3: AppTheme.display(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                  code: TextStyle(
                      color: c.accent,
                      backgroundColor: c.surface2,
                      fontSize: 13),
                  blockquote: TextStyle(color: c.textSecondary, fontSize: 14),
                  listBulletPadding: const EdgeInsets.only(right: 6),
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
        child: _TypingDots(color: c.textMuted),
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
              onTap: _chat.sending ? null : () => _send(),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _chat.sending ? c.surface3 : c.accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_upward,
                    color: _chat.sending ? c.textMuted : Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three dots that rise in sequence -- the "assistant is typing" cue.
class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.color});

  final Color color;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 14,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (i) {
              // Each dot is a third of a cycle behind the previous one.
              final t = (_c.value - i * 0.2) % 1.0;
              final lift = (t < 0.5) ? (1 - (t * 2 - 0.5).abs() * 2) : 0.0;
              return Transform.translate(
                offset: Offset(0, -3 * lift),
                child: Opacity(
                  opacity: 0.4 + 0.6 * lift,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration:
                        BoxDecoration(color: widget.color, shape: BoxShape.circle),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
