class Exercise {
  // MongoDB ObjectId, e.g. "6a95c5b9d9dfd9105acec7ca".
  final String? id;
  final String name;
  final String? category;

  const Exercise({this.id, required this.name, this.category});

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String?,
      name: json['name'] as String,
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
      };
}
