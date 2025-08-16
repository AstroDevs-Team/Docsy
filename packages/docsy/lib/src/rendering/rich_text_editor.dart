import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controller/editor_controller.dart';
import '../document/nodes.dart';
import 'block_widgets.dart';
import 'editable_paragraph.dart';

TextStyle _applyMarksView(TextStyle base, TextMarks m) {
  var s = base;
  if (m.bold) s = s.copyWith(fontWeight: FontWeight.w600);
  if (m.italic) s = s.copyWith(fontStyle: FontStyle.italic);
  if (m.underline) s = s.copyWith(decoration: TextDecoration.underline);
  if (m.code)
    s = s.copyWith(fontFamily: 'monospace', backgroundColor: Colors.black12);
  return s;
}

class RichTextEditor extends StatefulWidget {
  final EditorController controller;
  final bool isEditing;
  const RichTextEditor({
    super.key,
    required this.controller,
    this.isEditing = true,
  });

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant RichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final doc = widget.controller.document;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      dragStartBehavior: DragStartBehavior.down,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < doc.blocks.length; i++) ...[
            _buildBlock(doc.blocks[i], i),
            if (i != doc.blocks.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildBlock(BlockNode node, int index) {
    final key = ValueKey(node.id); // stable identity per block

    switch (node) {
      case ParagraphNode n:
        if (widget.isEditing) {
          return EditableParagraph(
            key: key,
            node: n,
            index: index,
            controller: widget.controller,
          );
        } else {
          return _ReadOnlyParagraph(
            key: key,
            node: n,
          );
        }

      case HeadingNode n:
        return _EditableHeading(
          isEditing: widget.isEditing,
          key: key,
          node: n,
          index: index,
          controller: widget.controller,
        );

      case QuoteNode n:
        return _EditableQuote(
          key: key,
          node: n,
          index: index,
          controller: widget.controller,
          isEditing: widget.isEditing,
        );

      case DividerNode _:
        return const DividerBlock();

      case ListItemNode n:
        final prefix = n.ordered ? '• ' : '• ';
        if (widget.isEditing) {
          // Render with a bullet + editable inner paragraph.
          return Row(
            key: key,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(prefix),
              const SizedBox(width: 4),
              Expanded(
                child: EditableParagraph(
                  key: ValueKey('${n.id}-content'),
                  node: ParagraphNode(inlines: n.inlines),
                  index: index,
                  controller: widget.controller,
                ),
              ),
            ],
          );
        } else {
          // Read-only with clickable link spans
          return Row(
            key: key,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(prefix),
              const SizedBox(width: 4),
              Expanded(
                child: _ReadOnlyParagraph(
                  key: ValueKey('${n.id}-content'),
                  node: ParagraphNode(inlines: n.inlines),
                ),
              ),
            ],
          );
        }

      default:
        return const Text('[Unsupported block in MVP]');
    }
  }
}

