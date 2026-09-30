import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

typedef InboxMessage = ({String id, String title, String body, DateTime sentAt});

/// Messages from the Movara team, sent from the local admin dashboard.
///
/// There's no push service yet, so the app checks on launch and whenever it
/// returns to the foreground. [fetchNew] returns only messages this device
/// hasn't shown before, remembering the newest one it has seen.
class Inbox {
  Inbox(this._api);

  final ApiService _api;

  static const _kLastSeen = 'inbox_last_seen';

  Future<List<InboxMessage>> fetchNew() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLastSeen);
    final since = raw == null ? null : DateTime.tryParse(raw);

    final messages = await _api.fetchNotifications(since: since);
    if (messages.isEmpty) return messages;

    final newest = messages
        .map((m) => m.sentAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    await prefs.setString(_kLastSeen, newest.toUtc().toIso8601String());
    return messages;
  }
}
