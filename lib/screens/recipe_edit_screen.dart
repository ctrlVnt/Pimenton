import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/storage_service.dart';

class RecipeEditScreen extends StatefulWidget {
  final String bookId;
  final Recipe? initialRecipe;

  const RecipeEditScreen({
    Key? key,
    required this.bookId,
    this.initialRecipe,
  }) : super(key: key);

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _title;
  late String _description;
  late String _prepTime;
  late String _cookTime;
  late String _servings;
  late String _imageUrl;
  late String _sourceUrl;

  late List<TextEditingController> _ingredientControllers;
  late List<TextEditingController> _instructionControllers;

  @override
  void initState() {
    super.initState();
    final r = widget.initialRecipe;
    _title = r?.title ?? '';
    _description = r?.description ?? '';
    _prepTime = r?.prepTime ?? '';
    _cookTime = r?.cookTime ?? '';
    _servings = r?.servings ?? '';
    _imageUrl = r?.imageUrl ?? '';
    _sourceUrl = r?.sourceUrl ?? '';

    _ingredientControllers = (r?.ingredients.isNotEmpty == true)
        ? r!.ingredients.map((i) => TextEditingController(text: i)).toList()
        : [TextEditingController()];

    _instructionControllers = (r?.instructions.isNotEmpty == true)
        ? r!.instructions.map((i) => TextEditingController(text: i)).toList()
        : [TextEditingController()];
  }

  @override
  void dispose() {
    for (var c in _ingredientControllers) c.dispose();
    for (var c in _instructionControllers) c.dispose();
    super.dispose();
  }

  void _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final ingredients = _ingredientControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final instructions = _instructionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final recipe = Recipe(
      id: widget.initialRecipe?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      bookId: widget.bookId,
      title: _title.trim(),
      description: _description.trim(),
      ingredients: ingredients,
      instructions: instructions,
      prepTime: _prepTime.trim(),
      cookTime: _cookTime.trim(),
      servings: _servings.trim(),
      imageUrl: _imageUrl.trim(),
      sourceUrl: _sourceUrl.trim(),
      createdAt: widget.initialRecipe?.createdAt,
    );

    await StorageService.instance.saveRecipe(recipe);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialRecipe != null && widget.initialRecipe!.id.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Recipe' : 'New Recipe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveRecipe,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              initialValue: _title,
              decoration: const InputDecoration(
                labelText: 'Recipe Title *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              onSaved: (v) => _title = v ?? '',
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _description,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onSaved: (v) => _description = v ?? '',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _prepTime,
                    decoration: const InputDecoration(
                      labelText: 'Prep Time',
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (v) => _prepTime = v ?? '',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: _cookTime,
                    decoration: const InputDecoration(
                      labelText: 'Cook Time',
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (v) => _cookTime = v ?? '',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: _servings,
                    decoration: const InputDecoration(
                      labelText: 'Servings',
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (v) => _servings = v ?? '',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _imageUrl,
              decoration: const InputDecoration(
                labelText: 'Image URL',
                border: OutlineInputBorder(),
              ),
              onSaved: (v) => _imageUrl = v ?? '',
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _sourceUrl,
              decoration: const InputDecoration(
                labelText: 'Source URL / Web Link',
                border: OutlineInputBorder(),
              ),
              onSaved: (v) => _sourceUrl = v ?? '',
            ),
            const SizedBox(height: 20),
            Text('Ingredients', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._ingredientControllers.asMap().entries.map((entry) {
              int idx = entry.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: entry.value,
                        decoration: InputDecoration(
                          hintText: 'Ingredient ${idx + 1}',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        setState(() {
                          _ingredientControllers.removeAt(idx);
                        });
                      },
                    )
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _ingredientControllers.add(TextEditingController());
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Ingredient'),
            ),
            const SizedBox(height: 20),
            Text('Instructions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._instructionControllers.asMap().entries.map((entry) {
              int idx = entry.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: entry.value,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Step ${idx + 1}',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        setState(() {
                          _instructionControllers.removeAt(idx);
                        });
                      },
                    )
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _instructionControllers.add(TextEditingController());
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Step'),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saveRecipe,
              icon: const Icon(Icons.save),
              label: const Text('Save Recipe'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            )
          ],
        ),
      ),
    );
  }
}
