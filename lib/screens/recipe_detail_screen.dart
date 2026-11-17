import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/recipe.dart';
import '../services/sharing_service.dart';
import '../services/storage_service.dart';
import 'recipe_edit_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({Key? key, required this.recipe}) : super(key: key);

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late Recipe _currentRecipe;
  late double _baseServings;
  late double _currentServings;

  @override
  void initState() {
    super.initState();
    _currentRecipe = widget.recipe;
    _baseServings = _parseBaseServings(_currentRecipe.servings);
    _currentServings = _baseServings;
  }

  double _parseBaseServings(String servingsStr) {
    if (servingsStr.trim().isEmpty) return 1.0;
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(servingsStr);
    if (match != null) {
      final val = double.tryParse(match.group(1)!);
      if (val != null && val > 0) return val;
    }
    return 1.0;
  }

  String _formatNumber(double val) {
    if ((val - val.round()).abs() < 0.01) {
      return val.round().toString();
    }

    final whole = val.floor();
    final remainder = val - whole;

    String fractionStr = '';
    if ((remainder - 0.25).abs() < 0.04) {
      fractionStr = '1/4';
    } else if ((remainder - 0.333).abs() < 0.04) {
      fractionStr = '1/3';
    } else if ((remainder - 0.5).abs() < 0.04) {
      fractionStr = '1/2';
    } else if ((remainder - 0.666).abs() < 0.04) {
      fractionStr = '2/3';
    } else if ((remainder - 0.75).abs() < 0.04) {
      fractionStr = '3/4';
    }

    if (fractionStr.isNotEmpty) {
      return whole > 0 ? '$whole $fractionStr' : fractionStr;
    }

    return val.toStringAsFixed(val % 1 == 0 ? 0 : 2);
  }

  String _scaleIngredient(String ingredient, double ratio) {
    if (ratio == 1.0) return ingredient;

    final regex = RegExp(r'(\d+\s+[1-9]\d*/[1-9]\d*)|([1-9]\d*/[1-9]\d*)|(\d+(?:\.\d+)?)');

    return ingredient.replaceAllMapped(regex, (match) {
      final text = match.group(0)!;

      // 1. Mixed fraction: e.g. "1 1/2"
      if (text.contains(' ') && text.contains('/')) {
        final parts = text.split(' ');
        final whole = double.tryParse(parts[0]) ?? 0;
        final fracParts = parts[1].split('/');
        final num = double.tryParse(fracParts[0]) ?? 0;
        final den = double.tryParse(fracParts[1]) ?? 1;
        final value = (whole + (num / den)) * ratio;
        return _formatNumber(value);
      }

      // 2. Simple fraction: e.g. "1/2"
      if (text.contains('/')) {
        final fracParts = text.split('/');
        final num = double.tryParse(fracParts[0]) ?? 0;
        final den = double.tryParse(fracParts[1]) ?? 1;
        final value = (num / den) * ratio;
        return _formatNumber(value);
      }

      // 3. Decimal or integer: e.g. "2.5", "3"
      final val = double.tryParse(text);
      if (val != null) {
        return _formatNumber(val * ratio);
      }

      return text;
    });
  }

  void _editRecipe() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeEditScreen(
          bookId: _currentRecipe.bookId,
          initialRecipe: _currentRecipe,
        ),
      ),
    );

    if (result == true) {
      final updatedList = await StorageService.instance.getRecipes();
      final updated = updatedList.firstWhere(
        (r) => r.id == _currentRecipe.id,
        orElse: () => _currentRecipe,
      );
      setState(() {
        _currentRecipe = updated;
        _baseServings = _parseBaseServings(_currentRecipe.servings);
        _currentServings = _baseServings;
      });
    }
  }

  void _deleteRecipe() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: const Text('Are you sure you want to delete this recipe?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.instance.deleteRecipe(_currentRecipe.id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      debugPrint('Impossibile aprire $url');
    }
  }

  Widget _buildServingsSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people, size: 20),
          const SizedBox(width: 8),
          Text(
            'Servings:',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _currentServings > 1
                ? () {
                    setState(() {
                      _currentServings -= 1;
                    });
                  }
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              _formatNumber(_currentServings),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _currentServings != _baseServings
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                _currentServings += 1;
              });
            },
          ),
          if (_currentServings != _baseServings) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _currentServings = _baseServings;
                });
              },
              child: const Text('Reset', style: TextStyle(fontSize: 12)),
            )
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _currentServings / _baseServings;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentRecipe.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => SharingService.shareRecipe(_currentRecipe),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editRecipe,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteRecipe,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentRecipe.imageUrl.isNotEmpty)
              Image.network(
                _currentRecipe.imageUrl,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentRecipe.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (_currentRecipe.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _currentRecipe.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (_currentRecipe.prepTime.isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.timer),
                          label: Text('Prep: ${_currentRecipe.prepTime}'),
                        ),
                      if (_currentRecipe.cookTime.isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.soup_kitchen),
                          label: Text('Cook: ${_currentRecipe.cookTime}'),
                        ),
                      _buildServingsSelector(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Ingredients',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              if (ratio != 1.0)
                                Text(
                                  'Scaled (${_formatNumber(_currentServings)} servings)',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                            ],
                          ),
                          const Divider(),
                          if (_currentRecipe.ingredients.isEmpty)
                            const Text('No ingredients specified.'),
                          ..._currentRecipe.ingredients.map(
                            (item) {
                              final scaledItem = _scaleIngredient(item, ratio);
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Expanded(
                                      child: Text(
                                        scaledItem,
                                        style: TextStyle(
                                          fontWeight: ratio != 1.0 ? FontWeight.w500 : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Instructions',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Divider(),
                          if (_currentRecipe.instructions.isEmpty)
                            const Text('No instructions specified.'),
                          ..._currentRecipe.instructions.asMap().entries.map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        child: Text(
                                          '${entry.key + 1}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(entry.value),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                  if (_currentRecipe.sourceUrl.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Source:',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    SelectableText(
                      _currentRecipe.sourceUrl,
                      style: const TextStyle(color: Colors.blue),
                      onTap: () => _launchUrl(_currentRecipe.sourceUrl),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
