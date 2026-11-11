import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import '../models/recipe.dart';
import 'storage_service.dart';

class FileImportService {
  /// Prompts user to pick .json or .paprikarecipes files and processes them into the target book.
  static Future<int> pickAndImportRecipes(String bookId) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'paprikarecipes', 'paprikarecipe', 'zip'],
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return 0;

    int importedCount = 0;

    for (var file in result.files) {
      if (file.path == null) continue;
      final fileObj = File(file.path!);
      final extension = file.extension?.toLowerCase() ?? '';

      if (extension == 'json') {
        final count = await _importJsonFile(fileObj, bookId);
        importedCount += count;
      } else if (extension == 'paprikarecipes' || extension == 'zip') {
        final count = await _importPaprikaRecipesFile(fileObj, bookId);
        importedCount += count;
      } else if (extension == 'paprikarecipe') {
        final count = await _importSinglePaprikaRecipe(fileObj, bookId);
        importedCount += count;
      }
    }

    return importedCount;
  }

  static Future<int> _importJsonFile(File file, String bookId) async {
    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      int count = 0;

      if (decoded is List) {
        for (var item in decoded) {
          if (item is Map<String, dynamic>) {
            final recipe = Recipe.fromJson(item).copyWith(
              id: DateTime.now().millisecondsSinceEpoch.toString() + '_$count',
              bookId: bookId,
            );
            await StorageService.instance.saveRecipe(recipe);
            count++;
          }
        }
      } else if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('recipes') && decoded['recipes'] is List) {
          for (var item in decoded['recipes']) {
            if (item is Map<String, dynamic>) {
              final recipe = Recipe.fromJson(item).copyWith(
                id: DateTime.now().millisecondsSinceEpoch.toString() + '_$count',
                bookId: bookId,
              );
              await StorageService.instance.saveRecipe(recipe);
              count++;
            }
          }
        } else {
          final recipe = Recipe.fromJson(decoded).copyWith(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            bookId: bookId,
          );
          await StorageService.instance.saveRecipe(recipe);
          count++;
        }
      }
      return count;
    } catch (e) {
      print('Error parsing JSON file: $e');
      return 0;
    }
  }

  static Future<int> _importPaprikaRecipesFile(File file, String bookId) async {
    int count = 0;
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final archiveFile in archive) {
        if (archiveFile.isFile) {
          final fileData = archiveFile.content as List<int>;
          try {
            // Paprika individual files inside archive are gzipped JSON
            final uncompressed = GZipDecoder().decodeBytes(fileData);
            final jsonStr = utf8.decode(uncompressed);
            final map = jsonDecode(jsonStr);
            if (map is Map<String, dynamic>) {
              final recipe = _convertPaprikaMapToRecipe(map, bookId, count);
              await StorageService.instance.saveRecipe(recipe);
              count++;
            }
          } catch (_) {
            // If not gzip, attempt plain UTF-8 JSON
            try {
              final jsonStr = utf8.decode(fileData);
              final map = jsonDecode(jsonStr);
              if (map is Map<String, dynamic>) {
                final recipe = _convertPaprikaMapToRecipe(map, bookId, count);
                await StorageService.instance.saveRecipe(recipe);
                count++;
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      print('Error reading paprika archive: $e');
    }
    return count;
  }

  static Future<int> _importSinglePaprikaRecipe(File file, String bookId) async {
    try {
      final bytes = await file.readAsBytes();
      List<int> decompressed;
      try {
        decompressed = GZipDecoder().decodeBytes(bytes);
      } catch (_) {
        decompressed = bytes;
      }
      final jsonStr = utf8.decode(decompressed);
      final map = jsonDecode(jsonStr);
      if (map is Map<String, dynamic>) {
        final recipe = _convertPaprikaMapToRecipe(map, bookId, 0);
        await StorageService.instance.saveRecipe(recipe);
        return 1;
      }
    } catch (e) {
      print('Error importing paprika recipe: $e');
    }
    return 0;
  }

  static Recipe _convertPaprikaMapToRecipe(Map<String, dynamic> map, String bookId, int index) {
    final title = map['name'] ?? 'Paprika Recipe';
    final description = map['description'] ?? '';

    List<String> ingredients = [];
    if (map['ingredients'] is String) {
      ingredients = (map['ingredients'] as String)
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    List<String> instructions = [];
    if (map['directions'] is String) {
      instructions = (map['directions'] as String)
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return Recipe(
      id: DateTime.now().millisecondsSinceEpoch.toString() + '_$index',
      bookId: bookId,
      title: title,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      prepTime: map['prep_time'] ?? '',
      cookTime: map['cook_time'] ?? '',
      servings: map['servings'] ?? '',
      imageUrl: map['image_url'] ?? '',
      sourceUrl: map['source_url'] ?? '',
    );
  }
}
