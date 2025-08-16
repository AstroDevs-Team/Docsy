import '../document/document.dart';

typedef DocumentReducer = DocumentRoot Function(DocumentRoot);

class EditTransaction {
  final List<DocumentReducer> _ops = [];
  EditTransaction add(DocumentReducer op) {
    _ops.add(op);
    return this;
  }

  DocumentRoot commit(DocumentRoot doc) {
    var current = doc;
    for (final op in _ops) {
      current = op(current);
    }
    return current;
  }
}
