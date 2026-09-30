import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/run_record.dart';
import '../models/workout_entry.dart';
import '../services/api_service.dart';
import '../services/badges.dart';
import '../services/health_service.dart';
import '../services/motivation_reminders.dart';
import '../services/run_store.dart';
import '../services/workout_log.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';
import '../widgets/badges_grid.dart';

/// Profile / account screen.
///
/// Workout counts and personal records come from real logged entries. Body
/// stats and toggles are editable and persisted on the device. Menu rows that
/// map to a real feature act on it (Edit Goals, Water Reminders, Privacy,
/// About, Sign Out); the rest open a "coming soon" note. Daily Goals and
/// Badges are still design placeholders until they have a data source.
class AccountTab extends StatefulWidget {
  const AccountTab({
    super.key,
    required this.api,
    required this.entriesFuture,
    required this.runStore,
    required this.workoutLog,
    this.onOpenTab,
    this.displayName = 'Athlete',
    this.email,
    this.photoUrl,
    this.onSignOut,
    this.onNameChanged,
    this.onOpenUpgrade,
  });

  final ApiService api;
  final Future<List<WorkoutEntry>> entriesFuture;
  final RunStore runStore;
  final WorkoutLog workoutLog;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final Future<void> Function()? onSignOut;

  /// Told when the public name changes, so the header greeting follows it.
  final ValueChanged<String>? onNameChanged;

  /// Opens the Movara Pro upgrade screen.
  final VoidCallback? onOpenUpgrade;

  /// Switches the shell to another bottom tab (0=Home,1=Workout,3=Reminders).
  final void Function(int index)? onOpenTab;

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  /// The one name shown everywhere: the unique public name (username) once
  /// set, otherwise the sign-in name.
  String get _name {
    final chosen = _usernameController.text.trim();
    return chosen.isNotEmpty ? chosen : widget.displayName;
  }

  /// Short free-text status shown under the name and on the leaderboard.
  String _status = '';
  String get _handle => widget.email ?? 'Signed in';

  final _usernameController = TextEditingController();

  /// The tier badge shown in the hero, decided by how the user ranks against
  /// everyone else on the leaderboard. Empty until it loads.
  String _badge = '';

  /// Gym motivation times, minutes after midnight.
  int _morningMin = MotivationReminders.defaultMorningMinute;
  int _eveningMin = MotivationReminders.defaultEveningMinute;

