import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Consistent line-art exercise figures, drawn with a [CustomPainter] so they
/// always render offline and share one visual style across every card.
///
/// Each movement is a pair of skeleton poses (a rep's start and end). The
/// thumbnail shows a fixed mid-rep frame; the demo animates between the two.
///
/// Poses are authored in a normalised 0..100 box (y grows downward) as seven
/// joints plus a head, then scaled to the requested size.

class _Pose {
  const _Pose({
    required this.head,
    required this.shoulder,
    required this.elbow,
    required this.hand,
    required this.hip,
    required this.knee,
    required this.foot,
    this.headR = 7,
  });

  final Offset head, shoulder, elbow, hand, hip, knee, foot;
  final double headR;

  _Pose copyWith({
    Offset? head,
    Offset? shoulder,
    Offset? elbow,
    Offset? hand,
    Offset? hip,
    Offset? knee,
    Offset? foot,
    double? headR,
  }) =>
      _Pose(
        head: head ?? this.head,
        shoulder: shoulder ?? this.shoulder,
        elbow: elbow ?? this.elbow,
        hand: hand ?? this.hand,
        hip: hip ?? this.hip,
        knee: knee ?? this.knee,
        foot: foot ?? this.foot,
        headR: headR ?? this.headR,
      );

  static _Pose lerp(_Pose a, _Pose b, double t) => _Pose(
        head: Offset.lerp(a.head, b.head, t)!,
        shoulder: Offset.lerp(a.shoulder, b.shoulder, t)!,
        elbow: Offset.lerp(a.elbow, b.elbow, t)!,
        hand: Offset.lerp(a.hand, b.hand, t)!,
        hip: Offset.lerp(a.hip, b.hip, t)!,
        knee: Offset.lerp(a.knee, b.knee, t)!,
        foot: Offset.lerp(a.foot, b.foot, t)!,
        headR: a.headR + (b.headR - a.headR) * t,
      );
}

enum _Gear { barbell, dumbbell, barBack, cableTop, bench, floor }

class _Move {
  const _Move(this.start, this.end, {this.gear = const {}, this.front = false});
  final _Pose start;
  final _Pose end;
  final Set<_Gear> gear;

  /// Front-facing, bilateral movement: both arms and both legs are drawn
  /// (the authored side is mirrored). Side-view movements draw a single
  /// arm and leg, profile-style.
  final bool front;
}

// Standing reference pose, arms at sides.
const _stand = _Pose(
  head: Offset(50, 14),
  shoulder: Offset(50, 29),
  elbow: Offset(50, 42),
  hand: Offset(50, 55),
  hip: Offset(50, 55),
  knee: Offset(50, 74),
  foot: Offset(50, 93),
);

// Lying-on-a-bench reference (knees up).
const _lie = _Pose(
  head: Offset(20, 58),
  shoulder: Offset(32, 58),
  elbow: Offset(34, 50),
  hand: Offset(34, 44),
  hip: Offset(60, 60),
  knee: Offset(72, 52),
  foot: Offset(84, 50),
  headR: 6,
);

Map<String, _Move>? _movesCache;

Map<String, _Move> get _moves {
  return _movesCache ??= _buildMoves();
}

