class DocPosition {
  final int block;
  final int inline;
  final int offset;
  const DocPosition(this.block, this.inline, this.offset);
}

class DocSelection {
  final DocPosition base;
  final DocPosition extent;
  const DocSelection(this.base, this.extent);

  bool get isCollapsed =>
      base.block == extent.block &&
      base.inline == extent.inline &&
      base.offset == extent.offset;
}