  /// The photo others see: an uploaded one ([_photoCustom]) or the sign-in
  /// photo. Starts as the sign-in photo until the server profile loads.
  late String? _photoUrl = widget.photoUrl;
  bool _photoCustom = false;
  bool _photoBusy = false;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadBody();
    _loadToggles();
    _loadBadge();
    _loadMotivationTimes();
  }

  Future<void> _loadMotivationTimes() async {
    final t = await MotivationReminders.times();
    if (!mounted) return;
    setState(() {
      _morningMin = t.morning;
      _eveningMin = t.evening;
    });
  }

  String _clock(int minute) => MaterialLocalizations.of(context)
      .formatTimeOfDay(TimeOfDay(hour: minute ~/ 60, minute: minute % 60));

  /// Pick the morning and evening motivation times; reschedules right away
  /// when Gym Motivation is on.
  Future<void> _editMotivationTimes() async {
    final picked = await showDialog<({int morning, int evening})>(
      context: context,
      builder: (_) => _MotivationTimesDialog(
          morning: _morningMin, evening: _eveningMin),
    );
    if (picked == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await MotivationReminders.saveTimes(
        morning: picked.morning, evening: picked.evening);
    setState(() {
      _morningMin = picked.morning;
      _eveningMin = picked.evening;
    });
    if (_toggles['Gym Motivation'] ?? false) {
      await MotivationReminders(widget.api).enable();
    }
    messenger.showSnackBar(SnackBar(
      content: Text('Motivation times: ${_clock(picked.morning)} wake-up & '
          '${_clock(picked.evening)} gym.'),
    ));
  }

  /// Trend/percentile logic: compare the user's leaderboard rank against the
  /// field. Top third → Pro Athlete, middle → Athlete, rest → Rising.
  Future<void> _loadBadge() async {
    try {
      final board = await widget.api.fetchLeaderboard();
      final me = board.where((e) => e.isMe).toList();
      String badge;
      if (me.isEmpty) {
        badge = '🌱 RISING';
      } else if (board.length < 3) {
        badge = '💪 ATHLETE'; // too few peers to rank meaningfully
      } else {
        final pct = me.first.rank / board.length; // rank 1 = strongest
        badge = pct <= 0.34
            ? '🔥 PRO ATHLETE'
            : pct <= 0.67
                ? '💪 ATHLETE'
                : '🌱 RISING';
      }
      if (mounted) setState(() => _badge = badge);
    } catch (_) {
      if (mounted) setState(() => _badge = '🌱 RISING');
    }
  }

  Future<void> _loadToggles() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final key in _toggles.keys.toList()) {
        final v = prefs.getBool('toggle_$key');
        if (v != null) _toggles[key] = v;
      }
    });
  }

  Future<void> _setToggle(String key, bool value) async {
    setState(() => _toggles[key] = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('toggle_$key', value);
    if (key == 'Gym Motivation') await _applyGymMotivation(value);
  }

  /// Schedules (or cancels) the daily 6am wake-up and 5pm gym notifications.
  Future<void> _applyGymMotivation(bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    final reminders = MotivationReminders(widget.api);

    Future<void> revert(String message) async {
      if (mounted) setState(() => _toggles['Gym Motivation'] = false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('toggle_Gym Motivation', false);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }

    if (!reminders.isSupported) {
      if (on) {
        await revert('Motivation reminders work in the iPhone app, not the web.');
      }
      return;
    }
    if (on) {
      final status = await reminders.requestPermission();
      if (status != 'granted') {
        await revert('Allow notifications to get motivation reminders.');
        return;
      }
      await reminders.enable();
      messenger.showSnackBar(SnackBar(
        content: Text('Motivation set: ${_clock(_morningMin)} wake-up & '
            '${_clock(_eveningMin)} gym. 💪'),
      ));
    } else {
      await reminders.disable();
    }
  }

  Future<void> _loadBody() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final key in _body.keys.toList()) {
        final v = prefs.getDouble('body_$key');
        if (v != null) _body[key] = v;
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadUsername() async {
    try {
      final me = await widget.api.fetchMyProfile();
      if (!mounted) return;
      setState(() {
        // Only prefill if the user hasn't already started typing.
        if (_usernameController.text.isEmpty) {
          _usernameController.text = me.username ?? '';
        }
        _status = me.status ?? '';
        if (me.photoCustom && me.photoUrl != null) {
          _photoUrl = me.photoUrl;
          _photoCustom = true;
        }
      });
    } catch (_) {
      // Prefill is best-effort; the field is editable regardless.
    }
  }

  /// The first letter of the name, shown when there's no photo.
  Widget _initial(MovaraColors c) => Text(
        _name.isEmpty ? '?' : _name[0].toUpperCase(),
        style: AppTheme.display(
          color: c.accent,
          fontSize: 30,
          fontWeight: FontWeight.w800,
        ),
      );

  /// Pick, take, or remove the profile photo shown on the leaderboard/feed.
  Future<void> _changePhoto(BuildContext context) async {
    if (_photoBusy) return;
    final c = context.movara;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: c.accent),
              title: Text('Choose from photos',
                  style: TextStyle(color: c.textPrimary)),
              onTap: () => Navigator.pop(sheet, 'gallery'),
            ),
            if (!kIsWeb)
              ListTile(
                leading: Icon(Icons.photo_camera_outlined, color: c.accent),
                title: Text('Take a photo',
                    style: TextStyle(color: c.textPrimary)),
                onTap: () => Navigator.pop(sheet, 'camera'),
              ),
            if (_photoCustom)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: Color(0xFFEF4444)),
                title: const Text('Remove photo',
                    style: TextStyle(color: Color(0xFFEF4444))),
                subtitle: Text('Go back to your Google photo',
                    style: TextStyle(color: c.textMuted, fontSize: 12)),
                onTap: () => Navigator.pop(sheet, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(this.context);

    if (action == 'remove') {
      setState(() => _photoBusy = true);
      try {
        await widget.api.removeProfilePhoto();
        // Put the sign-in photo back straight away rather than next launch.
        await widget.api
            .upsertProfile(widget.displayName, photoUrl: widget.photoUrl);
        if (mounted) {
          setState(() {
            _photoUrl = widget.photoUrl;
            _photoCustom = false;
          });
        }
        messenger.showSnackBar(
            const SnackBar(content: Text('Photo removed.')));
      } catch (_) {
        messenger.showSnackBar(const SnackBar(
            content: Text("Couldn't remove the photo. Try again.")));
      } finally {
        if (mounted) setState(() => _photoBusy = false);
      }
      return;
    }

    final XFile? picked;
    try {
      // Resized and re-encoded on device: small upload, and HEIC becomes JPEG.
      picked = await ImagePicker().pickImage(
        source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Allow photo access in Settings to choose a photo.')));
      return;
    }
    if (picked == null || !mounted) return;

    setState(() => _photoBusy = true);
    try {
      final url =
          await widget.api.uploadProfilePhoto(await picked.readAsBytes());
      if (mounted) {
        setState(() {
          _photoUrl = url;
          _photoCustom = true;
        });
      }
      messenger.showSnackBar(
          const SnackBar(content: Text('Profile photo updated. 📸')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text("Couldn't upload the photo. Try again.")));
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  /// Opens Edit profile (photo, name, status). The name is the single public
  /// name — unique, shown in the app and on the leaderboard.
  Future<void> _editProfile(BuildContext context) async {
    final saved = await Navigator.of(context).push<({String name, String status})>(
      MaterialPageRoute(
        builder: (_) => _EditProfilePage(
          api: widget.api,
          signInName: widget.displayName,
          signInPhotoUrl: widget.photoUrl,
          name: _name,
          status: _status,
          photoUrl: () => _photoUrl,
          onChangePhoto: (pageContext) => _changePhoto(pageContext),
        ),
      ),
    );
    if (saved == null || !mounted) return;
    setState(() {
      _usernameController.text = saved.name;
      _status = saved.status;
    });
    widget.onNameChanged?.call(saved.name);
    ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')));
  }

  // Persisted per-device (see _loadBody / _editBody).
  final Map<String, double> _body = {
    'Weight': 70,
    'Height': 170,
    'Body Fat': 18,
    'Muscle Mass': 55,
    'Resting HR': 62,
  };

  final Map<String, bool> _toggles = {
    'Notifications': true,
    'Sleep Tracking': false,
    'Gym Motivation': false,
  };

  double get _bmi {
    final h = (_body['Height'] ?? 0) / 100;
    if (h <= 0) return 0;
    return (_body['Weight'] ?? 0) / (h * h);
  }

  String get _bmiTag {
    final b = _bmi;
    if (b < 18.5) return 'Under';
    if (b < 25) return 'Normal';
    if (b < 30) return 'Over';
    return 'High';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return FutureBuilder<List<WorkoutEntry>>(
      future: widget.entriesFuture,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <WorkoutEntry>[];
        final summary = _Summary.from(entries);

        return Container(
          color: c.bg,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _hero(context, summary),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _title('Body Stats'),
                    _bodyStats(context),
                    const SizedBox(height: 22),
                    _title('Daily Goals'),
                    _goals(context),
                    const SizedBox(height: 22),
                    _title('Personal Records 🏆'),
                    _records(context, summary.records),
                    const SizedBox(height: 22),
                    _title('Badges'),
                    _badges(context),
                    const SizedBox(height: 22),
                    ..._menu(context),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Movara v1.0.0 · Built with 🔥',
                        style: TextStyle(color: c.textMuted, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  // ── Hero ──────────────────────────────────────────────────────────

  Widget _hero(BuildContext context, _Summary s) {
    final c = context.movara;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.surface, c.bg],
        ),
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                key: const ValueKey('profile-photo'),
                onTap: () => _changePhoto(context),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.accentSoft,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.accent, width: 3),
                          boxShadow: [
                            BoxShadow(color: c.accentGlow, blurRadius: 20),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _photoUrl != null
                            ? Image.network(
                                _photoUrl!,
                                width: 76,
                                height: 76,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _initial(c),
                              )
                            : _initial(c),
                      ),
                      if (_photoBusy)
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            ),
                          ),
                        ),
                      // Camera badge: signals the photo can be changed.
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: c.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.surface, width: 2),
                          ),
                          child: const Icon(Icons.photo_camera,
                              size: 13, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      style: AppTheme.display(
                        color: c.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(_handle,
                        style: TextStyle(color: c.textMuted, fontSize: 11)),
                    if (_status.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _status,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (_badge.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.accentSoft,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: c.accent.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              _badge,
                              style: AppTheme.display(
                                color: c.accent,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                        GestureDetector(
                          key: const ValueKey('edit-profile'),
                          onTap: () => _editProfile(context),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: c.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, size: 11, color: c.accent),
                                const SizedBox(width: 4),
                                Text(
                                  'Edit profile',
                                  style: AppTheme.display(
                                    color: c.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              // Real: derived from logged entries.
              _quickStat(context, '🏋️', '${s.workoutDays}', 'Workouts'),
              const SizedBox(width: 8),
              _quickStat(context, '📅', '${s.thisMonthDays}', 'This Month'),
              const SizedBox(width: 8),
              // TODO: no duration/calorie source yet.
              _quickStat(context, '📈', '${s.totalSets}', 'Total Sets'),
              const SizedBox(width: 8),
              _quickStat(context, '🏅', '${s.prCount}', 'PRs'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickStat(
      BuildContext context, String icon, String value, String label) {
    final c = context.movara;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTheme.display(
                color: c.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted, fontSize: 9, height: 1.1),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sections ──────────────────────────────────────────────────────

  Widget _title(String text) {
    final c = context.movara;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: AppTheme.display(
          color: c.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
        ),
      ),
    );
  }

  Widget _panel(BuildContext context, List<Widget> rows) {
    final c = context.movara;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: rows),
    );
  }

  Widget _bodyStats(BuildContext context) {
    final rows = <Widget>[];
    final specs = <({String label, String unit, bool editable})>[
      (label: 'Weight', unit: 'kg', editable: true),
      (label: 'Height', unit: 'cm', editable: true),
      (label: 'BMI', unit: '', editable: false),
      (label: 'Body Fat', unit: '%', editable: true),
      (label: 'Muscle Mass', unit: 'kg', editable: true),
      (label: 'Resting HR', unit: 'bpm', editable: true),
    ];

    for (var i = 0; i < specs.length; i++) {
      final s = specs[i];
      // BMI is computed from weight + height rather than stored.
      final value = s.label == 'BMI' ? _bmi : (_body[s.label] ?? 0);
      rows.add(_bodyRow(
        context,
        label: s.label,
        value: value,
        unit: s.unit,
        editable: s.editable,
        tag: s.label == 'BMI' ? _bmiTag : null,
        striped: i.isOdd,
      ));
    }
    return _panel(context, rows);
  }

  Widget _bodyRow(
    BuildContext context, {
    required String label,
    required double value,
    required String unit,
    required bool editable,
    String? tag,
    required bool striped,
  }) {
    final c = context.movara;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: striped ? c.surface2 : c.surface,
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(color: c.textSecondary, fontSize: 14)),
          ),
          if (tag != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: c.greenSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tag,
                style: TextStyle(
                    color: c.green, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: editable ? () => _editBody(label, value) : null,
            child: Container(
              decoration: editable
                  ? BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: c.textMuted, width: 1),
                      ),
                    )
                  : null,
              child: RichText(
                text: TextSpan(
                  text: _fmt(value),
                  style: AppTheme.display(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  children: [
                    if (unit.isNotEmpty)
                      TextSpan(
                        text: ' $unit',
                        style: TextStyle(
                            color: c.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w400),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editBody(String label, double current) async {
    final c = context.movara;
    final controller = TextEditingController(text: _fmt(current));
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(label,
            style: AppTheme.display(color: c.textPrimary, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(
                context, double.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      setState(() => _body[label] = result);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('body_$label', result);
    }
  }


  Widget _goals(BuildContext context) {
    final c = context.movara;
    final goals =
        <({String label, double current, double target, String unit, Color color})>[
      (label: 'Daily Steps', current: 7200, target: 10000, unit: 'steps', color: c.accent),
      (label: 'Weekly Workouts', current: 4, target: 5, unit: 'sessions', color: c.green),
      (label: 'Water Intake', current: 1.8, target: 2.5, unit: 'L', color: c.blue),
      (label: 'Sleep', current: 6.5, target: 8, unit: 'hrs', color: const Color(0xFFA78BFA)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (var i = 0; i < goals.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _goalBar(context, goals[i].label, goals[i].current, goals[i].target,
                goals[i].unit, goals[i].color),
          ],
        ],
      ),
    );
  }

  Widget _goalBar(BuildContext context, String label, double current,
      double target, String unit, Color color) {
    final c = context.movara;
    final pct = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: c.textSecondary, fontSize: 13)),
            Text('${_fmt(current)} / ${_fmt(target)} $unit',
                style: AppTheme.display(
                    color: c.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: c.surface3,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  Widget _badges(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.runStore, widget.workoutLog]),
      builder: (context, _) {
        final types =
            widget.runStore.runs.map((r) => r.activityType).toSet();
        final badges = computeBadges(BadgeStats(
          workoutCount: widget.workoutLog.totalCount,
          longestWorkoutSeconds: widget.workoutLog.longestSeconds,
          workoutStreakDays: widget.workoutLog.streakDays,
          workoutsThisWeek: widget.workoutLog.countThisWeek(),
          totalKm: widget.runStore.totalKmAllTime,
          longestRunKm: widget.runStore.longestRun?.distanceKm ?? 0,
          runCount: widget.runStore.runs.length,
          stepsThisWeek: widget.runStore.stepsThisWeek(),
          activityTypes: types.length,
        ));
        return BadgesGrid(badges: badges);
      },
    );
  }

  Widget _records(BuildContext context, List<_Record> records) {
    final c = context.movara;

    if (records.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text('🏆', style: TextStyle(fontSize: 26, color: c.textMuted)),
            const SizedBox(height: 10),
            Text('No records yet',
                style: AppTheme.display(color: c.textPrimary, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              'Log a set with a weight to set your first PR.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.9,
      children: [
        for (final r in records)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  r.exercise.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.display(
                    color: c.textMuted,
                    fontSize: 9,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  r.value,
                  style: AppTheme.display(
                    color: c.accent,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text('Set ${r.date}',
                    style: TextStyle(color: c.textMuted, fontSize: 10)),
              ],
            ),
          ),
      ],
    );
  }


  List<Widget> _menu(BuildContext context) {
    final sections = <({String title, List<_MenuAction> items})>[
      (
        title: 'Preferences',
        items: [
          _MenuAction('🎯', 'Edit Goals', onTap: () => widget.onOpenTab?.call(0)),
          _MenuAction('📊', 'Progress History',
              onTap: () => widget.onOpenTab?.call(1)),
          _MenuAction('🔔', 'Notifications', toggleKey: 'Notifications'),
          _MenuAction('📏', 'Units (Metric)',
              onTap: () => _comingSoon(context, 'Imperial units')),
        ],
      ),
      (
        title: 'Health',
        items: [
          _MenuAction('🔗', 'Connected Apps',
              onTap: () => _showConnectedApps(context)),
          _MenuAction('❤️', 'Heart Rate Zones',
              onTap: () => _comingSoon(context, 'Heart rate zones')),
          _MenuAction('🩺', 'Health Metrics',
              onTap: () => _comingSoon(context, 'Health metrics')),
          _MenuAction('🏋️', 'Gym Motivation',
              subtitle: '${_clock(_morningMin)} & ${_clock(_eveningMin)} · '
                  'tap to change',
              toggleKey: 'Gym Motivation',
              onTap: _editMotivationTimes),
          _MenuAction('😴', 'Sleep Tracking', toggleKey: 'Sleep Tracking'),
        ],
      ),
      (
        title: 'Account',
        items: [
          _MenuAction('⚡', 'Movara Pro',
              subtitle: 'Subscription · coming soon',
              onTap: widget.onOpenUpgrade),
          _MenuAction('💧', 'Water Reminders',
              onTap: () => widget.onOpenTab?.call(3)),
          _MenuAction('🔒', 'Privacy', onTap: () => _showPrivacy(context)),
          _MenuAction('⬇️', 'Download App',
              onTap: () => _showDownloadApp(context)),
          _MenuAction('ℹ️', 'About Movara', onTap: () => _showAbout(context)),
          _MenuAction('🚪', 'Sign Out',
              onTap: () => widget.onSignOut?.call(), danger: true),
        ],
      ),
    ];

    final widgets = <Widget>[];
    for (final section in sections) {
      widgets.add(_title(section.title));
      widgets.add(_panel(context, [
        for (var i = 0; i < section.items.length; i++)
          _menuRow(context, section.items[i], divider: i > 0),
      ]));
      widgets.add(const SizedBox(height: 22));
    }
    return widgets;
  }

  Widget _menuRow(BuildContext context, _MenuAction item,
      {required bool divider}) {
    final c = context.movara;
    final key = item.toggleKey;
    final isToggle = key != null;
    return Container(
      decoration: divider
          ? BoxDecoration(border: Border(top: BorderSide(color: c.border)))
          : null,
      child: InkWell(
        onTap: item.onTap ??
            (isToggle ? () => _setToggle(key, !(_toggles[key] ?? false)) : null),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(item.icon,
                    style: const TextStyle(fontSize: 15),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label,
                        style: TextStyle(
                          color: item.danger
                              ? const Color(0xFFEF4444)
                              : c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        )),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(item.subtitle!,
                          style: TextStyle(color: c.textMuted, fontSize: 11)),
                    ],
                  ],
                ),
              ),
              if (isToggle)
                _switch(context, _toggles[key] ?? false,
                    () => _setToggle(key, !(_toggles[key] ?? false)))
              else if (!item.danger)
                Icon(Icons.chevron_right, size: 18, color: c.textMuted),
            ],
          ),
        ),
      ),
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
                    color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _comingSoon(BuildContext context, String feature) async {
    final c = context.movara;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(feature,
            style: AppTheme.display(color: c.textPrimary, fontSize: 18)),
        content: Text(
          '$feature is on the roadmap and not available yet. It will show up '
          'here once it is built.',
          style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: TextStyle(color: c.accent))),
        ],
      ),
    );
  }

  /// The list of health/fitness sources. Apple Health is the working hub;
  /// other watches (like Noise) feed in through it; direct integrations are
  /// on the roadmap.
  Future<void> _showConnectedApps(BuildContext context) async {
    final c = context.movara;
    final appleSub = HealthService.instance.isSupported
        ? 'Apple Watch, heart rate & steps'
        : 'iPhone app only';
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Connected apps',
            style: AppTheme.display(color: c.textPrimary, fontSize: 18)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _downloadRow(context,
                    icon: '⌚',
                    label: 'Apple Health',
                    sub: appleSub,
                    onTap: () {
                      Navigator.pop(context);
                      _connectAppleHealth(context);
                    }),
                const SizedBox(height: 8),
                _downloadRow(context,
                    icon: '⌚',
                    label: 'NoiseFit (Noise)',
                    sub: 'Syncs via Apple Health',
                    onTap: () {
                      Navigator.pop(context);
                      _showNoiseFitHelp(context);
                    }),
                const SizedBox(height: 8),
                _downloadRow(context,
                    icon: '💪', label: 'Google Fit', sub: 'Coming soon'),
                const SizedBox(height: 8),
                _downloadRow(context,
                    icon: '🚴', label: 'Strava', sub: 'Coming soon'),
                const SizedBox(height: 8),
                _downloadRow(context,
                    icon: '⌚', label: 'Fitbit', sub: 'Coming soon'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: c.accent))),
        ],
      ),
    );
  }

  /// How to get a Noise watch's data into Movara (there is no direct NoiseFit
  /// login — it routes through Apple Health).
  Future<void> _showNoiseFitHelp(BuildContext context) async {
    final c = context.movara;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('NoiseFit (Noise)',
            style: AppTheme.display(color: c.textPrimary, fontSize: 18)),
        content: Text(
          'Noise watches sync through the NoiseFit app, which shares data with '
          'Apple Health. To bring it into Movara:\n\n'
          '1. Open NoiseFit → Profile → Apple Health (or Health permissions).\n'
          '2. Turn on Steps and Heart Rate.\n'
          '3. Come back and connect Apple Health here.\n\n'
          'Movara then reads that shared data — a direct NoiseFit login is not '
          'available yet.',
          style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                _connectAppleHealth(context);
              },
              child: Text('Connect Apple Health',
                  style: TextStyle(color: c.accent))),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: TextStyle(color: c.textMuted))),
        ],
      ),
    );
  }

  /// Requests Apple Health access so heart rate and steps from the Apple
  /// Watch flow into activities. The connection lives in Apple Health — the
  /// watch writes to Health and Movara reads it.
  Future<void> _connectAppleHealth(BuildContext context) async {
    final c = context.movara;
    if (!HealthService.instance.isSupported) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Apple Watch & Health',
              style: AppTheme.display(color: c.textPrimary, fontSize: 18)),
          content: Text(
            'Apple Health lives on your iPhone. Open Movara on the iPhone app '
            'to connect your Apple Watch — it is not available in the web app.',
            style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: TextStyle(color: c.accent))),
          ],
        ),
      );
      return;
    }

    final granted = await HealthService.instance.requestPermission();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('health_connected', granted);

    // Prove the read actually works by pulling today's steps right now.
    int? stepsToday;
    if (granted) {
      final now = DateTime.now();
      stepsToday = await HealthService.instance
          .steps(DateTime(now.year, now.month, now.day), now);
    }
    if (!context.mounted) return;

    final String title;
    final String message;
    if (!granted) {
      title = 'Health access needed';
      message =
          'Movara could not read Apple Health. Turn it on in the iPhone '
          'Settings › Health › Data Access & Devices › Movara, then try again.';
    } else if (stepsToday != null && stepsToday > 0) {
      title = 'Apple Health connected';
      message =
          'Read ${formatSteps(stepsToday)} steps from Apple Health today. '
          'Your steps and heart rate will now show on Home and your activities.';
    } else {
      title = 'Connected, but no steps yet';
      message =
          'Movara is connected but Apple Health returned no steps. Check:\n\n'
          '1. iPhone Settings › Health › Data Access & Devices › Movara — '
          'turn ON Steps and Heart Rate.\n'
          '2. In NoiseFit › Profile › Apple Health, turn ON Steps so your '
          'Noise watch writes to Health.\n\n'
          'Then reopen Home.';
    }

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: AppTheme.display(color: c.textPrimary, fontSize: 18)),
        content: Text(
          message,
          style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          if (stepsToday == null || stepsToday == 0)
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Opens the Health app; Profile → Apps → Movara has the
                  // Steps read toggle. Bypasses canLaunchUrl since the custom
                  // scheme need not be in LSApplicationQueriesSchemes to open.
                  launchUrl(Uri.parse('x-apple-health://'),
                          mode: LaunchMode.externalApplication)
                      .catchError((_) => false);
                },
                child: Text('Open Apple Health',
                    style: TextStyle(color: c.accent))),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: TextStyle(color: c.textMuted))),
        ],
      ),
    );
  }

  /// Where to get the app: the Android APK now, the stores later.
  Future<void> _showDownloadApp(BuildContext context) async {
    final c = context.movara;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Download Movara',
            style: AppTheme.display(color: c.textPrimary, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _downloadRow(context,
                icon: '🌐',
                label: 'Open the web app',
                sub: 'Works now — any device',
                onTap: () {
                  Navigator.pop(context);
                  _launch(_webUrl);
                }),
            const SizedBox(height: 8),
            _downloadRow(context,
                icon: '🤖',
                label: 'Android APK',
                sub: 'Download, then allow "install unknown apps"',
                onTap: () {
                  Navigator.pop(context);
                  _launch(_apkUrl);
                }),
            const SizedBox(height: 8),
            _downloadRow(context,
                icon: '▶️', label: 'Google Play', sub: 'Coming soon'),
            const SizedBox(height: 8),
            _downloadRow(context,
                icon: '', label: 'App Store', sub: 'Coming soon'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: c.accent))),
        ],
      ),
    );
  }

  Widget _downloadRow(BuildContext context,
      {required String icon,
      required String label,
      required String sub,
      VoidCallback? onTap}) {
    final c = context.movara;
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: c.surface2,
            border: Border.all(
                color: enabled ? c.accent.withValues(alpha: 0.4) : c.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(icon.isEmpty ? '🍎' : icon,
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppTheme.display(
                            color: c.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text(sub,
                        style: TextStyle(color: c.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              if (enabled)
                Icon(Icons.download, size: 18, color: c.accent)
              else
                Icon(Icons.hourglass_empty, size: 16, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  static const _webUrl = 'https://movara-app.pages.dev';

  /// Rebuilt by CI on every frontend push; this URL always serves the latest.
  static const _apkUrl =
      'https://github.com/avneeshgautam/movara/releases/download/android-latest/movara.apk';

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showPrivacy(BuildContext context) async {
    final c = context.movara;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Privacy & data',
            style: AppTheme.display(color: c.textPrimary, fontSize: 18)),
        content: Text(
          'Your workouts and runs are tied to your account and only you can '
          'see your own data. On the leaderboard, others see only your chosen '
          'username (or first name) and your weekly totals — never your '
          'individual entries. Body stats stay on this device. Sign-in is '
          'handled by Google; Movara never sees your password.',
          style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Got it', style: TextStyle(color: c.accent))),
        ],
      ),
    );
  }

  Future<void> _showAbout(BuildContext context) async {
    final c = context.movara;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Movara',
            style: AppTheme.display(color: c.accent, fontSize: 20)),
        content: Text(
          'Movara v1.0.0\n\nTrack workouts and runs, share your route, and '
          'stay on the leaderboard. Built with 🔥.',
          style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: c.accent))),
        ],
      ),
    );
  }
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

