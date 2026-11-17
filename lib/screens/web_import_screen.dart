import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/recipe_parser_service.dart';
import 'recipe_edit_screen.dart';

class FavoriteWebsite {
  final String name;
  final String url;

  const FavoriteWebsite({
    required this.name,
    required this.url,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
      };

  factory FavoriteWebsite.fromJson(Map<String, dynamic> json) => FavoriteWebsite(
        name: json['name'] ?? '',
        url: json['url'] ?? '',
      );
}

class WebImportScreen extends StatefulWidget {
  final String bookId;
  final String? initialUrl;

  const WebImportScreen({
    Key? key,
    required this.bookId,
    this.initialUrl,
  }) : super(key: key);

  @override
  State<WebImportScreen> createState() => _WebImportScreenState();
}

class _WebImportScreenState extends State<WebImportScreen> {
  WebViewController? _controller;
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  bool _isWebViewSupported = true;

  List<FavoriteWebsite> _favoriteWebsites = [];

  static const String _favoritesKey = 'user_favorite_websites';

  @override
  void initState() {
    super.initState();
    final startUrl = widget.initialUrl ?? 'https://www.google.com';
    _urlController.text = startUrl;
    _loadFavorites();

    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _urlController.text = url;
                });
              }
            },
            onPageFinished: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(startUrl));
    } catch (e) {
      _isWebViewSupported = false;
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_favoritesKey);
    if (data != null && data.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(data);
        setState(() {
          _favoriteWebsites = list.map((e) => FavoriteWebsite.fromJson(e)).toList();
        });
      } catch (_) {}
    }
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(_favoriteWebsites.map((e) => e.toJson()).toList());
    await prefs.setString(_favoritesKey, data);
  }

  bool _isCurrentUrlFavorite() {
    final currentUrl = _urlController.text.trim();
    return _favoriteWebsites.any((site) => _normalizeUrl(site.url) == _normalizeUrl(currentUrl));
  }

  String _normalizeUrl(String url) {
    return url.trim().toLowerCase().replaceAll(RegExp(r'/$'), '');
  }

  void _toggleFavorite() {
    final currentUrl = _urlController.text.trim();
    if (currentUrl.isEmpty) return;

    if (_isCurrentUrlFavorite()) {
      setState(() {
        _favoriteWebsites.removeWhere(
          (site) => _normalizeUrl(site.url) == _normalizeUrl(currentUrl),
        );
      });
      _saveFavorites();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from favorites')),
      );
    } else {
      _showAddFavoriteDialog(currentUrl);
    }
  }

  void _showAddFavoriteDialog(String defaultUrl) {
    Uri? parsed = Uri.tryParse(defaultUrl);
    String defaultName = parsed?.host.replaceAll('www.', '') ?? 'My Favorite Site';
    if (defaultName.isEmpty) defaultName = 'My Favorite Site';

    final nameController = TextEditingController(text: defaultName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add to Favorites'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Site Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              defaultUrl,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  _favoriteWebsites.add(FavoriteWebsite(name: name, url: defaultUrl));
                });
                _saveFavorites();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Saved "$name" to favorites')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _removeFavorite(FavoriteWebsite site) {
    setState(() {
      _favoriteWebsites.removeWhere((item) => item.url == site.url);
    });
    _saveFavorites();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Removed "${site.name}" from favorites')),
    );
  }

  void _openUrl(String targetUrl) {
    _urlController.text = targetUrl;
    if (_isWebViewSupported && _controller != null) {
      _controller!.loadRequest(Uri.parse(targetUrl));
    } else {
      _fetchDirectUrl();
    }
  }

  Future<void> _extractRecipeFromPage() async {
    if (_controller == null) {
      _fetchDirectUrl();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUrl = await _controller!.currentUrl() ?? '';
      final htmlContent = await _controller!.runJavaScriptReturningResult(
        "document.documentElement.outerHTML",
      );

      String rawHtml = htmlContent.toString();
      if (rawHtml.startsWith('"') && rawHtml.endsWith('"')) {
        rawHtml = jsonDecode(rawHtml);
      }

      final recipe = RecipeParserService.parseHtmlContent(
        rawHtml,
        widget.bookId,
        url: currentUrl,
      );

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeEditScreen(
            bookId: widget.bookId,
            initialRecipe: recipe,
          ),
        ),
      );

      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to extract recipe: $e')),
        );
      }
    }
  }

  Future<void> _fetchDirectUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final recipe = await RecipeParserService.fetchAndParseUrl(url, widget.bookId);

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (recipe != null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeEditScreen(
            bookId: widget.bookId,
            initialRecipe: recipe,
          ),
        ),
      );

      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not extract recipe from URL.')),
      );
    }
  }

  void _loadEnteredUrl() {
    String input = _urlController.text.trim();
    if (input.isEmpty) return;

    if (!input.startsWith('http://') && !input.startsWith('https://')) {
      input = 'https://www.google.com/search?q=' + Uri.encodeComponent(input);
    }

    _openUrl(input);
  }

  Widget _buildFavoritesBar() {
    if (_favoriteWebsites.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 50,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _favoriteWebsites.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final site = _favoriteWebsites[index];
          return GestureDetector(
            onLongPress: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Remove Favorite'),
                  content: Text('Remove "${site.name}" from your favorites?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _removeFavorite(site);
                      },
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              );
            },
            child: ActionChip(
              avatar: const Icon(Icons.bookmark, size: 16),
              label: Text(site.name),
              onPressed: () => _openUrl(site.url),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFav = _isCurrentUrlFavorite();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            hintText: 'Search or type web address',
            border: InputBorder.none,
          ),
          keyboardType: TextInputType.url,
          onSubmitted: (_) => _loadEnteredUrl(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? Colors.amber : null,
            ),
            tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: _loadEnteredUrl,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFavoritesBar(),
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: _isWebViewSupported && _controller != null
                ? WebViewWidget(controller: _controller!)
                : Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.web_asset_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'In-app Web Browser view is unavailable on this desktop environment.',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Select a favorite website or paste a recipe URL in the address bar to fetch and parse directly.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _fetchDirectUrl,
                          icon: const Icon(Icons.download),
                          label: const Text('Fetch & Extract from URL'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: _isWebViewSupported
          ? FloatingActionButton.extended(
              onPressed: _extractRecipeFromPage,
              icon: const Icon(Icons.download),
              label: const Text('Extract Recipe'),
            )
          : null,
    );
  }
}
