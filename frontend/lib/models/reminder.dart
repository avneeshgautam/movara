import 'dart:convert';

/// One repeating reminder: a label, how often it repeats, whether it is on,
/// and when it is next due (used for web catch-up).
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
  });

  final String id;
  final int notifId;
  final String label;
  final int intervalMinutes;
  final bool enabled;
  final DateTime? nextDue;

  Reminder copyWith({
    String? label,
    int? intervalMinutes,
    bool? enabled,
    DateTime? nextDue,
    bool clearNextDue = false,
  }) {
    return Reminder(
      id: id,
      notifId: notifId,
      label: label ?? this.label,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      enabled: enabled ?? this.enabled,
      nextDue: clearNextDue ? null : (nextDue ?? this.nextDue),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'notifId': notifId,
        'label': label,
        'intervalMinutes': intervalMinutes,
        'enabled': enabled,
        'nextDueMs': nextDue?.millisecondsSinceEpoch,
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