Map<String, _Move> _buildMoves() {
  final m = <String, _Move>{};

  // Shoulder press — bar from shoulders to overhead.
  m['press'] = _Move(
    _stand.copyWith(elbow: const Offset(58, 33), hand: const Offset(58, 24)),
    _stand.copyWith(elbow: const Offset(52, 15), hand: const Offset(52, 6)),
    gear: {_Gear.barbell},
    front: true,
  );

  // Lateral / front raise — arm down to shoulder height.
  m['lateral'] = _Move(
    _stand.copyWith(elbow: const Offset(51, 42), hand: const Offset(52, 55)),
    _stand.copyWith(elbow: const Offset(64, 33), hand: const Offset(79, 33)),
    gear: {_Gear.dumbbell},
    front: true,
  );

  // Face pull — rope toward the face, elbows high.
  m['facePull'] = _Move(
    _stand.copyWith(elbow: const Offset(64, 36), hand: const Offset(75, 40)),
    _stand.copyWith(elbow: const Offset(67, 22), hand: const Offset(55, 26)),
    gear: {_Gear.cableTop},
    front: true,
  );

  // Shrug — small vertical lift of the shoulders.
  m['shrug'] = _Move(
    _stand.copyWith(shoulder: const Offset(50, 31), hand: const Offset(50, 56)),
    _stand.copyWith(shoulder: const Offset(50, 25), hand: const Offset(50, 50)),
    gear: {_Gear.dumbbell},
    front: true,
  );

  // Bench press — lying, press the bar up off the chest.
  m['benchPress'] = _Move(
    _lie.copyWith(elbow: const Offset(34, 50), hand: const Offset(34, 44)),
    _lie.copyWith(elbow: const Offset(34, 42), hand: const Offset(34, 30)),
    gear: {_Gear.bench, _Gear.barbell},
  );

  // Fly / crossover — arms sweep from wide to together.
  m['fly'] = _Move(
    _stand.copyWith(elbow: const Offset(64, 44), hand: const Offset(79, 46)),
    _stand.copyWith(elbow: const Offset(55, 48), hand: const Offset(58, 50)),
    gear: {_Gear.dumbbell},
    front: true,
  );

  // Push-up — body rises and lowers over hands on the floor.
  m['pushup'] = const _Move(
    _Pose(
      head: Offset(24, 55),
      shoulder: Offset(34, 56),
      elbow: Offset(31, 66),
      hand: Offset(30, 73),
      hip: Offset(62, 63),
      knee: Offset(78, 66),
      foot: Offset(92, 68),
      headR: 6,
    ),
    _Pose(
      head: Offset(24, 49),
      shoulder: Offset(34, 50),
      elbow: Offset(32, 62),
      hand: Offset(30, 73),
      hip: Offset(62, 58),
      knee: Offset(78, 61),
      foot: Offset(92, 63),
      headR: 6,
    ),
    gear: {_Gear.floor},
  );

  // Dips — upright between bars, body drops and presses up.
  m['dip'] = const _Move(
    _Pose(
      head: Offset(50, 22),
      shoulder: Offset(50, 40),
      elbow: Offset(44, 49),
      hand: Offset(44, 54),
      hip: Offset(50, 62),
      knee: Offset(58, 73),
      foot: Offset(52, 82),
    ),
    _Pose(
      head: Offset(50, 16),
      shoulder: Offset(50, 34),
      elbow: Offset(46, 47),
      hand: Offset(44, 54),
      hip: Offset(50, 56),
      knee: Offset(58, 68),
      foot: Offset(52, 77),
    ),
    gear: {_Gear.dumbbell},
    front: true,
  );

  // Curl — forearm from extended down to curled up.
  m['curl'] = _Move(
    _stand.copyWith(elbow: const Offset(51, 43), hand: const Offset(53, 56)),
    _stand.copyWith(elbow: const Offset(50, 44), hand: const Offset(47, 31)),
    gear: {_Gear.dumbbell},
    front: true,
  );

  // Pushdown — forearm extends down against a cable.
  m['pushdown'] = _Move(
    _stand.copyWith(elbow: const Offset(50, 42), hand: const Offset(52, 45)),
    _stand.copyWith(elbow: const Offset(50, 43), hand: const Offset(53, 58)),
    gear: {_Gear.cableTop},
    front: true,
  );

  // Overhead triceps extension — hands drop behind the head, then extend up.
  m['overheadExt'] = _Move(
    _stand.copyWith(elbow: const Offset(52, 14), hand: const Offset(44, 24)),
    _stand.copyWith(elbow: const Offset(52, 14), hand: const Offset(50, 5)),
    gear: {_Gear.dumbbell},
    front: true,
  );

  // Skull crusher — lying, bar lowers toward the head then extends.
  m['skullCrusher'] = _Move(
    _lie.copyWith(elbow: const Offset(34, 46), hand: const Offset(30, 42)),
    _lie.copyWith(elbow: const Offset(34, 46), hand: const Offset(38, 32)),
    gear: {_Gear.bench, _Gear.barbell},
  );

  // Deadlift — hinge from a bent bottom to a tall lockout.
  m['deadlift'] = _Move(
    const _Pose(
      head: Offset(34, 30),
      shoulder: Offset(42, 36),
      elbow: Offset(46, 52),
      hand: Offset(48, 68),
      hip: Offset(60, 46),
      knee: Offset(64, 66),
      foot: Offset(64, 90),
    ),
    _stand.copyWith(hand: const Offset(50, 57), elbow: const Offset(50, 45)),
    gear: {_Gear.barbell, _Gear.floor},
  );

  // Bent-over row — torso stays hinged, the bar pulls to the ribs.
  const rowTorso = _Pose(
    head: Offset(30, 34),
    shoulder: Offset(40, 40),
    elbow: Offset(44, 54),
    hand: Offset(46, 66),
    hip: Offset(62, 46),
    knee: Offset(66, 68),
    foot: Offset(66, 92),
  );
  m['bentRow'] = _Move(
    rowTorso,
    rowTorso.copyWith(elbow: const Offset(50, 44), hand: const Offset(50, 50)),
    gear: {_Gear.barbell},
  );

  // Lat pulldown — seated, bar comes from overhead to the chest.
  const pulldownSeat = _Pose(
    head: Offset(50, 18),
    shoulder: Offset(50, 32),
    elbow: Offset(48, 20),
    hand: Offset(48, 8),
    hip: Offset(50, 58),
    knee: Offset(64, 60),
    foot: Offset(64, 80),
  );
  m['pulldown'] = _Move(
    pulldownSeat,
    pulldownSeat.copyWith(elbow: const Offset(60, 30), hand: const Offset(54, 34)),
    gear: {_Gear.cableTop},
    front: true,
  );

  // Pull-up — hang from a bar, pull the body up.
  m['pullup'] = const _Move(
    _Pose(
      head: Offset(50, 27),
      shoulder: Offset(50, 40),
      elbow: Offset(48, 22),
      hand: Offset(48, 8),
      hip: Offset(50, 62),
      knee: Offset(56, 76),
      foot: Offset(50, 86),
    ),
    _Pose(
      head: Offset(50, 20),
      shoulder: Offset(50, 32),
      elbow: Offset(46, 18),
      hand: Offset(48, 8),
      hip: Offset(50, 54),
      knee: Offset(56, 68),
      foot: Offset(50, 78),
    ),
    gear: {_Gear.barbell},
    front: true,
  );

  // Squat — stand tall, then sit into the hole with the bar on the back.
  m['squat'] = _Move(
    _stand.copyWith(
      shoulder: const Offset(50, 30),
      elbow: const Offset(44, 34),
      hand: const Offset(42, 30),
    ),
    const _Pose(
      head: Offset(52, 18),
      shoulder: Offset(52, 34),
      elbow: Offset(46, 38),
      hand: Offset(44, 34),
      hip: Offset(52, 60),
      knee: Offset(64, 66),
      foot: Offset(58, 90),
    ),
    gear: {_Gear.barBack},
    front: true,
  );

  // Leg extension / curl — seated, the shin swings out and back.
  const legSeat = _Pose(
    head: Offset(30, 30),
    shoulder: Offset(36, 36),
    elbow: Offset(40, 44),
    hand: Offset(40, 50),
    hip: Offset(58, 42),
    knee: Offset(70, 42),
    foot: Offset(78, 58),
  );
  m['legExtension'] = _Move(
    legSeat,
    legSeat.copyWith(foot: const Offset(86, 40)),
    gear: {_Gear.bench},
  );

  // Calf raise — the whole body lifts onto the toes.
  m['calfRaise'] = _Move(
    _stand,
    _stand.copyWith(
      head: const Offset(50, 11),
      shoulder: const Offset(50, 26),
      elbow: const Offset(50, 39),
      hand: const Offset(50, 52),
      hip: const Offset(50, 52),
      knee: const Offset(50, 71),
      foot: const Offset(50, 90),
    ),
    front: true,
  );

  // Crunch — shoulders curl up off the floor.
  const crunchBase = _Pose(
    head: Offset(28, 60),
    shoulder: Offset(38, 60),
    elbow: Offset(44, 58),
    hand: Offset(40, 52),
    hip: Offset(56, 66),
    knee: Offset(70, 54),
    foot: Offset(80, 64),
    headR: 6,
  );
  m['crunch'] = _Move(
    crunchBase,
    crunchBase.copyWith(
      head: const Offset(36, 48),
      shoulder: const Offset(44, 52),
      elbow: const Offset(50, 48),
      hand: const Offset(46, 42),
    ),
    gear: {_Gear.floor},
  );

  // Plank — held isometric on the forearms.
  const plankPose = _Pose(
    head: Offset(24, 54),
    shoulder: Offset(34, 56),
    elbow: Offset(34, 68),
    hand: Offset(26, 68),
    hip: Offset(62, 60),
    knee: Offset(78, 62),
    foot: Offset(92, 64),
    headR: 6,
  );
  m['plank'] = const _Move(plankPose, plankPose, gear: {_Gear.floor});

  // Mountain climbers — from a plank, a knee drives forward.
  m['mountainClimbers'] = _Move(
    plankPose.copyWith(knee: const Offset(78, 62), foot: const Offset(92, 64)),
    plankPose.copyWith(knee: const Offset(56, 58), foot: const Offset(50, 62)),
    gear: {_Gear.floor},
  );

  // Lying leg raise — legs lift from flat to vertical.
  const legRaiseBase = _Pose(
    head: Offset(20, 64),
    shoulder: Offset(30, 64),
    elbow: Offset(30, 66),
    hand: Offset(24, 66),
    hip: Offset(56, 64),
    knee: Offset(72, 64),
    foot: Offset(84, 64),
    headR: 6,
  );
  m['legRaise'] = _Move(
    legRaiseBase,
    legRaiseBase.copyWith(knee: const Offset(60, 48), foot: const Offset(60, 32)),
    gear: {_Gear.floor},
  );

  // Hanging leg raise — hang from a bar and lift the legs to the front.
  const hangBase = _Pose(
    head: Offset(50, 22),
    shoulder: Offset(50, 32),
    elbow: Offset(48, 18),
    hand: Offset(48, 8),
    hip: Offset(50, 54),
    knee: Offset(50, 72),
    foot: Offset(50, 86),
  );
  m['hangingLegRaise'] = _Move(
    hangBase,
    hangBase.copyWith(knee: const Offset(62, 58), foot: const Offset(74, 50)),
    gear: {_Gear.barbell},
    front: true,
  );

  // Farmer's carry — stand tall with a load, a small walking shift.
  m['carry'] = _Move(
    _stand.copyWith(hand: const Offset(50, 56)),
    _stand.copyWith(
      hand: const Offset(50, 56),
      knee: const Offset(54, 74),
      foot: const Offset(57, 92),
    ),
    gear: {_Gear.dumbbell},
    front: true,
  );

  return m;
}

