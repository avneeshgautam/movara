/// A single logged unit of work: N sets of M reps of an exercise,
/// optionally with a weight, on a given day.
class WorkoutEntry {
  // MongoDB ObjectId, e.g. "6a95c5d8d9dfd9105acec7d0".
  final String? id;
  final String exerciseName;
  final int sets;
  final int reps;
  final double? weightKg;
  final DateTime performedAt;
  final String? notes;

  const WorkoutEntry({
    this.id,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    this.weightKg,
    required this.performedAt,
    this.notes,
  });

  factory WorkoutEntry.fromJson(Map<String, dynamic> json) {
    return WorkoutEntry(
      id: json['id'] as String?,
      exerciseName: json['exerciseName'] as String,
      sets: json['sets'] as int,
      reps: json['reps'] as int,
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      performedAt: DateTime.parse(json['performedAt'] as String),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'exerciseName': exerciseName,
        'sets': sets,
        'reps': reps,
        'weightKg': weightKg,
        // Backend expects an ISO date (yyyy-MM-dd), not a full timestamp.
        'performedAt': performedAt.toIso8601String().split('T').first,
        'notes': notes,
      };
}
