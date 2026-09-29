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

              if (_suggestions(context) case final chips?) ...[
                const SizedBox(height: 4),
                Text('QUICK ADD',
                    style: TextStyle(
                        color: c.textMuted, fontSize: 10, letterSpacing: 1.6)),
                const SizedBox(height: 10),
                chips,
                const SizedBox(height: 16),
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

  /// One-tap chips for common reminders the user hasn't added yet, or null
  /// when they already have them all.
  Widget? _suggestions(BuildContext context) {
    final c = context.movara;
    final remaining = ReminderScheduler.suggestions
        .where((s) => !scheduler.hasReminderNamed(s.label))
        .toList();
    if (remaining.isEmpty) return null;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in remaining)
          GestureDetector(
            onTap: () => scheduler.addReminder(
                label: s.label, intervalMinutes: s.minutes),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(s.label,
                      style: AppTheme.display(
                          color: c.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 5),
                  Icon(Icons.add, size: 14, color: c.accent),
                ],
              ),
            ),
          ),
      ],
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
          label: result.label,
          intervalMinutes: result.minutes,
          startMinute: result.startMinute,
          endMinute: result.endMinute);
    } else {
      await scheduler.updateReminder(existing.id,
          label: result.label,
          intervalMinutes: result.minutes,
          startMinute: result.startMinute,
          endMinute: result.endMinute);
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
                  Text(
                      'Every ${formatInterval(reminder.intervalMinutes)} · '
                      '${activeHoursLabel(context, reminder.startMinute, reminder.endMinute)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

/// "7:00 AM – 11:00 PM" in the device's 12/24h style, or "All day".
String activeHoursLabel(BuildContext context, int startMinute, int endMinute) {
  if (startMinute == endMinute) return 'All day';
  final l = MaterialLocalizations.of(context);
  String f(int m) =>
      l.formatTimeOfDay(TimeOfDay(hour: m ~/ 60, minute: m % 60));
  return '${f(startMinute)} – ${f(endMinute)}';
}

class _ReminderInput {
  const _ReminderInput(this.label, this.minutes, this.startMinute, this.endMinute);
  final String label;
  final int minutes;
  final int startMinute;
  final int endMinute;
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
  late int _start = widget.existing?.startMinute ?? Reminder.defaultStartMinute;
  late int _end = widget.existing?.endMinute ?? Reminder.defaultEndMinute;
  late bool _allDay = widget.existing?.isAllDay ?? false;

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
    // All day is stored as start == end.
    Navigator.pop(
      context,
      _ReminderInput(_label.text, minutes, _allDay ? 0 : _start,
          _allDay ? 0 : _end),
    );
  }

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: start ? 'REMIND ME FROM' : 'REMIND ME UNTIL',
    );
    if (picked == null || !mounted) return;
    setState(() {
      final m = picked.hour * 60 + picked.minute;
      if (start) {
        _start = m;
      } else {
        _end = m;
      }
      _allDay = false;
    });
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
            const SizedBox(height: 20),
            Row(
              children: [
                // Expanded (not Spacer) so the label yields on narrow phones.
                Expanded(
                  child: Text('ACTIVE HOURS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: c.textMuted,
                          fontSize: 10,
                          letterSpacing: 1.4)),
                ),
                const SizedBox(width: 8),
                _chip(context, 'All day', _allDay,
                    () => setState(() => _allDay = !_allDay)),
              ],
            ),
            const SizedBox(height: 10),
            Opacity(
              opacity: _allDay ? 0.4 : 1,
              child: Row(
                children: [
                  Expanded(child: _timeBox(context, 'From', _start, true)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('–', style: TextStyle(color: c.textMuted)),
                  ),
                  Expanded(child: _timeBox(context, 'To', _end, false)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _allDay
                  ? 'Reminders can arrive at any hour.'
                  : 'No reminders outside these hours.',
              style: TextStyle(color: c.textMuted, fontSize: 11),
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

  Widget _timeBox(BuildContext context, String caption, int minute, bool start) {
    final c = context.movara;
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay(hour: minute ~/ 60, minute: minute % 60));
    return GestureDetector(
      key: ValueKey('hours-$caption'),
      onTap: () => _pickTime(start: start),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(caption,
                style: TextStyle(color: c.textMuted, fontSize: 10)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(time,
                  style: AppTheme.display(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
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
