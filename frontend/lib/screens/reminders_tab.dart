import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/reminder.dart';
import '../services/reminder_scheduler.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

/// Lists the user's reminders and lets them add, edit, toggle and delete
/// custom ones. The single water reminder from earlier builds is migrated in
/// as the first item.
class RemindersTab extends StatelessWidget {
  const RemindersTab({super.key, required this.scheduler});

  final ReminderScheduler scheduler;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return AnimatedBuilder(
      animation: scheduler,
      builder: (context, _) {
        final reminders = scheduler.reminders;

        return Container(
          color: c.bg,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text('STAY ON TRACK',
                  style: TextStyle(
                      color: c.textMuted, fontSize: 10, letterSpacing: 1.6)),
              const SizedBox(height: 2),
              Text('Reminders',
                  style: AppTheme.display(
                      color: c.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),

              if (_banner(context) case final banner?) ...[
                banner,
                const SizedBox(height: 16),
              ],

              if (reminders.isEmpty)
                _empty(context)
              else
                for (final r in reminders) ...[
                  _ReminderCard(
                    reminder: r,
                    onToggle: (on) => scheduler.setReminderEnabled(r.id, on),
                    onEdit: () => _openDialog(context, existing: r),
                    onDelete: () => _confirmDelete(context, r),
                    switchBuilder: _switch,
                  ),
                  const SizedBox(height: 12),
                ],

              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add reminder'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: AppTheme.display(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _sendTest(context),
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
      },
    );
  }

  Widget? _banner(BuildContext context) {
    if (!scheduler.isSupported) {
      return _note(context,
          'Reminders are not supported on this device. Install the app to get them.');
    }
    if (scheduler.permission == 'denied') {
      return _note(context,
          'Notifications are turned off for Movara. Enable them in Settings to '
          'get reminders.');
    }
    return null;
  }

  Widget _note(BuildContext context, String text) {
    final c = context.movara;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: c.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: c.textSecondary, fontSize: 12, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final c = context.movara;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Text('🔔', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 10),
          Text('No reminders yet',
              style: AppTheme.display(color: c.textPrimary, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Add one to be nudged — water, stretch, a walk, anything.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _openDialog(BuildContext context, {Reminder? existing}) async {
    final result = await showDialog<_ReminderInput>(
      context: context,
      builder: (_) => _ReminderDialog(existing: existing),
    );
    if (result == null) return;

    if (existing == null) {
      await scheduler.addReminder(
          label: result.label, intervalMinutes: result.minutes);
    } else {
      await scheduler.updateReminder(existing.id,
          label: result.label, intervalMinutes: result.minutes);
    }
  }

  Future<void> _confirmDelete(BuildContext context, Reminder r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = ctx.movara;
        return AlertDialog(
          backgroundColor: c.surface,
          title: Text('Delete reminder?',
              style: AppTheme.display(color: c.textPrimary, fontSize: 16)),
          content: Text('“${r.label}” will be removed.',
              style: TextStyle(color: c.textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: c.textMuted))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete',
                    style: TextStyle(color: Color(0xFFEF4444)))),
          ],
        );
      },
    );
    if (ok == true) await scheduler.removeReminder(r.id);
  }

  Future<void> _sendTest(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final sent = await scheduler.sendTest();
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(sent
          ? 'Test reminder sent.'
          : scheduler.isSupported
              ? 'Notifications are turned off for Movara. Enable them in '
                  'Settings to get reminders.'
              : 'Reminders are not supported on this device.'),
      duration: const Duration(seconds: 4),
    ));
  }

  Widget _switch(BuildContext context, bool on, ValueChanged<bool> onChanged) {
    final c = context.movara;
    return GestureDetector(
      onTap: () => onChanged(!on),
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
                    color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.switchBuilder,
  });

  final Reminder reminder;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget Function(BuildContext, bool, ValueChanged<bool>) switchBuilder;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
            child: const Text('🔔', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onEdit,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reminder.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.display(
                          color: c.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Every ${formatInterval(reminder.intervalMinutes)}',
                      style: TextStyle(color: c.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: c.textMuted,
            onPressed: onDelete,
          ),
          switchBuilder(context, reminder.enabled, onToggle),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _ReminderInput {
  const _ReminderInput(this.label, this.minutes);
  final String label;
  final int minutes;
}

/// Add / edit sheet: a label and an interval (a preset or a typed value).
class _ReminderDialog extends StatefulWidget {
  const _ReminderDialog({this.existing});

  final Reminder? existing;

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  late final TextEditingController _label =
      TextEditingController(text: widget.existing?.label ?? '');
  late final TextEditingController _custom = TextEditingController();
  late int _minutes =
      widget.existing?.intervalMinutes ?? ReminderScheduler.defaultIntervalMinutes;

  @override
  void dispose() {
    _label.dispose();
    _custom.dispose();
    super.dispose();
  }

  void _save() {
    final typed = int.tryParse(_custom.text.trim());
    final minutes = (typed ?? _minutes).clamp(
        ReminderScheduler.minIntervalMinutes,
        ReminderScheduler.maxIntervalMinutes);
    Navigator.pop(context, _ReminderInput(_label.text, minutes));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final isEdit = widget.existing != null;

    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(isEdit ? 'Edit reminder' : 'New reminder',
          style: AppTheme.display(color: c.textPrimary, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _label,
              autofocus: !isEdit,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: c.textPrimary),
              decoration: InputDecoration(
                labelText: 'What for?',
                hintText: 'e.g. Drink water, Stretch, Walk',
                labelStyle: TextStyle(color: c.textMuted),
                hintStyle: TextStyle(color: c.textMuted.withValues(alpha: 0.6)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: c.accent)),
              ),
            ),
            const SizedBox(height: 18),
            Text('REMIND ME EVERY',
                style: TextStyle(
                    color: c.textMuted, fontSize: 10, letterSpacing: 1.4)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in ReminderScheduler.intervalOptions)
                  _chip(context, formatInterval(m), _minutes == m && _custom.text.isEmpty,
                      () {
                    setState(() {
                      _minutes = m;
                      _custom.clear();
                    });
                  }),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _custom,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: c.textPrimary),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Custom (minutes)',
                labelStyle: TextStyle(color: c.textMuted),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: c.accent)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: c.textMuted))),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: c.accent, foregroundColor: Colors.white),
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, bool selected, VoidCallback onTap) {
    final c = context.movara;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.accent : c.surface2,
          border: Border.all(color: selected ? c.accent : c.border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: AppTheme.display(
                color: selected ? Colors.white : c.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
