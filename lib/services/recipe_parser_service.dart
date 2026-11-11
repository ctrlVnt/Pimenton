import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../models/recipe.dart';

class RecipeParserService {
  /// Extracts JSON-LD schema or open graph meta information from a web page URL or raw HTML string.
  static Future<Recipe?> fetchAndParseUrl(String url, String targetBookId) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36',
        },
      );

      if (response.statusCode == 200) {
        return parseHtmlContent(response.body, targetBookId, url: url);
      }
    } catch (e) {
      print('Error fetching URL: $e');
    }
    return null;
  }

  static Recipe parseHtmlContent(String htmlContent, String targetBookId, {String url = ''}) {
    final document = html_parser.parse(htmlContent);

    // Try finding JSON-LD script tags
    final scriptTags = document.querySelectorAll('script[type="application/ld+json"]');
    for (var script in scriptTags) {
      try {
        final jsonContent = jsonDecode(script.text);
        Recipe? parsed = _parseJsonLd(jsonContent, targetBookId, url);
        if (parsed != null) return parsed;
      } catch (_) {}
    }

    // Fallback: Parse Open Graph Meta tags (for Instagram, TikTok, Facebook or plain blogs)
    String title = '';
    String description = '';
    String imageUrl = '';

    final ogTitle = document.querySelector('meta[property="og:title"]');
    if (ogTitle != null) title = ogTitle.attributes['content'] ?? '';

    final ogDesc = document.querySelector('meta[property="og:description"]');
    if (ogDesc != null) description = ogDesc.attributes['content'] ?? '';

    final ogImage = document.querySelector('meta[property="og:image"]');
    if (ogImage != null) imageUrl = ogImage.attributes['content'] ?? '';

    if (title.isEmpty) {
      title = document.querySelector('title')?.text ?? 'Imported Recipe';
    }

    return Recipe(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      bookId: targetBookId,
      title: title.trim(),
      description: description.trim(),
      ingredients: [],
      instructions: description.isNotEmpty ? [description.trim()] : [],
      imageUrl: imageUrl.trim(),
      sourceUrl: url,
    );
  }

  static Recipe? _parseJsonLd(dynamic jsonLd, String targetBookId, String sourceUrl) {
    if (jsonLd is List) {
      for (var item in jsonLd) {
        final r = _parseJsonLdItem(item, targetBookId, sourceUrl);
        if (r != null) return r;
      }
    } else if (jsonLd is Map<String, dynamic>) {
      if (jsonLd.containsKey('@graph') && jsonLd['@graph'] is List) {
        for (var item in jsonLd['@graph']) {
          final r = _parseJsonLdItem(item, targetBookId, sourceUrl);
          if (r != null) return r;
        }
      } else {
        return _parseJsonLdItem(jsonLd, targetBookId, sourceUrl);
      }
    }
    return null;
  }

  static Recipe? _parseJsonLdItem(Map<String, dynamic> item, String targetBookId, String sourceUrl) {
    final type = item['@type'];
    bool isRecipe = false;

    if (type is String && type.toLowerCase() == 'recipe') {
      isRecipe = true;
    } else if (type is List) {
      isRecipe = type.any((element) => element.toString().toLowerCase() == 'recipe');
    }

    if (!isRecipe) return null;

    String title = item['name'] ?? 'Imported Recipe';
    String description = item['description'] ?? '';

    // Ingredients
    List<String> ingredients = [];
    if (item['recipeIngredient'] is List) {
      ingredients = List<String>.from(
        (item['recipeIngredient'] as List).map((e) => e.toString().trim()),
      );
    }

    // Instructions
    List<String> instructions = [];
    if (item['recipeInstructions'] is List) {
      for (var step in item['recipeInstructions']) {
        if (step is String) {
          instructions.add(step.trim());
        } else if (step is Map && step.containsKey('text')) {
          instructions.add(step['text'].toString().trim());
        }
      }
    } else if (item['recipeInstructions'] is String) {
      instructions.add(item['recipeInstructions'].toString().trim());
    }

    // Image
    String imageUrl = '';
    if (item['image'] is String) {
      imageUrl = item['image'];
    } else if (item['image'] is List && (item['image'] as List).isNotEmpty) {
      final first = (item['image'] as List).first;
      imageUrl = first is String ? first : (first is Map ? first['url'] ?? '' : '');
    } else if (item['image'] is Map && item['image']['url'] != null) {
      imageUrl = item['image']['url'];
    }

    String prepTime = item['prepTime']?.toString() ?? '';
    String cookTime = item['cookTime']?.toString() ?? '';
    String yieldVal = item['recipeYield']?.toString() ?? '';

    return Recipe(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      bookId: targetBookId,
      title: title,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      prepTime: prepTime,
      cookTime: cookTime,
      servings: yieldVal,
      imageUrl: imageUrl,
      sourceUrl: sourceUrl,
    );
  }
}
