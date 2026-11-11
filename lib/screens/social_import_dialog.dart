import 'package:flutter/material.dart';
import '../services/recipe_parser_service.dart';
import 'recipe_edit_screen.dart';

class SocialImportDialog extends StatefulWidget {
  final String bookId;

  const SocialImportDialog({Key? key, required this.bookId}) : super(key: key);

  @override
  State<SocialImportDialog> createState() => _SocialImportDialogState();
}

class _SocialImportDialogState extends State<SocialImportDialog> {
  final TextEditingController _urlController = TextEditingController();
  bool _isFetching = false;

  Future<void> _importFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isFetching = true;
    });

    final recipe = await RecipeParserService.fetchAndParseUrl(url, widget.bookId);

    setState(() {
      _isFetching = false;
    });

    if (!mounted) return;

    if (recipe != null) {
      Navigator.pop(context); // Close dialog
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
        // Updated successfully
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not extract recipe info from link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import Social Link'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paste a link from Instagram, TikTok, Facebook, or any recipe blog:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Recipe URL',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
          ),
          if (_isFetching) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isFetching ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isFetching ? null : _importFromUrl,
          child: const Text('Import'),
        ),
      ],
    );
  }
}
