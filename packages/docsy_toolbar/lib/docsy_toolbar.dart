library docsy_toolbar;

import 'package:docsy/docsy.dart';
import 'package:flutter/material.dart';

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

  Future<void> _insertCodeBlock(BuildContext context) async {
    final raw = await _promptForCode(context);
    if (raw == null) return;

    final parsed = _parseFencedCode(raw);
    final lang = parsed.$1; // language ('' if none)
    final code = parsed.$2; // code content

    if (code.trim().isEmpty) return;

    controller.transact((tx) {
      tx.add((doc) {
        final blocks = [...doc.blocks];
        blocks.add(
          CodeBlockNode(
            language: lang.isEmpty ? null : lang,
          ),
        );
        // Represent code as a single span; marks.code = true for styling
        final idx = blocks.length - 1;
        final cb = blocks[idx] as CodeBlockNode;
        blocks[idx] = cb.copyWith(
          inlines: [TextSpanNode(code, marks: const TextMarks(code: true))],
        );
        return doc.copyWith(blocks: blocks);
      });
    });
  }

  Future<String?> _promptForCode(BuildContext context) async {
    final tec = TextEditingController(
      text: '```dart\nprint("hello world");\n```',
    );
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insert code block'),
        content: SizedBox(
          width: 600,
          child: TextField(
            controller: tec,
            autofocus: true,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'Paste code (supports ```lang ... ``` fenced blocks)',
            ),
            keyboardType: TextInputType.multiline,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(tec.text),
            child: const Text('Insert'),
          ),
        ],
      ),
    );
  }

  (String, String) _parseFencedCode(String raw) {
    final text = raw.trim();
    final re = RegExp(r'```([\w+\-]*)\n([\s\S]*?)```', multiLine: true);
    final m = re.firstMatch(text);
    if (m != null) {
      final lang = (m.group(1) ?? '').trim();
      final code = (m.group(2) ?? '').trimRight();
      return (lang, code);
    }
    // Fallback: whole text is code, no language
    return ('', text);
    // (You could also try to auto-detect language later.)
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
          tooltip: 'Insert Code Block',
          icon: const Icon(Icons.code),
          onPressed: () => _insertCodeBlock(context),
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
