import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../models/recipe_book.dart';
import '../services/recipe_parser_service.dart';
import '../services/sharing_service.dart';
import '../services/storage_service.dart';
import 'book_detail_screen.dart';
import 'recipe_edit_screen.dart';
import 'web_import_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _platform = MethodChannel('com.example.pimenton/share');

  List<RecipeBook> _books = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
    _initShareIntentHandler();
  }

  void _initShareIntentHandler() {
    _platform.setMethodCallHandler(_handleNativeMethodCall);
    _checkSharedText();
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'onSharedTextReceived') {
      final String? text = call.arguments as String?;
      if (text != null && text.isNotEmpty) {
        _processSharedText(text);
      }
    }
  }

  Future<void> _checkSharedText() async {
    try {
      final String? text = await _platform.invokeMethod('getSharedText');
      if (text != null && text.isNotEmpty) {
        _processSharedText(text);
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to get shared text: ${e.message}");
    }
  }

  void _processSharedText(String text) {
    final regExp = RegExp(r'https?://[^\s]+');
    final match = regExp.firstMatch(text);
    final url = match?.group(0) ?? text.trim();

    if (url.isEmpty) return;

    _showBookSelectionDialog(url);
  }

  void _showBookSelectionDialog(String url) async {
    final books = await StorageService.instance.getBooks();
    if (books.isEmpty) return;

    String selectedBookId = books.first.id;
    bool isImporting = false;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Import Shared Recipe'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shared URL:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    url,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.blue),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select Recipe Book:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedBookId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: books.map((b) {
                      return DropdownMenuItem(
                        value: b.id,
                        child: Text(b.name),
                      );
                    }).toList(),
                    onChanged: isImporting
                        ? null
                        : (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedBookId = val;
                              });
                            }
                          },
                  ),
                  if (isImporting) ...[
                    const SizedBox(height: 20),
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('Scraping recipe...'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: isImporting
                  ? []
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          setDialogState(() {
                            isImporting = true;
                          });

                          final recipe = await RecipeParserService.fetchAndParseUrl(url, selectedBookId);

                          if (!mounted) return;
                          Navigator.pop(dialogCtx);

                          if (recipe != null) {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RecipeEditScreen(
                                  bookId: selectedBookId,
                                  initialRecipe: recipe,
                                ),
                              ),
                            );
                            _loadBooks();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not automatically scrape recipe. Opening web import...'),
                              ),
                            );
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WebImportScreen(
                                  bookId: selectedBookId,
                                  initialUrl: url,
                                ),
                              ),
                            );
                            _loadBooks();
                          }
                        },
                        child: const Text('Import Recipe'),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadBooks() async {
    setState(() {
      _isLoading = true;
    });
    final books = await StorageService.instance.getBooks();
    setState(() {
      _books = books;
      _isLoading = false;
    });
  }

  void _showCreateBookDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Recipe Book'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Book Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = titleController.text.trim();
              if (name.isNotEmpty) {
                final newBook = RecipeBook(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  description: descController.text.trim(),
                );
                await StorageService.instance.saveBook(newBook);
                if (mounted) Navigator.pop(ctx);
                _loadBooks();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _deleteBook(RecipeBook book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recipe Book'),
        content: Text('Are you sure you want to delete "${book.name}" and all its recipes?'),
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
      await StorageService.instance.deleteBook(book.id);
      _loadBooks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Recipe Books'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _books.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.menu_book, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No recipe books found',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: _books.length,
                  itemBuilder: (context, index) {
                    final book = _books[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      elevation: 2,
                      child: InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BookDetailScreen(book: book),
                            ),
                          );
                          _loadBooks();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primaryContainer,
                                    child: Icon(
                                      Icons.book,
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (value) {
                                      if (value == 'share') {
                                        SharingService.shareRecipeBook(book);
                                      } else if (value == 'delete') {
                                        _deleteBook(book);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'share',
                                        child: Row(
                                          children: [
                                            Icon(Icons.share),
                                            SizedBox(width: 8),
                                            Text('Share Book'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete),
                                            SizedBox(width: 8),
                                            Text('Delete Book'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                book.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                book.description.isNotEmpty
                                    ? book.description
                                    : 'Recipe collection',
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateBookDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Book'),
      ),
    );
  }
}
