class RecipeBook {
  final String id;
  final String name;
  final String description;

  RecipeBook({
    required this.id,
    required this.name,
    this.description = '',
  });

  RecipeBook copyWith({
    String? id,
    String? name,
    String? description,
  }) {
    return RecipeBook(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }

  factory RecipeBook.fromJson(Map<String, dynamic> json) {
    return RecipeBook(
      id: json['id'] ?? 'default',
      name: json['name'] ?? 'My Recipe Book',
      description: json['description'] ?? '',
    );
  }
}
