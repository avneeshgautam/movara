import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/reminder_scheduler.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

/// Water reminder settings: pick how often it repeats, then switch it on.
class RemindersTab extends StatelessWidget {
  const RemindersTab({super.key, required this.scheduler});

  final ReminderScheduler scheduler;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return AnimatedBuilder(
      animation: scheduler,
      builder: (context, _) {
        return Container(
          color: c.bg,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text(
                'STAY HYDRATED',
                style: TextStyle(
                    color: c.textMuted, fontSize: 10, letterSpacing: 1.6),
              ),
              const SizedBox(height: 2),
              Text(
                'Reminders',
                style: AppTheme.display(
                  color: c.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              _waterCard(context),
              const SizedBox(height: 16),
              _statusCard(context),
            ],
          ),
        );
      },
    );
  }

  Widget _waterCard(BuildContext context) {
    final c = context.movara;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: scheduler.enabled ? c.accent : c.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheduler.enabled ? c.accentSoft : c.surface2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text('💧', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Water Reminder',
                  style: AppTheme.display(
                    color: c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  scheduler.enabled ? 'On' : 'Off',
                  style: TextStyle(color: c.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Timing control sits before the toggle so the interval is chosen
          // first, then switched on.
          _intervalDropdown(context),
          const SizedBox(width: 10),
          _switch(
            context,
            scheduler.enabled,
            () => scheduler.setEnabled(!scheduler.enabled),
          ),
        ],
      ),
    );
  }

  Widget _intervalDropdown(BuildContext context) {
    final c = context.movara;

    return PopupMenuButton<int>(
      tooltip: 'Reminder interval',
      color: c.surface,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) {
        if (value == -1) {
          _promptCustomInterval(context);
        } else {
          scheduler.setIntervalMinutes(value);
        }
      },
      itemBuilder: (context) => [
        for (final minutes in ReminderScheduler.intervalOptions)
          PopupMenuItem<int>(
            value: minutes,
            child: Row(
              children: [
                Icon(
                  scheduler.intervalMinutes == minutes
                      ? Icons.check
                      : Icons.schedule,
                  size: 16,
                  color: scheduler.intervalMinutes == minutes
                      ? c.accent
                      : c.textMuted,
                ),
                const SizedBox(width: 10),
                Text(
                  formatInterval(minutes),
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: scheduler.intervalMinutes == minutes
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<int>(
          value: -1,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 16, color: c.textMuted),
              const SizedBox(width: 10),
              Text('Custom…', style: TextStyle(color: c.textPrimary)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              scheduler.intervalLabel,
              style: AppTheme.display(
                color: c.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.arrow_drop_down, size: 18, color: c.textMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _promptCustomInterval(BuildContext context) async {
    final c = context.movara;
    final controller =
        TextEditingController(text: '${scheduler.intervalMinutes}');

    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Remind me every',
            style: AppTheme.display(color: c.textPrimary, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'e.g. 30',
            suffixText: 'minutes',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('Set'),
          ),
        ],
      ),
    );

    if (minutes != null && minutes > 0) {
      await scheduler.setIntervalMinutes(minutes);
    }
  }

  Widget _statusCard(BuildContext context) {
    final c = context.movara;
    final due = scheduler.nextDue;
    final blocked = scheduler.permission == 'denied';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.repeat, size: 16, color: c.textMuted),
              const SizedBox(width: 8),
              Text(
                'Every ${scheduler.intervalLabel}',
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
            ],
          ),
          if (scheduler.enabled && due != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: c.accent),
                const SizedBox(width: 8),
                Text(
                  'Next reminder at ${DateFormat.jm().format(due)}',
                  style: TextStyle(color: c.textPrimary, fontSize: 13),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (blocked)
            _note(
              context,
              Icons.notifications_off,
              'Notifications are blocked for this site. Enable them in your '
              'browser settings for Movara, then turn the reminder on again.',
              const Color(0xFFEF4444),
            )
          else
            _note(
              context,
              Icons.info_outline,
              'Reminders fire while Movara is open in your browser. A web app '
              'cannot wake a closed tab, so keep it open (or added to your '
              'home screen) to be reminded. Anything due while it was closed '
              'shows the next time you open it.',
              c.textSecondary,
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: scheduler.sendTest,
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: const Text('Send a test reminder'),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.accent,
                side: BorderSide(color: c.accent.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _note(
      BuildContext context, IconData icon, String text, Color colour) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: colour),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: colour, fontSize: 11, height: 1.45),
          ),
        ),
      ],
    );
  }

  Widget _switch(BuildContext context, bool on, VoidCallback onTap) {
    final c = context.movara;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 44,
        height: 24,
        decoration: BoxDecoration(
          color: on ? c.accent : c.surface3,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? c.accent : c.border, width: 1.5),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 160),
              left: on ? 21 : 1,
              top: 1,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
