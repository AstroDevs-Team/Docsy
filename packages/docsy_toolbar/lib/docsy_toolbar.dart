library docsy_toolbar;

import 'package:flutter/material.dart';
import 'package:docsy/docsy.dart';
import 'package:url_launcher/url_launcher.dart';

class DocsyToolbar extends StatelessWidget {
  final EditorController controller;
  const DocsyToolbar({super.key, required this.controller});

  void _withSelection(void Function(int blockIndex, int start, int end) run) {
    final sel = controller.selection;
    if (sel == null) return;
    if (sel.base.block != sel.extent.block) return; // single-block only (MVP)
    final start = sel.base.offset <= sel.extent.offset
        ? sel.base.offset
        : sel.extent.offset;
    final end = sel.base.offset <= sel.extent.offset
        ? sel.extent.offset
        : sel.base.offset;
    if (start == end) return; // collapsed caret
    run(sel.base.block, start, end);
  }

  /// Returns the href (if any) at the current caret/selection start.
  String? _hrefAtSelection() {
    final sel = controller.selection;
    if (sel == null) return null;
    if (sel.base.block != sel.extent.block) return null;

    final blockIndex = sel.base.block;
    final offset = sel.base.offset;
    final block = controller.document.blocks[blockIndex];

    List<TextSpanNode>? spans;
    if (block is ParagraphNode) {
      spans = block.inlines;
    } else if (block is HeadingNode) {
      spans = block.inlines;
    } else if (block is QuoteNode) {
      spans = block.inlines;
    } else if (block is ListItemNode) {
      spans = block.inlines;
    } else {
      return null;
    }

    var cursor = 0;
    for (final s in spans) {
      final start = cursor;
      final end = cursor + s.text.length;
      cursor = end;
      if (offset >= start && offset <= end) {
        return s.marks.link;
      }
    }
    return null;
  }

  Future<void> _addLink(BuildContext context) async {
    final url = await _promptForLink(context);
    if (url == null || url.trim().isEmpty) return;
    _withSelection((b, s, e) => controller.setLinkInRange(b, s, e, url.trim()));
  }

  void _removeLink() {
    _withSelection((b, s, e) => controller.clearLinkInRange(b, s, e));
  }

  Future<String?> _promptForLink(BuildContext context) async {
    final tec = TextEditingController(text: 'https://');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insert link'),
        content: TextField(
          controller: tec,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'https://example.com'),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(tec.text),
              child: const Text('Add')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Inline formatting
        IconButton(
          tooltip: 'Bold (⌘/Ctrl+B)',
          icon: const Icon(Icons.format_bold),
          onPressed: () => _withSelection(
            (b, s, e) => controller.toggleBoldInParagraphRange(b, s, e),
          ),
        ),
        IconButton(
          tooltip: 'Italic (⌘/Ctrl+I)',
          icon: const Icon(Icons.format_italic),
          onPressed: () => _withSelection(
            (b, s, e) => controller.toggleItalicInParagraphRange(b, s, e),
          ),
        ),
        IconButton(
          tooltip: 'Underline (⌘/Ctrl+U)',
          icon: const Icon(Icons.format_underline),
          onPressed: () => _withSelection(
            (b, s, e) => controller.toggleUnderlineInParagraphRange(b, s, e),
          ),
        ),

        const SizedBox(width: 12),

        // Links
        IconButton(
          tooltip: 'Insert link',
          icon: const Icon(Icons.link),
          onPressed: () => _addLink(context),
        ),
        IconButton(
          tooltip: 'Remove link',
          icon: const Icon(Icons.link_off),
          onPressed: _removeLink,
        ),

        const SizedBox(width: 12),

        // Blocks & history
        IconButton(
          tooltip: 'Insert Heading (H2)',
          icon: const Icon(Icons.title),
          onPressed: () => controller.insertHeading(level: 2),
        ),
        IconButton(
          tooltip: 'Insert Divider',
          icon: const Icon(Icons.horizontal_rule),
          onPressed: controller.insertDivider,
        ),
        IconButton(
          tooltip: 'Undo',
          icon: const Icon(Icons.undo),
          onPressed: controller.canUndo ? controller.undo : null,
        ),
        IconButton(
          tooltip: 'Redo',
          icon: const Icon(Icons.redo),
          onPressed: controller.canRedo ? controller.redo : null,
        ),
      ],
    );
  }
}
