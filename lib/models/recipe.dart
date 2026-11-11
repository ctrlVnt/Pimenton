import 'dart:convert';

class Recipe {
  final String id;
  final String bookId;
  final String title;
  final String description;
  final List<String> ingredients;
  final List<String> instructions;
  final String prepTime;
  final String cookTime;
  final String servings;
  final String imageUrl;
  final String sourceUrl;
  final DateTime createdAt;

  Recipe({
    required this.id,
    required this.bookId,
    required this.title,
    this.description = '',
    required this.ingredients,
    required this.instructions,
    this.prepTime = '',
    this.cookTime = '',
    this.servings = '',
    this.imageUrl = '',
    this.sourceUrl = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Recipe copyWith({
    String? id,
    String? bookId,
    String? title,
    String? description,
    List<String>? ingredients,
    List<String>? instructions,
    String? prepTime,
    String? cookTime,
    String? servings,
    String? imageUrl,
    String? sourceUrl,
    DateTime? createdAt,
  }) {
    return Recipe(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      title: title ?? this.title,
      description: description ?? this.description,
      ingredients: ingredients ?? List.from(this.ingredients),
      instructions: instructions ?? List.from(this.instructions),
      prepTime: prepTime ?? this.prepTime,
      cookTime: cookTime ?? this.cookTime,
      servings: servings ?? this.servings,
      imageUrl: imageUrl ?? this.imageUrl,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'title': title,
      'description': description,
      'ingredients': ingredients,
      'instructions': instructions,
      'prepTime': prepTime,
      'cookTime': cookTime,
      'servings': servings,
      'imageUrl': imageUrl,
      'sourceUrl': sourceUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      bookId: json['bookId'] ?? 'default',
      title: json['title'] ?? 'Untitled Recipe',
      description: json['description'] ?? '',
      ingredients: json['ingredients'] != null
          ? List<String>.from(json['ingredients'])
          : [],
      instructions: json['instructions'] != null
          ? List<String>.from(json['instructions'])
          : [],
      prepTime: json['prepTime'] ?? '',
      cookTime: json['cookTime'] ?? '',
      servings: json['servings'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      sourceUrl: json['sourceUrl'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
