import 'nodes.dart';

class DocumentRoot {
  final int schemaVersion;
  final List<BlockNode> blocks;

  const DocumentRoot({this.schemaVersion = 1, this.blocks = const []});

  DocumentRoot copyWith({int? schemaVersion, List<BlockNode>? blocks}) =>
      DocumentRoot(schemaVersion: schemaVersion ?? this.schemaVersion, blocks: blocks ?? this.blocks);

  Map<String, dynamic> toJson() => {
        'schema': schemaVersion,
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };
}
