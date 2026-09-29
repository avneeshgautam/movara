import 'dart:convert';

/// One repeating reminder: a label, how often it repeats, the hours of the day
/// it may fire in, whether it is on, and when it is next due (used for web
/// catch-up).
///
/// [notifId] is a small stable integer that namespaces this reminder's OS
/// notifications, so cancelling or rescheduling one reminder never disturbs
/// another.
class Reminder {
  Reminder({
    required this.id,
    required this.notifId,
    required this.label,
    required this.intervalMinutes,
    this.enabled = true,
    this.nextDue,
    this.startMinute = defaultStartMinute,
    this.endMinute = defaultEndMinute,
  });

  /// Default active hours, 7:00 AM to 11:00 PM -- no reminders overnight.
  static const defaultStartMinute = 7 * 60;
  static const defaultEndMinute = 23 * 60;

  final String id;
  final int notifId;
  final String label;
  final int intervalMinutes;
  final bool enabled;
  final DateTime? nextDue;

  /// Active hours as minutes after midnight, inclusive. A window may wrap past
  /// midnight (e.g. 22:00-06:00); start == end means all day.
  final int startMinute;
  final int endMinute;

  bool get isAllDay => startMinute == endMinute;

  /// Whether [t] falls inside this reminder's active hours.
  bool isActiveAt(DateTime t) {
    if (isAllDay) return true;
    final m = t.hour * 60 + t.minute;
    return startMinute <= endMinute
        ? m >= startMinute && m <= endMinute
        : m >= startMinute || m <= endMinute; // wraps past midnight
  }

  /// The next [count] times this reminder should fire after [from]: every
  /// [intervalMinutes], skipping anything outside the active hours. When a
  /// step lands outside them, the next reminder fires as the window opens.
  List<DateTime> upcomingTimes(DateTime from, int count) {
    final out = <DateTime>[];
    var t = from.add(Duration(minutes: intervalMinutes));
    // Bounded: even a 1-minute interval finds a window within a day.
    for (var guard = 0; out.length < count && guard < count + 2000; guard++) {
      if (isActiveAt(t)) {
        out.add(t);
        t = t.add(Duration(minutes: intervalMinutes));
      } else {
        t = _nextWindowStart(t);
      }
    }
    return out;
  }

  DateTime _nextWindowStart(DateTime t) {
    final start =
        DateTime(t.year, t.month, t.day, startMinute ~/ 60, startMinute % 60);
    return start.isAfter(t) ? start : start.add(const Duration(days: 1));
  }

  Reminder copyWith({
    String? label,
    int? intervalMinutes,
    bool? enabled,
    DateTime? nextDue,
    bool clearNextDue = false,
    int? startMinute,
    int? endMinute,
  }) {
    return Reminder(
      id: id,
      notifId: notifId,
      label: label ?? this.label,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      enabled: enabled ?? this.enabled,
      nextDue: clearNextDue ? null : (nextDue ?? this.nextDue),
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'notifId': notifId,
        'label': label,
        'intervalMinutes': intervalMinutes,
        'enabled': enabled,
        'nextDueMs': nextDue?.millisecondsSinceEpoch,
        'startMin': startMinute,
        'endMin': endMinute,
      };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'] as String,
        notifId: json['notifId'] as int,
        label: json['label'] as String,
        intervalMinutes: json['intervalMinutes'] as int,
        enabled: json['enabled'] as bool? ?? true,
        nextDue: json['nextDueMs'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(json['nextDueMs'] as int),
        // Reminders saved before active hours existed get the default window.
        startMinute: json['startMin'] as int? ?? defaultStartMinute,
        endMinute: json['endMin'] as int? ?? defaultEndMinute,
      );

  static String encode(List<Reminder> reminders) =>
      jsonEncode(reminders.map((r) => r.toJson()).toList());

  static List<Reminder> decode(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Reminder.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