/// Maps an exercise id to a movement archetype. Unknown ids fall back to a
/// neutral standing figure.
const _idToMove = <String, String>{
  // Chest
  'bench-press': 'benchPress',
  'chest-press-machine': 'benchPress',
  'incline-dumbbell-press': 'benchPress',
  'dumbbell-bench-press': 'benchPress',
  'decline-bench-press': 'benchPress',
  'cable-fly': 'fly',
  'cable-crossover': 'fly',
  'chest-dips': 'dip',
  'push-up': 'pushup',
  // Shoulders
  'overhead-press': 'press',
  'dumbbell-shoulder-press': 'press',
  'arnold-press': 'press',
  'lateral-raise': 'lateral',
  'front-raise': 'lateral',
  'face-pull': 'facePull',
  'shrugs': 'shrug',
  // Bicep
  'barbell-curl': 'curl',
  'dumbbell-curl': 'curl',
  'hammer-curl': 'curl',
  'preacher-curl': 'curl',
  'incline-curl': 'curl',
  'cable-curl': 'curl',
  'concentration-curl': 'curl',
  // Tricep
  'tricep-pushdown': 'pushdown',
  'rope-pushdown': 'pushdown',
  'overhead-extension': 'overheadExt',
  'skull-crusher': 'skullCrusher',
  'close-grip-bench': 'benchPress',
  'tricep-dips': 'dip',
  'tricep-kickback': 'pushdown',
  // Arms
  'wrist-curl': 'curl',
  'reverse-wrist-curl': 'curl',
  'reverse-curl': 'curl',
  'farmers-carry': 'carry',
  // Back
  'deadlift': 'deadlift',
  'pull-up': 'pullup',
  'lat-pulldown': 'pulldown',
  'bent-over-row': 'bentRow',
  'seated-cable-row': 'bentRow',
  't-bar-row': 'bentRow',
  // Abs
  'crunches': 'crunch',
  'plank': 'plank',
  'leg-raises': 'legRaise',
  'russian-twist': 'crunch',
  'bicycle-crunch': 'crunch',
  'mountain-climbers': 'mountainClimbers',
  'hanging-leg-raise': 'hangingLegRaise',
  // Legs
  'squat': 'squat',
  'leg-press': 'squat',
  'lunges': 'squat',
  'romanian-deadlift': 'deadlift',
  'leg-curl': 'legExtension',
  'leg-extension': 'legExtension',
  'calf-raise': 'calfRaise',
};

