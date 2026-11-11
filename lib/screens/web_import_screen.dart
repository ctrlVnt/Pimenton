import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/recipe_parser_service.dart';
import 'recipe_edit_screen.dart';

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

  @override
  void initState() {
    super.initState();
    final startUrl = widget.initialUrl ?? 'https://www.google.com';
    _urlController.text = startUrl;

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

    if (_isWebViewSupported && _controller != null) {
      _controller!.loadRequest(Uri.parse(input));
    } else {
      _urlController.text = input;
      _fetchDirectUrl();
    }
  }

  @override
  Widget build(BuildContext context) {
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
            icon: const Icon(Icons.arrow_forward),
            onPressed: _loadEnteredUrl,
          ),
        ],
      ),
      body: Column(
        children: [
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
                          'Enter or paste a recipe URL in the address bar above and click "Extract Recipe" to fetch and parse it directly.',
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