class _MenuAction {
  _MenuAction(this.icon, this.label,
      {this.onTap, this.danger = false, this.toggleKey, this.subtitle});
  final String icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;
  final String? toggleKey;
  final String? subtitle;
}

/// Edit profile: photo, the single public name (unique), and a short status.
class _EditProfilePage extends StatefulWidget {
  const _EditProfilePage({
    required this.api,
    required this.signInName,
    required this.signInPhotoUrl,
    required this.name,
    required this.status,
    required this.photoUrl,
    required this.onChangePhoto,
  });

  final ApiService api;
  final String signInName;
  final String? signInPhotoUrl;
  final String name;
  final String status;

  /// Current photo, read live so the preview follows a change.
  final String? Function() photoUrl;
  final Future<void> Function(BuildContext) onChangePhoto;

  @override
  State<_EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<_EditProfilePage> {
  late final _name = TextEditingController(text: widget.name);
  late final _status = TextEditingController(text: widget.status);
  String? _nameError;
  bool _busy = false;

  static const maxName = 40;
  static const maxStatus = 100;

  @override
  void dispose() {
    _name.dispose();
    _status.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final status = _status.text.trim();
    if (name.length < 2) {
      setState(() => _nameError = 'Use at least 2 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _nameError = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Friendlier message before writing; the server enforces it anyway.
      final renamed = name.toLowerCase() != widget.name.toLowerCase();
      if (renamed && !await widget.api.isUsernameAvailable(name)) {
        setState(() {
          _busy = false;
          _nameError = 'That name is taken — try another.';
        });
        return;
      }
      await widget.api.upsertProfile(
        widget.signInName,
        photoUrl: widget.signInPhotoUrl,
        username: name,
        status: status,
        strict: true,
      );
      if (mounted) Navigator.pop(context, (name: name, status: status));
    } on UsernameTaken {
      setState(() {
        _busy = false;
        _nameError = 'That name is taken — try another.';
      });
    } catch (_) {
      setState(() => _busy = false);
      messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't save. Try again.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final photo = widget.photoUrl();
    final initial = _name.text.trim().isEmpty
        ? '?'
        : _name.text.trim()[0].toUpperCase();

    InputDecoration field(String label, String hint, {String? error}) =>
        InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: error,
          labelStyle: TextStyle(color: c.textMuted),
          hintStyle: TextStyle(color: c.textMuted.withValues(alpha: 0.6)),
          counterStyle: TextStyle(color: c.textMuted, fontSize: 10),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: c.accent)),
        );

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text('Edit profile',
            style: AppTheme.display(color: c.textPrimary, fontSize: 18)),
        actions: [
          TextButton(
            key: const ValueKey('save-profile'),
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save',
                style: AppTheme.display(
                    color: c.accent, fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        children: [
          Center(
            child: GestureDetector(
              onTap: () async {
                await widget.onChangePhoto(context);
                if (mounted) setState(() {}); // pick up the new photo
              },
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.accent, width: 3),
                    ),
                    child: photo != null
                        ? Image.network(photo,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Text(initial,
                                style: AppTheme.display(
                                    color: c.accent, fontSize: 36)))
                        : Text(initial,
                            style:
                                AppTheme.display(color: c.accent, fontSize: 36)),
                  ),
                  const SizedBox(height: 10),
                  Text('Change photo',
                      style: AppTheme.display(
                          color: c.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            key: const ValueKey('profile-name'),
            controller: _name,
            maxLength: maxName,
            textCapitalization: TextCapitalization.none,
            style: TextStyle(color: c.textPrimary, fontSize: 16),
            onChanged: (_) => setState(() => _nameError = null),
            decoration: field('Name', 'e.g. devil', error: _nameError),
          ),
          Text(
            'Your one name in Movara — unique, and shown on the leaderboard.',
            style: TextStyle(color: c.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('profile-status'),
            controller: _status,
            maxLength: maxStatus,
            maxLines: 2,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: c.textPrimary, fontSize: 15),
            decoration:
                field('Status', 'e.g. Training for my first 10K 🏃'),
          ),
          Text(
            'Shown under your name and on the leaderboard. Leave blank to hide.',
            style: TextStyle(color: c.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Morning and evening time pickers for Gym Motivation.
class _MotivationTimesDialog extends StatefulWidget {
  const _MotivationTimesDialog({required this.morning, required this.evening});

  final int morning;
  final int evening;

  @override
  State<_MotivationTimesDialog> createState() => _MotivationTimesDialogState();
}

class _MotivationTimesDialogState extends State<_MotivationTimesDialog> {
  late int _morning = widget.morning;
  late int _evening = widget.evening;

  Future<void> _pick({required bool morning}) async {
    final current = morning ? _morning : _evening;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: morning ? 'MORNING WAKE-UP' : 'EVENING GYM',
    );
    if (picked == null || !mounted) return;
    setState(() {
      final m = picked.hour * 60 + picked.minute;
      if (morning) {
        _morning = m;
      } else {
        _evening = m;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Gym Motivation',
          style: AppTheme.display(color: c.textPrimary, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pick when each daily nudge arrives.',
              style: TextStyle(color: c.textMuted, fontSize: 12)),
          const SizedBox(height: 14),
          _slot(context, '🌅', 'Morning wake-up', _morning, true),
          const SizedBox(height: 10),
          _slot(context, '🏋️', 'Evening gym', _evening, false),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: c.textMuted))),
        ElevatedButton(
          onPressed: () =>
              Navigator.pop(context, (morning: _morning, evening: _evening)),
          style: ElevatedButton.styleFrom(
              backgroundColor: c.accent, foregroundColor: Colors.white),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _slot(BuildContext context, String emoji, String label, int minute,
      bool morning) {
    final c = context.movara;
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay(hour: minute ~/ 60, minute: minute % 60));
    return GestureDetector(
      key: ValueKey('motivation-${morning ? 'morning' : 'evening'}'),
      onTap: () => _pick(morning: morning),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textSecondary, fontSize: 13)),
            ),
            Text(time,
                style: AppTheme.display(
                    color: c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

class _Record {
  const _Record({required this.exercise, required this.value, required this.date});
  final String exercise;
  final String value;
  final String date;
}

/// Figures derived from the real entry list.
class _Summary {
  const _Summary({
    required this.workoutDays,
    required this.thisMonthDays,
    required this.totalSets,
    required this.prCount,
    required this.records,
  });

  /// Distinct days with at least one logged set.
  final int workoutDays;

  /// Distinct days logged in the current calendar month.
  final int thisMonthDays;

  /// Every set ever logged, and how many exercises have a weight PR.
  final int totalSets;
  final int prCount;

  /// Heaviest logged set per exercise, best first.
  final List<_Record> records;

  factory _Summary.from(List<WorkoutEntry> entries) {
    final now = DateTime.now();
    final days = <DateTime>{};
    final best = <String, WorkoutEntry>{};
    var totalSets = 0;

    for (final e in entries) {
      final d = DateTime(
          e.performedAt.year, e.performedAt.month, e.performedAt.day);
      days.add(d);
      totalSets += e.sets;

      final weight = e.weightKg;
      if (weight == null || weight <= 0) continue;
      final current = best[e.exerciseName];
      if (current == null || weight > (current.weightKg ?? 0)) {
        best[e.exerciseName] = e;
      }
    }

    final ranked = best.values.toList()
      ..sort((a, b) => (b.weightKg ?? 0).compareTo(a.weightKg ?? 0));

    return _Summary(
      workoutDays: days.length,
      thisMonthDays: days
          .where((d) => d.year == now.year && d.month == now.month)
          .length,
      totalSets: totalSets,
      prCount: best.length,
      records: ranked
          .take(4)
          .map((e) => _Record(
                exercise: e.exerciseName,
                value: '${_fmt(e.weightKg ?? 0)} kg',
                date: DateFormat.MMMd().format(e.performedAt),
              ))
          .toList(),
    );
  }
}
