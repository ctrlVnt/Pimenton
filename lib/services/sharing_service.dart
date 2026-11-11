import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recipe.dart';
import '../models/recipe_book.dart';
import 'storage_service.dart';

class SharingService {
  /// Exports and shares a single recipe as JSON file.
  static Future<void> shareRecipe(Recipe recipe) async {
    final directory = await getTemporaryDirectory();
    final sanitizedTitle = recipe.title.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
    final filePath = '${directory.path}/$sanitizedTitle.json';

    final file = File(filePath);
    await file.writeAsString(jsonEncode(recipe.toJson()));

    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'Sharing recipe: ${recipe.title}',
    );
  }

  /// Exports and shares an entire recipe book (with all its recipes) as JSON file.
  static Future<void> shareRecipeBook(RecipeBook book) async {
    final recipes = await StorageService.instance.getRecipesForBook(book.id);
    final directory = await getTemporaryDirectory();
    final sanitizedName = book.name.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
    final filePath = '${directory.path}/$sanitizedName.json';

    final data = {
      'book': book.toJson(),
      'recipes': recipes.map((r) => r.toJson()).toList(),
    };

    final file = File(filePath);
    await file.writeAsString(jsonEncode(data));

    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'Sharing recipe book: ${book.name} (${recipes.length} recipes)',
    );
  }
}
