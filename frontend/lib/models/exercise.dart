class Exercise {
  final int? id;
  final String name;
  final String? category;

  const Exercise({this.id, required this.name, this.category});

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as int?,
      name: json['name'] as String,
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
      };
}