_Move _moveFor(String id) =>
    _moves[_idToMove[id]] ?? const _Move(_stand, _stand);

// ── Painter ─────────────────────────────────────────────────────────

class _FigurePainter extends CustomPainter {
  _FigurePainter({required this.move, required this.t, required this.color});

  final _Move move;
  final double t; // 0 = start, 1 = end
  final Color color;

  // Flat-illustration palette. The tank top follows the theme accent; the
  // rest is fixed so the avatar always reads as a little gym character.
  static const _skin = Color(0xFFEBB48E);
  static const _skinDark = Color(0xFFD89C74);
  static const _hair = Color(0xFF37302B);
  static const _shorts = Color(0xFF2C3446);
  static const _shoe = Color(0xFF20242E);
  static const _metal = Color(0xFF98A2B3);
  static const _metalDark = Color(0xFF6B7482);

  @override
  void paint(Canvas canvas, Size size) {
    final pose = _Pose.lerp(move.start, move.end, t);
    final s = size.width / 100.0;
    Offset p(Offset o) => Offset(o.dx * s, o.dy * s);

    final limbW = size.width * 0.11; // arm thickness
    final legW = size.width * 0.13; // leg thickness
    final top = color; // tank top follows theme accent

    Paint cap(Color col, double w) => Paint()
      ..color = col
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    void seg(Offset a, Offset b, Color col, double w) =>
        canvas.drawLine(p(a), p(b), cap(col, w));

    void head(Offset centre, double r) {
      final cc = p(centre);
      final rr = r * s;
      canvas.drawCircle(cc, rr, Paint()..color = _skin);
      // Hair as a thick band across the top of the head.
      canvas.drawArc(
        Rect.fromCircle(center: cc, radius: rr * 0.82),
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = _hair
          ..style = PaintingStyle.stroke
          ..strokeWidth = rr * 0.7
          ..strokeCap = StrokeCap.round,
      );
    }

    void arm(Offset sh, Offset el, Offset ha, Color skinCol, double w) {
      seg(sh, el, skinCol, w);
      seg(el, ha, skinCol, w);
      canvas.drawCircle(p(ha), w * 0.52, Paint()..color = _skinDark);
    }
    void leg(Offset hp, Offset kn, Offset ft) {
      seg(hp, kn, _shorts, legW);
      seg(kn, ft, _skin, legW * 0.78);
      canvas.drawCircle(p(ft), legW * 0.5, Paint()..color = _shoe);
    }

    void dumbbell(Offset hand) {
      final h = p(hand);
      final bar = size.width * 0.15;
      final plate = size.width * 0.055;
      canvas.drawLine(h.translate(-bar / 2, 0), h.translate(bar / 2, 0),
          cap(_metalDark, plate));
      for (final dx in [-bar / 2, bar / 2]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: h.translate(dx, 0),
                width: plate * 1.6,
                height: plate * 3.2),
            Radius.circular(plate * 0.6),
          ),
          Paint()..color = _metal,
        );
      }
    }

    void barbell(Offset a, Offset b) {
      final pa = p(a), pb = p(b);
      final dir = (pb - pa);
      final len = dir.distance;
      final unit = len == 0 ? const Offset(1, 0) : dir / len;
      final ext = size.width * 0.12;
      final e1 = pa - unit * ext, e2 = pb + unit * ext;
      canvas.drawLine(e1, e2, cap(_metalDark, size.width * 0.03));
      final plate = size.width * 0.05;
      for (final pt in [e1, e2, pa, pb]) {
        canvas.drawCircle(pt, plate, Paint()..color = _metal);
      }
    }

    final centre = pose.hip.dx;
    Offset mir(Offset o) => Offset(2 * centre - o.dx, o.dy);

    // ── Gear behind the body ──
    if (move.gear.contains(_Gear.floor)) {
      canvas.drawLine(Offset(4 * s, 95 * s), Offset(96 * s, 95 * s),
          cap(_metal.withValues(alpha: 0.5), s * 1.6));
    }
    if (move.gear.contains(_Gear.bench)) {
      final y = math.max(pose.shoulder.dy, pose.hip.dy) + 9;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB((pose.head.dx - 8) * s, y * s, (pose.hip.dx + 16) * s,
              (y + 6) * s),
          Radius.circular(2 * s),
        ),
        Paint()..color = _shorts,
      );
    }
    if (move.gear.contains(_Gear.cableTop)) {
      canvas.drawLine(p(pose.hand), p(Offset(pose.hand.dx, 2)),
          cap(_metalDark, s * 0.8));
      if (move.front) {
        canvas.drawLine(p(mir(pose.hand)), p(Offset(mir(pose.hand).dx, 2)),
            cap(_metalDark, s * 0.8));
      }
    }

    if (move.front) {
      const shHalf = 11.0, hipHalf = 7.0;
      final shL = Offset(centre - shHalf, pose.shoulder.dy);
      final shR = Offset(centre + shHalf, pose.shoulder.dy);
      final hipL = Offset(centre - hipHalf, pose.hip.dy);
      final hipR = Offset(centre + hipHalf, pose.hip.dy);

      // Symmetrise the authored arm/leg onto the right, mirror to the left.
      final elR = Offset(centre + (pose.elbow.dx - centre).abs(), pose.elbow.dy);
      final haR = Offset(centre + (pose.hand.dx - centre).abs(), pose.hand.dy);
      final knR =
          Offset(centre + math.max(5.0, (pose.knee.dx - centre).abs()), pose.knee.dy);
      final ftR =
          Offset(centre + math.max(6.0, (pose.foot.dx - centre).abs()), pose.foot.dy);

      // Legs (behind torso).
      leg(hipR, knR, ftR);
      leg(hipL, mir(knR), mir(ftR));

      // Back arm (left), a touch darker for depth.
      arm(shL, mir(elR), mir(haR), _skinDark, limbW);

      // Torso / tank top.
      final torso = Path()
        ..moveTo(p(shL).dx, p(shL).dy)
        ..lineTo(p(shR).dx, p(shR).dy)
        ..lineTo(p(hipR).dx, p(hipR).dy)
        ..lineTo(p(hipL).dx, p(hipL).dy)
        ..close();
      canvas.drawPath(torso, Paint()..color = top);
      canvas.drawCircle(p(shL), limbW * 0.5, Paint()..color = top);
      canvas.drawCircle(p(shR), limbW * 0.5, Paint()..color = top);

      // Neck + head.
      seg(Offset(centre, pose.head.dy + pose.headR - 1),
          Offset(centre, pose.shoulder.dy), _skin, limbW * 0.8);
      head(Offset(centre, pose.head.dy), pose.headR);

      // Front arm (right).
      arm(shR, elR, haR, _skin, limbW);

      // Weights.
      if (move.gear.contains(_Gear.barbell)) {
        barbell(mir(haR), haR);
      } else if (move.gear.contains(_Gear.dumbbell)) {
        dumbbell(haR);
        dumbbell(mir(haR));
      }
      if (move.gear.contains(_Gear.barBack)) {
        barbell(Offset(centre - shHalf, pose.shoulder.dy),
            Offset(centre + shHalf, pose.shoulder.dy));
      }
    } else {
      // Side view — single arm and leg, profile style.
      leg(pose.hip, pose.knee, pose.foot);
      seg(pose.shoulder, pose.hip, top, limbW * 1.6); // torso
      seg(Offset(pose.head.dx, pose.head.dy + pose.headR - 1), pose.shoulder,
          _skin, limbW * 0.8);
      head(pose.head, pose.headR);
      arm(pose.shoulder, pose.elbow, pose.hand, _skin, limbW);

      if (move.gear.contains(_Gear.barbell)) {
        barbell(Offset(pose.hand.dx - 10, pose.hand.dy),
            Offset(pose.hand.dx + 10, pose.hand.dy));
      } else if (move.gear.contains(_Gear.dumbbell)) {
        dumbbell(pose.hand);
      }
    }
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.t != t || old.color != color || old.move != move;
}

