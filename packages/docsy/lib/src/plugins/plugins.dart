import '../document/nodes.dart';

abstract class InputRule {
  bool matches(String lineText);
  BlockNode transform(BlockNode current);
}

abstract class ExternalSerializer {
  String get id;
  String exportDocument(List<BlockNode> blocks);
  List<BlockNode> importDocument(String text);
}
