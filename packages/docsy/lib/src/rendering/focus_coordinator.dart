import 'package:flutter/foundation.dart';

class CurrentSelection {
  final int blockIndex;
  final int start;
  final int end;
  const CurrentSelection(this.blockIndex, this.start, this.end);

  bool get isRange => start != end;
}

class FocusCoordinator {
  final ValueNotifier<int?> focusedBlock = ValueNotifier<int?>(null);
  final ValueNotifier<CurrentSelection?> selection =
      ValueNotifier<CurrentSelection?>(null);

  void setFocused(int index) => focusedBlock.value = index;
  void setSelection(int blockIndex, int start, int end) =>
      selection.value = CurrentSelection(blockIndex, start, end);
}