/// ===== Helper: turn a (text, href) into a Span; use Link widget on web for reliability =====
InlineSpan _spanOrLink({
  required String text,
  required TextStyle style,
  required String? href,
  required TextMarks marks,
}) {
// Apply bold/italic/underline/code first
  final marked = _applyMarksView(style, marks);
  if (href == null || href.isEmpty) {
    return TextSpan(text: text, style: marked);
  }

  return TextSpan(
    text: text,
    style: marked.copyWith(
      color: Colors.blue,
      decoration: TextDecoration.underline,
    ),
    recognizer: TapGestureRecognizer()
      ..onTap = () async {
        final uri = Uri.tryParse(href);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
  );
}

/// ===== Read-only paragraph with clickable links =====
class _ReadOnlyParagraph extends StatelessWidget {
  final ParagraphNode node;
  const _ReadOnlyParagraph({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.copyWith(fontSize: 16);
    return Text.rich(
      TextSpan(
        children: [
          for (final s in node.inlines)
            _spanOrLink(
              text: s.text,
              style: style,
              marks: s.marks,
              href: s.marks.link,
            ),
        ],
      ),
    );
  }
}

/// ===== Editable Heading (edit + view w/ links) =====
class _EditableHeading extends StatefulWidget {
  final HeadingNode node;
  final int index; // block index
  final EditorController controller;
  final bool isEditing;
  const _EditableHeading({
    super.key,
    required this.node,
    required this.index,
    required this.controller,
    required this.isEditing,
  });

  @override
  State<_EditableHeading> createState() => _EditableHeadingState();
}

class _EditableHeadingState extends State<_EditableHeading> {
  late final TextEditingController _tec;
  late final FocusNode _focus;
  bool _applyingDocChange = false;

  static String _textFromNode(HeadingNode n) =>
      n.inlines.map((s) => s.text).join();

  @override
  void initState() {
    super.initState();
    _tec = TextEditingController(text: _textFromNode(widget.node));
    _focus = FocusNode(debugLabel: 'DocsyEditableHeading');
    _tec.addListener(_onTextOrSelectionChange);
    widget.controller.addListener(_onDocChanged);
  }

  @override
  void didUpdateWidget(covariant _EditableHeading oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onDocChanged);
      widget.controller.addListener(_onDocChanged);
    }
    final t = _textFromNode(widget.node);
    if (!_applyingDocChange && _tec.text != t) {
      final sel = _tec.selection;
      _tec.text = t;
      final pos = t.length.clamp(0, t.length);
      _tec.selection = sel.copyWith(baseOffset: pos, extentOffset: pos);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onDocChanged);
    _tec.removeListener(_onTextOrSelectionChange);
    _tec.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onDocChanged() {
    if (!mounted) return;
    final latest = widget.controller.document.blocks[widget.index];
    if (latest is HeadingNode) {
      final t = _textFromNode(latest);
      if (_tec.text != t) {
        _applyingDocChange = true;
        _tec.text = t;
        _tec.selection = TextSelection.collapsed(offset: t.length);
        _applyingDocChange = false;
      }
    }
  }

  void _onTextOrSelectionChange() {
    final sel = _tec.selection;
    if (sel.isValid) {
      widget.controller.setSelectionFromEditable(
        widget.index,
        sel.baseOffset,
        sel.extentOffset,
      );
    }
    if (!_applyingDocChange) {
      widget.controller.transact((tx) {
        tx.add((doc) {
          final blocks = [...doc.blocks];
          final h = blocks[widget.index] as HeadingNode;
          blocks[widget.index] = h.copyWith(inlines: [TextSpanNode(_tec.text)]);
          return doc.copyWith(blocks: blocks);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizes = {1: 28.0, 2: 24.0, 3: 20.0, 4: 18.0, 5: 16.0, 6: 14.0};
    final style = DefaultTextStyle.of(context).style.copyWith(
          fontSize: sizes[widget.node.level]!,
          fontWeight: FontWeight.w700,
        );

    if (widget.isEditing) {
      return EditableText(
        controller: _tec,
        focusNode: _focus,
        style: style,
        cursorColor: Theme.of(context).colorScheme.primary,
        backgroundCursorColor: Colors.black12,
        selectionColor: Theme.of(context).colorScheme.primary.withOpacity(0.25),
        keyboardType: TextInputType.text,
        selectionControls: materialTextSelectionControls,
      );
    } else {
      // Read-only mode with clickable links
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        child: Text.rich(
          TextSpan(
            children: widget.node.inlines.map((span) {
              final marked = _applyMarksView(style, span.marks);
              if (span.marks.link != null) {
                return TextSpan(
                  text: span.text,
                  style: marked.copyWith(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () async {
                      final uri = Uri.tryParse(span.marks.link!);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                );
              }
              return TextSpan(text: span.text, style: marked);
            }).toList(),
          ),
        ),
      );
    }
  }
}

/// ===== Editable Quote (edit + view w/ links) =====
class _EditableQuote extends StatefulWidget {
  final QuoteNode node;
  final int index; // block index
  final EditorController controller;
  final bool isEditing;
  const _EditableQuote({
    super.key,
    required this.node,
    required this.index,
    required this.controller,
    required this.isEditing,
  });

  @override
  State<_EditableQuote> createState() => _EditableQuoteState();
}

class _EditableQuoteState extends State<_EditableQuote> {
  late final TextEditingController _tec;
  late final FocusNode _focus;
  bool _applyingDocChange = false;

  String _textFromNode(QuoteNode n) => n.inlines.map((s) => s.text).join();

  @override
  void initState() {
    super.initState();
    _tec = TextEditingController(text: _textFromNode(widget.node));
    _focus = FocusNode(debugLabel: 'DocsyEditableQuote');
    _tec.addListener(_onTextOrSelectionChange);
    widget.controller.addListener(_onDocChanged);
  }

  @override
  void didUpdateWidget(_EditableQuote oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onDocChanged);
      widget.controller.addListener(_onDocChanged);
    }
    final t = _textFromNode(widget.node);
    if (!_applyingDocChange && _tec.text != t) {
      final sel = _tec.selection;
      _tec.text = t;
      final pos = t.length.clamp(0, t.length);
      _tec.selection = sel.copyWith(baseOffset: pos, extentOffset: pos);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onDocChanged);
    _tec.removeListener(_onTextOrSelectionChange);
    _tec.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onDocChanged() {
    if (!mounted) return;
    final latest = widget.controller.document.blocks[widget.index];
    if (latest is QuoteNode) {
      final t = _textFromNode(latest);
      if (_tec.text != t) {
        _applyingDocChange = true;
        _tec.text = t;
        _tec.selection = TextSelection.collapsed(offset: t.length);
        _applyingDocChange = false;
      }
    }
  }

  void _onTextOrSelectionChange() {
    final sel = _tec.selection;
    if (sel.isValid) {
      widget.controller.setSelectionFromEditable(
        widget.index,
        sel.baseOffset,
        sel.extentOffset,
      );
    }
    if (!_applyingDocChange) {
      widget.controller.transact((tx) {
        tx.add((doc) {
          final blocks = [...doc.blocks];
          final q = blocks[widget.index] as QuoteNode;
          blocks[widget.index] = q.copyWith(inlines: [TextSpanNode(_tec.text)]);
          return doc.copyWith(blocks: blocks);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context)
        .style
        .copyWith(fontStyle: FontStyle.italic);

    if (widget.isEditing) {
      return Row(
        key: ValueKey('${widget.node.id}-row'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 4,
              height: 24,
              color: Colors.grey.shade400,
              margin: const EdgeInsets.only(right: 8)),
          Expanded(
            child: EditableText(
              controller: _tec,
              focusNode: _focus,
              style: base,
              cursorColor: Theme.of(context).colorScheme.primary,
              backgroundCursorColor: Colors.black12,
              selectionColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.25),
              keyboardType: TextInputType.multiline,
              maxLines: null,
              selectionControls: materialTextSelectionControls,
            ),
          ),
        ],
      );
    } else {
      // Read-only with clickable WidgetSpan(Link)
      return Row(
        key: ValueKey('${widget.node.id}-row'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 24,
            color: Colors.grey.shade400,
            margin: const EdgeInsets.only(right: 8),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              child: Text.rich(
                TextSpan(
                  children: widget.node.inlines.map((span) {
                    final marked = _applyMarksView(base, span.marks);
                    if (span.marks.link != null) {
                      return TextSpan(
                        text: span.text,
                        style: marked.copyWith(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            final uri = Uri.tryParse(span.marks.link!);
                            if (uri != null && await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                      );
                    }
                    return TextSpan(text: span.text, style: marked);
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }
}
