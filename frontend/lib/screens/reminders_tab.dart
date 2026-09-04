import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/reminder_scheduler.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

/// Water reminder settings: turn it on and pick how often it repeats.
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
              if (scheduler.enabled) ...[
                _intervalPicker(context),
                const SizedBox(height: 16),
              ],
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(
            color: scheduler.enabled ? c.accent : c.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheduler.enabled ? c.accentSoft : c.surface2,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Text('💧', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Water Reminder',
                  style: AppTheme.display(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  scheduler.enabled
                      ? 'Every ${scheduler.intervalHours} '
                          '${scheduler.intervalHours == 1 ? "hour" : "hours"}'
                      : 'Off',
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          _switch(
            context,
            scheduler.enabled,
            () => scheduler.setEnabled(!scheduler.enabled),
          ),
        ],
      ),
    );
  }

  Widget _intervalPicker(BuildContext context) {
    final c = context.movara;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REMIND ME EVERY',
          style:
              TextStyle(color: c.textMuted, fontSize: 10, letterSpacing: 1.6),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final hours in ReminderScheduler.intervalOptions) ...[
              if (hours != ReminderScheduler.intervalOptions.first)
                const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => scheduler.setIntervalHours(hours),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheduler.intervalHours == hours
                          ? c.accent
                          : c.surface2,
                      border: Border.all(
                        color: scheduler.intervalHours == hours
                            ? c.accent
                            : c.border,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '$hours ${hours == 1 ? "hour" : "hours"}',
                      style: AppTheme.display(
                        color: scheduler.intervalHours == hours
                            ? Colors.white
                            : c.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
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
          if (scheduler.enabled && due != null) ...[
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
            const SizedBox(height: 12),
          ],
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
