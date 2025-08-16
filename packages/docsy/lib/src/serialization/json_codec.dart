import '../document/document.dart';
import '../document/nodes.dart';
import 'schema.dart';

class DocsyJson {
  static Map<String, dynamic> encode(DocumentRoot doc) => doc.toJson();

  static DocumentRoot decode(Map<String, dynamic> json) {
    final schema = (json['schema'] as int?) ?? DocsySchema.current;
    final blocksJson = (json['blocks'] as List?) ?? const [];
    final blocks = <BlockNode>[];
    for (final b in blocksJson) {
      final m = Map<String, dynamic>.from(b as Map);
      switch (m['type']) {
        case 'paragraph':
          blocks.add(ParagraphNode(inlines: _readInlines(m)));
          break;
        case 'heading':
          blocks.add(HeadingNode(
              level: (m['level'] as int?) ?? 1, inlines: _readInlines(m)));
          break;
        case 'quote':
          blocks.add(QuoteNode(inlines: _readInlines(m)));
          break;
        case 'divider':
          blocks.add(DividerNode());
          break;
        case 'listItem':
          blocks.add(ListItemNode(
            ordered: m['ordered'] == true,
            indent: (m['indent'] as int?) ?? 0,
            inlines: _readInlines(m),
          ));
          break;
        case 'code':
          blocks.add(CodeBlockNode(
              language: m['language'] as String?, inlines: _readInlines(m)));
          break;
        case 'embed':
          blocks.add(EmbedNode(
              kind: m['kind'] as String? ?? 'custom',
              data: Map<String, dynamic>.from(m['data'] ?? {})));
          break;
        default:
          blocks.add(ParagraphNode(inlines: _readInlines(m)));
      }
    }
    return DocumentRoot(schemaVersion: schema, blocks: blocks);
  }

  static List<TextSpanNode> _readInlines(Map<String, dynamic> m) {
    final list = (m['inlines'] as List?) ?? const [];
    return [
      for (final s in list)
        TextSpanNode.fromJson(Map<String, dynamic>.from(s as Map))
    ];
  }
}
