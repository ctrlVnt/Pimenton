import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../models/recipe_book.dart';
import '../services/file_import_service.dart';
import '../services/storage_service.dart';
import 'recipe_detail_screen.dart';
import 'recipe_edit_screen.dart';
import 'social_import_dialog.dart';
import 'web_import_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final RecipeBook book;

  const BookDetailScreen({Key? key, required this.book}) : super(key: key);

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  List<Recipe> _recipes = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    setState(() {
      _isLoading = true;
    });
    final list = await StorageService.instance.getRecipesForBook(widget.book.id);
    setState(() {
      _recipes = list;
      _isLoading = false;
    });
  }

  void _openCreateRecipe() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeEditScreen(bookId: widget.book.id),
      ),
    );
    if (result == true) _loadRecipes();
  }

  void _openWebImport() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebImportScreen(bookId: widget.book.id),
      ),
    );
    if (result == true) _loadRecipes();
  }

  void _openSocialImport() async {
    await showDialog(
      context: context,
      builder: (context) => SocialImportDialog(bookId: widget.book.id),
    );
    _loadRecipes();
  }

  void _importFiles() async {
    final count = await FileImportService.pickAndImportRecipes(widget.book.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $count recipe(s)')),
      );
    }
    _loadRecipes();
  }

  void _showAddRecipeOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Add Recipe',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.edit,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: const Text('Add Manually'),
                  subtitle: const Text('Create a new recipe from scratch'),
                  onTap: () {
                    Navigator.pop(context);
                    _openCreateRecipe();
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    child: Icon(
                      Icons.language,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  title: const Text('Import from Web'),
                  subtitle: const Text('Search and extract recipe from website'),
                  onTap: () {
                    Navigator.pop(context);
                    _openWebImport();
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                    child: Icon(
                      Icons.link,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                  title: const Text('Import Social Link'),
                  subtitle: const Text('Paste link from Instagram, TikTok, Facebook'),
                  onTap: () {
                    Navigator.pop(context);
                    _openSocialImport();
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                    child: Icon(
                      Icons.file_open,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: const Text('Import File'),
                  subtitle: const Text('Import .json or .paprika file'),
                  onTap: () {
                    Navigator.pop(context);
                    _importFiles();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecipes = _recipes
        .where((r) => r.title.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.name),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search recipes...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredRecipes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              'No recipes found',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredRecipes.length,
                        itemBuilder: (context, index) {
                          final recipe = filteredRecipes[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              leading: recipe.imageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        recipe.imageUrl,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.fastfood),
                                      ),
                                    )
                                  : const CircleAvatar(child: Icon(Icons.restaurant)),
                              title: Text(recipe.title),
                              subtitle: Text(
                                recipe.description.isNotEmpty
                                    ? recipe.description
                                    : '${recipe.ingredients.length} ingredients',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                final res = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RecipeDetailScreen(recipe: recipe),
                                  ),
                                );
                                if (res == true) _loadRecipes();
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRecipeOptions,
        icon: const Icon(Icons.add),
        label: const Text('Add Recipe'),
      ),
    );
  }
}
