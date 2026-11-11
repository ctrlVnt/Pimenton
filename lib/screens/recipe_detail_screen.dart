import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _currentRecipe = widget.recipe;
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

  @override
  Widget build(BuildContext context) {
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
                      if (_currentRecipe.servings.isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.people),
                          label: Text('Yield: ${_currentRecipe.servings}'),
                        ),
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
                          Text(
                            'Ingredients',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Divider(),
                          if (_currentRecipe.ingredients.isEmpty)
                            const Text('No ingredients specified.'),
                          ..._currentRecipe.ingredients.map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Expanded(child: Text(item)),
                                ],
                              ),
                            ),
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