// ── Public widgets ──────────────────────────────────────────────────

/// A static line-art figure for an exercise, frozen at a recognisable
/// mid-rep frame. Used for the small card thumbnails.
class ExerciseFigure extends StatelessWidget {
  const ExerciseFigure({
    super.key,
    required this.exerciseId,
    required this.size,
    required this.color,
    this.frame = 0.6,
  });

  final String exerciseId;
  final double size;
  final Color color;
  final double frame;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _FigurePainter(move: _moveFor(exerciseId), t: frame, color: color),
    );
  }
}

/// An animated line-art figure that plays the rep back and forth, so the
/// avatar looks like it is performing the movement. Used in the demo sheet.
class AnimatedExerciseFigure extends StatefulWidget {
  const AnimatedExerciseFigure({
    super.key,
    required this.exerciseId,
    required this.size,
    required this.color,
  });

  final String exerciseId;
  final double size;
  final Color color;

  @override
  State<AnimatedExerciseFigure> createState() => _AnimatedExerciseFigureState();
}

class _AnimatedExerciseFigureState extends State<AnimatedExerciseFigure>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _t = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final move = _moveFor(widget.exerciseId);
    return AnimatedBuilder(
      animation: _t,
      builder: (_, __) => CustomPaint(
        size: Size.square(widget.size),
        painter: _FigurePainter(move: move, t: _t.value, color: widget.color),
      ),
    );
  }
}
