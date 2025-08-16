import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

@immutable
class TextMarks {
  final bool bold;
  final bool italic;
  final bool underline;
  final bool code;
  final String? link;

  const TextMarks({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.code = false,
    this.link,
  });

  TextMarks copyWith({bool? bold, bool? italic, bool? underline, bool? code, String? link}) =>
      TextMarks(
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        code: code ?? this.code,
        link: link ?? this.link,
      );

  Map<String, dynamic> toJson() => {
        'bold': bold,
        'italic': italic,
        'underline': underline,
        'code': code,
        if (link != null) 'link': link,
      };

  static TextMarks fromJson(Map<String, dynamic> json) => TextMarks(
        bold: json['bold'] == true,
        italic: json['italic'] == true,
        underline: json['underline'] == true,
        code: json['code'] == true,
        link: json['link'] as String?,
      );
}

@immutable
class TextSpanNode {
  final String text;
  final TextMarks marks;

  const TextSpanNode(this.text, {this.marks = const TextMarks()});

  TextSpanNode copyWith({String? text, TextMarks? marks}) =>
      TextSpanNode(text ?? this.text, marks: marks ?? this.marks);

  Map<String, dynamic> toJson() => {
        'type': 'text',
        'text': text,
        'marks': marks.toJson(),
      };

  static TextSpanNode fromJson(Map<String, dynamic> json) =>
      TextSpanNode(json['text'] as String, marks: TextMarks.fromJson(Map<String, dynamic>.from(json['marks'] as Map)));
}

/// Base class for block nodes.
@immutable
abstract class BlockNode {
  final String id;
  final String type; // paragraph, heading, listItem, quote, code, divider, embed
  final List<TextSpanNode> inlines; // empty for divider/embed

  BlockNode({
    String? id,
    required this.type,
    this.inlines = const [],
  }) : id = id ?? _uuid.v4();

  BlockNode copyWith({List<TextSpanNode>? inlines});

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'inlines': inlines.map((e) => e.toJson()).toList(),
      };
}

class ParagraphNode extends BlockNode {
  ParagraphNode({super.id, List<TextSpanNode> inlines = const []}) : super(type: 'paragraph', inlines: inlines);

  @override
  ParagraphNode copyWith({List<TextSpanNode>? inlines}) => ParagraphNode(id: id, inlines: inlines ?? this.inlines);
}

class HeadingNode extends BlockNode {
  final int level; // 1..6
  HeadingNode({super.id, required this.level, List<TextSpanNode> inlines = const []})
      : assert(level >= 1 && level <= 6),
        super(type: 'heading', inlines: inlines);

  @override
  HeadingNode copyWith({List<TextSpanNode>? inlines, int? level}) =>
      HeadingNode(id: id, level: level ?? this.level, inlines: inlines ?? this.inlines);

  @override
  Map<String, dynamic> toJson() => super.toJson()..['level'] = level;
}

class ListItemNode extends BlockNode {
  final bool ordered;
  final int indent; // nesting level
  ListItemNode({super.id, this.ordered = false, this.indent = 0, List<TextSpanNode> inlines = const []})
      : super(type: 'listItem', inlines: inlines);

  @override
  ListItemNode copyWith({List<TextSpanNode>? inlines, bool? ordered, int? indent}) => ListItemNode(
        id: id,
        ordered: ordered ?? this.ordered,
        indent: indent ?? this.indent,
        inlines: inlines ?? this.inlines,
      );

  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..addAll({'ordered': ordered, 'indent': indent});
}

class QuoteNode extends BlockNode {
  QuoteNode({super.id, List<TextSpanNode> inlines = const []}) : super(type: 'quote', inlines: inlines);
  @override
  QuoteNode copyWith({List<TextSpanNode>? inlines}) => QuoteNode(id: id, inlines: inlines ?? this.inlines);
}

class CodeBlockNode extends BlockNode {
  final String? language;
  CodeBlockNode({super.id, this.language, List<TextSpanNode> inlines = const []})
      : super(type: 'code', inlines: inlines);

  @override
  CodeBlockNode copyWith({List<TextSpanNode>? inlines, String? language}) =>
      CodeBlockNode(id: id, language: language ?? this.language, inlines: inlines ?? this.inlines);

  @override
  Map<String, dynamic> toJson() => super.toJson()..['language'] = language;
}

class DividerNode extends BlockNode {
  DividerNode({super.id}) : super(type: 'divider', inlines: const []);
  @override
  DividerNode copyWith({List<TextSpanNode>? inlines}) => this; // no-op
}

class EmbedNode extends BlockNode {
  final String kind; // e.g., image, custom
  final Map<String, dynamic> data;
  EmbedNode({super.id, required this.kind, this.data = const {}}) : super(type: 'embed', inlines: const []);

  @override
  EmbedNode copyWith({List<TextSpanNode>? inlines, String? kind, Map<String, dynamic>? data}) =>
      EmbedNode(id: id, kind: kind ?? this.kind, data: data ?? this.data);

  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..addAll({'kind': kind, 'data': data});
}