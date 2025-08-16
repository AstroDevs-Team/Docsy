import 'package:flutter/foundation.dart';
import '../document/document.dart';
import '../document/nodes.dart';
import '../selection/selection.dart';
import 'transaction.dart';

class EditorController extends ChangeNotifier {
  DocumentRoot _doc;
  DocSelection? _selection;
  final List<DocumentRoot> _undo = [];
  final List<DocumentRoot> _redo = [];

  EditorController({DocumentRoot? document}) : _doc = document ?? _emptyDoc();

  DocumentRoot get document => _doc;
  DocSelection? get selection => _selection;

  set selection(DocSelection? sel) {
    _selection = sel;
    notifyListeners();
  }

  static DocumentRoot _emptyDoc() => DocumentRoot(
        blocks: [
          ParagraphNode(inlines: const [TextSpanNode('')])
        ],
      );

  void _pushUndo() {
    _undo.add(_doc);
    _redo.clear();
  }

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void undo() {
    if (!canUndo) return;
    _redo.add(_doc);
    _doc = _undo.removeLast();
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(_doc);
    _doc = _redo.removeLast();
    notifyListeners();
  }

  /// Run batched operations as a transaction.
  void transact(void Function(EditTransaction tx) build) {
    _pushUndo();
    final tx = EditTransaction();
    build(tx);
    _doc = tx.commit(_doc);
    notifyListeners();
  }

  // ===== Basic block commands (MVP) =====

  /// Toggle bold for ALL spans in a block (legacy MVP behavior).
  void toggleBold(int blockIndex) {
    transact((tx) {
      tx.add((doc) {
        final blocks = [...doc.blocks];
        final block = blocks[blockIndex];
        final updated = block.copyWith(
          inlines: block.inlines
              .map((s) =>
                  s.copyWith(marks: s.marks.copyWith(bold: !s.marks.bold)))
              .toList(),
        );
        blocks[blockIndex] = updated;
        return doc.copyWith(blocks: blocks);
      });
    });
  }

  void insertParagraphAtEnd() {
    transact((tx) {
      tx.add(
        (doc) => doc.copyWith(
          blocks: [
            ...doc.blocks,
            ParagraphNode(inlines: const [TextSpanNode('')])
          ],
        ),
      );
    });
  }

  void insertHeading({int level = 1}) {
    transact((tx) {
      tx.add((doc) {
        final blocks = [
          ...doc.blocks,
          HeadingNode(level: level, inlines: const [TextSpanNode('Heading')]),
        ];
        return doc.copyWith(blocks: blocks);
      });
    });
  }

  void insertDivider() {
    transact((tx) {
      tx.add((doc) => doc.copyWith(blocks: [...doc.blocks, DividerNode()]));
    });
  }

  // ===== Paragraph editing =====

  void setParagraphText(int blockIndex, String text) {
    if (blockIndex < 0 || blockIndex >= _doc.blocks.length) return;
    final block = _doc.blocks[blockIndex];
    if (block is! ParagraphNode) return;

    transact((tx) {
      tx.add((doc) {
        final blocks = [...doc.blocks];
        final p = blocks[blockIndex] as ParagraphNode;
        blocks[blockIndex] = p.copyWith(inlines: [TextSpanNode(text)]);
        return doc.copyWith(blocks: blocks);
      });
    });
  }

  // ===== Selection sync from editable widgets =====

  void setSelectionFromEditable(
      int blockIndex, int baseOffset, int extentOffset) {
    final start = baseOffset < extentOffset ? baseOffset : extentOffset;
    final end = baseOffset < extentOffset ? extentOffset : baseOffset;
    _selection = DocSelection(
      DocPosition(blockIndex, /*inline*/ 0, start),
      DocPosition(blockIndex, /*inline*/ 0, end),
    );
    // Intentionally no notifyListeners(); selection changes every keystroke.
  }

  void setLinkInRange(int blockIndex, int start, int end, String href) {
    _toggleMarkInAnyBlockRange(
        blockIndex,
        start,
        end,
        (m) => TextMarks(
              bold: m.bold,
              italic: m.italic,
              underline: m.underline,
              code: m.code,
              link: href,
            ));
  }

