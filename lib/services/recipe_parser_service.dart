import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
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
        if (parsed != null) {
          // If JSON-LD is missing ingredients or instructions, attempt HTML fallback extraction to fill them
          if (parsed.ingredients.isEmpty || parsed.instructions.isEmpty) {
            final htmlIngredients = parsed.ingredients.isEmpty ? _extractIngredientsFromHtml(document) : parsed.ingredients;
            final htmlInstructions = parsed.instructions.isEmpty ? _extractInstructionsFromHtml(document) : parsed.instructions;
            return parsed.copyWith(
              ingredients: htmlIngredients,
              instructions: htmlInstructions,
            );
          }
          return parsed;
        }
      } catch (_) {}
    }

    // Fallback: Parse Open Graph Meta tags and HTML DOM
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

    final ingredients = _extractIngredientsFromHtml(document);
    final instructions = _extractInstructionsFromHtml(document);

    return Recipe(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      bookId: targetBookId,
      title: title.trim(),
      description: description.trim(),
      ingredients: ingredients,
      instructions: instructions.isNotEmpty ? instructions : (description.isNotEmpty ? [description.trim()] : []),
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

  static bool _isRecipeType(dynamic type) {
    if (type == null) return false;
    if (type is String) {
      final t = type.toLowerCase();
      return t == 'recipe' || t.endsWith('/recipe') || t.endsWith(':recipe');
    } else if (type is List) {
      return type.any((element) => _isRecipeType(element));
    }
    return false;
  }

  static Recipe? _parseJsonLdItem(Map<String, dynamic> item, String targetBookId, String sourceUrl) {
    final type = item['@type'];
    if (!_isRecipeType(type)) return null;

    String title = item['name'] ?? 'Imported Recipe';
    String description = item['description'] ?? '';

    // Ingredients
    List<String> ingredients = [];
    if (item['recipeIngredient'] is List) {
      ingredients = List<String>.from(
        (item['recipeIngredient'] as List).map((e) => _cleanHtmlText(e.toString())),
      );
    } else if (item['recipeIngredient'] is String) {
      ingredients = [ _cleanHtmlText(item['recipeIngredient']) ];
    }

    // Instructions (recursively handles HowToStep and HowToSection used by WordPress/Italian sites)
    List<String> instructions = _extractInstructionSteps(item['recipeInstructions']);

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

    String prepTime = _formatIsoDuration(item['prepTime']?.toString() ?? '');
    String cookTime = _formatIsoDuration(item['cookTime']?.toString() ?? '');
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

  static List<String> _extractInstructionSteps(dynamic instructionsData) {
    List<String> steps = [];
    if (instructionsData is List) {
      for (var item in instructionsData) {
        steps.addAll(_extractInstructionSteps(item));
      }
    } else if (instructionsData is Map<String, dynamic>) {
      if (instructionsData.containsKey('itemListElement') && instructionsData['itemListElement'] is List) {
        final sectionName = instructionsData['name']?.toString().trim();
        if (sectionName != null && sectionName.isNotEmpty) {
          steps.add('[$sectionName]');
        }
        steps.addAll(_extractInstructionSteps(instructionsData['itemListElement']));
      } else if (instructionsData.containsKey('text')) {
        final text = _cleanHtmlText(instructionsData['text'].toString());
        if (text.isNotEmpty) steps.add(text);
      } else if (instructionsData.containsKey('name')) {
        final text = _cleanHtmlText(instructionsData['name'].toString());
        if (text.isNotEmpty) steps.add(text);
      }
    } else if (instructionsData is String) {
      final text = _cleanHtmlText(instructionsData);
      if (text.isNotEmpty) steps.add(text);
    }
    return steps;
  }

  static List<String> _extractIngredientsFromHtml(dom.Document document) {
    List<String> ingredients = [];

    // 1. Try CSS selectors commonly used for ingredients
    final selectorElements = document.querySelectorAll(
      '[class*="ingredient"], [id*="ingredient"], [itemprop*="recipeIngredient"], .wprm-recipe-ingredient',
    );
    for (var el in selectorElements) {
      if (el.localName?.startsWith('H') == true || el.text.trim().isEmpty) continue;
      final text = el.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (text.isNotEmpty && !ingredients.contains(text) && text.length < 200) {
        ingredients.add(text);
      }
    }

    if (ingredients.isNotEmpty) return ingredients;

    // 2. Fallback: Search under headings like "Ingredienti" / "Ingredients"
    final headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6, strong, b');
    dom.Element? targetHeading;
    for (var h in headings) {
      final txt = h.text.trim().toLowerCase();
      if (txt == 'ingredienti' || txt == 'ingredients' || txt.contains('ingredienti') || txt.contains('ingredients')) {
        targetHeading = h;
        break;
      }
    }

    if (targetHeading != null) {
      var parent = targetHeading.parent;
      if (parent != null) {
        final listItems = parent.querySelectorAll('li, p');
        for (var item in listItems) {
          final text = item.text.trim().replaceAll(RegExp(r'\s+'), ' ');
          if (text.isNotEmpty && !ingredients.contains(text) && text.length < 200) {
            ingredients.add(text);
          }
        }
      }
    }

    return ingredients;
  }

  static List<String> _extractInstructionsFromHtml(dom.Document document) {
    List<String> instructions = [];

    // 1. Try CSS selectors commonly used for steps/instructions
    final selectorElements = document.querySelectorAll(
      '[class*="instruction"], [class*="recipe-step"], [id*="procedimento"], [id*="instruction"], .wprm-recipe-instruction',
    );
    for (var el in selectorElements) {
      if (el.localName?.startsWith('H') == true || el.text.trim().isEmpty) continue;
      final text = el.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (text.isNotEmpty && !instructions.contains(text)) {
        instructions.add(text);
      }
    }

    if (instructions.isNotEmpty) return instructions;

    // 2. Fallback: Search under headings like "Procedimento", "Preparazione", etc.
    final headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6, strong, b');
    dom.Element? targetHeading;
    for (var h in headings) {
      final txt = h.text.trim().toLowerCase();
      if (txt == 'procedimento' || txt == 'preparazione' || txt == 'instructions' || txt == 'directions' || txt == 'istruzioni') {
        targetHeading = h;
        break;
      }
    }

    if (targetHeading != null) {
      var parent = targetHeading.parent;
      if (parent != null) {
        final listItems = parent.querySelectorAll('li, p');
        for (var item in listItems) {
          final text = item.text.trim().replaceAll(RegExp(r'\s+'), ' ');
          if (text.isNotEmpty && !instructions.contains(text) && text.length > 5) {
            instructions.add(text);
          }
        }
      }
    }

    return instructions;
  }

  static String _cleanHtmlText(String text) {
    if (text.isEmpty) return '';
    final parsed = html_parser.parseFragment(text);
    return parsed.text?.trim() ?? text.trim();
  }

  static String _formatIsoDuration(String isoString) {
    if (isoString.isEmpty) return '';
    final regex = RegExp(r'P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?)?');
    final match = regex.firstMatch(isoString);
    if (match != null) {
      final days = match.group(1);
      final hours = match.group(2);
      final minutes = match.group(3);

      List<String> parts = [];
      if (days != null && days != '0') parts.add('${days}d');
      if (hours != null && hours != '0') parts.add('${hours}h');
      if (minutes != null && minutes != '0') parts.add('${minutes}m');

      if (parts.isNotEmpty) return parts.join(' ');
    }
    return isoString;
  }
}
