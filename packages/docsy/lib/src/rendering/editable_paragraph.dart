import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controller/editor_controller.dart';
import '../document/nodes.dart';

/// Applies TextMarks to a base TextStyle.F
TextStyle _applyMarks(TextStyle base, TextMarks m) {
  var s = base;
  if (m.bold) s = s.copyWith(fontWeight: FontWeight.w700);
  if (m.italic) s = s.copyWith(fontStyle: FontStyle.italic);

  if (m.underline) {
    s = s.copyWith(
      decoration: TextDecoration.combine([
        s.decoration ?? TextDecoration.none,
        TextDecoration.underline,
      ]),
    );
  }

  if (m.code) {
    s = s.copyWith(
      fontFamily: 'monospace',
      backgroundColor: Colors.black12,
    );
  }

  if (m.link != null) {
    s = s.copyWith(
      color: Colors.blue,
      decoration: TextDecoration.combine([
        s.decoration ?? TextDecoration.none,
        TextDecoration.underline,
      ]),
    );
  }

  return s;
}

/// Controller that paints spans from the document so inline formatting is visible.
class _DocsyTextController extends TextEditingController {
  _DocsyTextController({
    required this.spansProvider,
    required String initialText,
  }) {
    text = initialText;
  }

  final List<TextSpanNode> Function() spansProvider;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    final spans = spansProvider();
    return TextSpan(
      style: base,
      children: [
        for (final s in spans)
          TextSpan(text: s.text, style: _applyMarks(base, s.marks)),
      ],
    );
  }
}

class EditableParagraph extends StatefulWidget {
  final ParagraphNode node;
  final int index; // block index in the document
  final EditorController controller;

  const EditableParagraph({
    super.key,
    required this.node,
    required this.index,
    required this.controller,
  });

  @override
  State<EditableParagraph> createState() => _EditableParagraphState();
}

class _EditableParagraphState extends State<EditableParagraph> {
  late final _DocsyTextController _tec;
  final FocusNode _focus = FocusNode(debugLabel: 'DocsyEditableParagraph');

  String _lastCommittedText = '';

  String _docText() => widget.node.inlines.map((s) => s.text).join();
  String? _hrefAtCurrentSelection() {
    final sel = _tec.selection;
    if (!sel.isValid) return null;

    // We synced selection to controller already, but we can compute locally too.
    final block = widget.controller.document.blocks[widget.index];
    if (block is! ParagraphNode) return null;
    final spans = block.inlines;

    final offset = sel.baseOffset;
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

  @override
  void initState() {
    super.initState();
    final t = _docText();
    _lastCommittedText = t;

    _tec = _DocsyTextController(
      initialText: t,
      spansProvider: () {
        final block = widget.controller.document.blocks[widget.index];
        if (block is ParagraphNode) return block.inlines;
        return widget.node.inlines;
      },
    );

    // Mirror selection to controller (for toolbar) — no doc writes here.
    _tec.addListener(_syncSelectionOnly);
  }

  @override
  void didUpdateWidget(covariant EditableParagraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    // External text change (undo/redo) — update field without nuking selection.
    final t = _docText();
    if (t != _lastCommittedText && t != _tec.text) {
      final sel = _tec.selection;
      _tec.value = TextEditingValue(
        text: t,
        selection: sel.isValid
            ? TextSelection(
                baseOffset: sel.baseOffset.clamp(0, t.length),
                extentOffset: sel.extentOffset.clamp(0, t.length),
              )
            : TextSelection.collapsed(offset: t.length),
      );
      _lastCommittedText = t;
    }
  }

  @override
  void dispose() {
    _tec.removeListener(_syncSelectionOnly);
    _tec.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ---- Selection sync ONLY (never mutates the document) ----
  void _syncSelectionOnly() {
    final sel = _tec.selection;
    if (sel.isValid) {
      widget.controller.setSelectionFromEditable(
        widget.index,
        sel.baseOffset,
        sel.extentOffset,
      );
    }
  }

  // ---- Commit text edits into the document ----
  void _onChanged(String value) {
    if (value == _lastCommittedText) return; // ignore pure selection moves
    widget.controller.setParagraphText(widget.index, value);
    _lastCommittedText = value;
  }

  // Shortcuts act on the field's current selection
  void _toggleBoldSel() {
    final sel = _tec.selection;
    if (sel.isValid && !sel.isCollapsed) {
      widget.controller
          .toggleBoldInParagraphRange(widget.index, sel.start, sel.end);
    }
  }

  void _toggleItalicSel() {
    final sel = _tec.selection;
    if (sel.isValid && !sel.isCollapsed) {
      widget.controller
          .toggleItalicInParagraphRange(widget.index, sel.start, sel.end);
    }
  }

  void _toggleUnderlineSel() {
    final sel = _tec.selection;
    if (sel.isValid && !sel.isCollapsed) {
      widget.controller
          .toggleUnderlineInParagraphRange(widget.index, sel.start, sel.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 16);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true):
            _toggleBoldSel,
        const SingleActivator(LogicalKeyboardKey.keyB, control: true):
            _toggleBoldSel,
        const SingleActivator(LogicalKeyboardKey.keyI, meta: true):
            _toggleItalicSel,
        const SingleActivator(LogicalKeyboardKey.keyI, control: true):
            _toggleItalicSel,
        const SingleActivator(LogicalKeyboardKey.keyU, meta: true):
            _toggleUnderlineSel,
        const SingleActivator(LogicalKeyboardKey.keyU, control: true):
            _toggleUnderlineSel,
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (details) async {
          // Cmd on macOS, Ctrl on Windows/Linux
          final pressed = HardwareKeyboard.instance.logicalKeysPressed;
          final isCmdOrCtrl = pressed.contains(LogicalKeyboardKey.metaLeft) ||
              pressed.contains(LogicalKeyboardKey.metaRight) ||
              pressed.contains(LogicalKeyboardKey.controlLeft) ||
              pressed.contains(LogicalKeyboardKey.controlRight);

          if (isCmdOrCtrl) {
            final href = _hrefAtCurrentSelection();
            if (href != null && href.isNotEmpty) {
              final uri = Uri.tryParse(href);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          }
        },
        child: TextField(
          controller: _tec,
          focusNode: _focus,
          style: style,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          cursorColor: Theme.of(context).colorScheme.primary,
          selectionControls: materialTextSelectionControls,
          enableInteractiveSelection: true,
          mouseCursor: SystemMouseCursors.text,
          decoration: const InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: _onChanged,
        ),
      ),
    );
  }
}
