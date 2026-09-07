import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

/// Sticky header from the design: wordmark + time-aware greeting on the left,
/// theme toggle and profile avatar on the right.
class MovaraHeader extends StatelessWidget {
  const MovaraHeader({
    super.key,
    required this.username,
    required this.isDark,
    required this.onToggleTheme,
    this.onAvatarTap,
    this.photoUrl,
    this.action,
  });

  final String username;
  final bool isDark;
  final VoidCallback onToggleTheme;

  /// Opens the account screen. The avatar is the entry point to it now that
  /// Account is no longer a bottom tab.
  final VoidCallback? onAvatarTap;
  final String? photoUrl;

  /// Optional control shown left of the theme toggle (the timer button).
  final Widget? action;

  static String greetingFor(DateTime now) {
    if (now.hour < 12) return 'Good Morning';
    if (now.hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final initial = username.isEmpty ? '?' : username[0].toUpperCase();

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        14,
      ),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MOVARA',
                  style: AppTheme.display(
                    color: c.accent,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(color: c.textSecondary, fontSize: 13),
                      children: [
                        TextSpan(text: '${greetingFor(DateTime.now())}, '),
                        TextSpan(
                          text: '$username 👋',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (action != null) ...[
            action!,
            const SizedBox(width: 8),
          ],
          _ThemeToggle(isDark: isDark, onTap: onToggleTheme),
          const SizedBox(width: 10),
          _Avatar(initial: initial, onTap: onAvatarTap, photoUrl: photoUrl),
        ],
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.isDark, required this.onTap});

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? c.surface2 : c.surface3,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isDark ? '🌙' : '☀️', style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Text(
              isDark ? 'Dark' : 'Light',
              style: AppTheme.display(
                color: c.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, this.onTap, this.photoUrl});

  final String initial;
  final VoidCallback? onTap;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: c.accentSoft,
              shape: BoxShape.circle,
              border: Border.all(color: c.accent, width: 2),
            ),
            child: photoUrl != null && photoUrl!.isNotEmpty
                ? Image.network(photoUrl!, fit: BoxFit.cover, width: 44, height: 44,
                    errorBuilder: (_, __, ___) => _initialText(c))
                : _initialText(c),
          ),
          // Online dot.
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: c.green,
                shape: BoxShape.circle,
                border: Border.all(color: c.bg, width: 2),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _initialText(MovaraColors c) => Text(
        initial,
        style: AppTheme.display(
          color: c.accent,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      );
}