  void clearLinkInRange(int blockIndex, int start, int end) {
    _toggleMarkInAnyBlockRange(
        blockIndex,
        start,
        end,
        (m) => TextMarks(
              bold: m.bold,
              italic: m.italic,
              underline: m.underline,
              code: m.code,
            ));
  }
  // ===== Public range formatting helpers (work for paragraphs/headings/quotes/lists) =====

  void toggleBoldInParagraphRange(int blockIndex, int start, int end) =>
      _toggleMarkInAnyBlockRange(
          blockIndex, start, end, (m) => m.copyWith(bold: !m.bold));

  void toggleItalicInParagraphRange(int blockIndex, int start, int end) =>
      _toggleMarkInAnyBlockRange(
          blockIndex, start, end, (m) => m.copyWith(italic: !m.italic));

  void toggleUnderlineInParagraphRange(int blockIndex, int start, int end) =>
      _toggleMarkInAnyBlockRange(
          blockIndex, start, end, (m) => m.copyWith(underline: !m.underline));

  // ===== Core range mark toggler =====

  void _toggleMarkInAnyBlockRange(
    int blockIndex,
    int start,
    int end,
    TextMarks Function(TextMarks) mutate,
  ) {
    if (blockIndex < 0 || blockIndex >= _doc.blocks.length) return;
    if (start == end) return;

    final block = _doc.blocks[blockIndex];

    // Extract spans + a builder to write back for the given block type.
    List<TextSpanNode>? spans;
    BlockNode Function(List<TextSpanNode>)? rebuild;

    if (block is ParagraphNode) {
      spans = block.inlines;
      rebuild = (ns) => (block).copyWith(inlines: ns);
    } else if (block is HeadingNode) {
      spans = block.inlines;
      rebuild = (ns) => (block).copyWith(inlines: ns);
    } else if (block is QuoteNode) {
      spans = block.inlines;
      rebuild = (ns) => (block).copyWith(inlines: ns);
    } else if (block is ListItemNode) {
      spans = block.inlines;
      rebuild = (ns) => (block).copyWith(inlines: ns);
    } else {
      return; // unsupported block type for inline marks
    }

    transact((tx) {
      tx.add((doc) {
        final blocks = [...doc.blocks];
        final newSpans = _toggleOverRange(spans!, start, end, mutate);
        blocks[blockIndex] = rebuild!(newSpans);
        return doc.copyWith(blocks: blocks);
      });
    });
  }

  // ===== Span splitting/merging helpers =====

  List<TextSpanNode> _toggleOverRange(
    List<TextSpanNode> spans,
    int start,
    int end,
    TextMarks Function(TextMarks) mutate,
  ) {
    final out = <TextSpanNode>[];
    var cursor = 0;

    for (final s in spans) {
      final spanStart = cursor;
      final spanEnd = cursor + s.text.length;
      cursor = spanEnd;

      // No overlap
      if (end <= spanStart || start >= spanEnd) {
        out.add(s);
        continue;
      }

      final os = start.clamp(spanStart, spanEnd);
      final oe = end.clamp(spanStart, spanEnd);

      // Left segment
      if (os > spanStart) {
        out.add(TextSpanNode(
          s.text.substring(0, os - spanStart),
          marks: s.marks,
        ));
      }
      // Middle (toggle)
      if (oe > os) {
        out.add(TextSpanNode(
          s.text.substring(os - spanStart, oe - spanStart),
          marks: mutate(s.marks),
        ));
      }
      // Right segment
      if (oe < spanEnd) {
        out.add(TextSpanNode(
          s.text.substring(oe - spanStart),
          marks: s.marks,
        ));
      }
    }

    return _mergeAdjacentSameMarks(out);
  }

  List<TextSpanNode> _mergeAdjacentSameMarks(List<TextSpanNode> spans) {
    if (spans.isEmpty) return spans;
    final merged = <TextSpanNode>[spans.first];
    for (var i = 1; i < spans.length; i++) {
      final a = merged.last;
      final b = spans[i];
      if (_sameMarks(a.marks, b.marks)) {
        merged[merged.length - 1] = a.copyWith(text: a.text + b.text);
      } else {
        merged.add(b);
      }
    }
    return merged;
  }

  bool _sameMarks(TextMarks a, TextMarks b) =>
      a.bold == b.bold &&
      a.italic == b.italic &&
      a.underline == b.underline &&
      a.code == b.code &&
      a.link == b.link;
}
