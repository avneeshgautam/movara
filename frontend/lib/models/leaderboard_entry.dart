/// One row on the leaderboard.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.points,
    required this.setsThisWeek,
    required this.kmThisWeek,
    required this.rank,
    required this.isMe,
    this.photoUrl,
  });

  final String userId;
  final String displayName;
  final int points;
  final int setsThisWeek;
  final double kmThisWeek;
  final int rank;
  final bool isMe;
  final String? photoUrl;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        points: json['points'] as int,
        setsThisWeek: json['setsThisWeek'] as int,
        kmThisWeek: (json['kmThisWeek'] as num).toDouble(),
        rank: json['rank'] as int,
        isMe: json['isMe'] as bool,
        photoUrl: json['photoUrl'] as String?,
      );
}
