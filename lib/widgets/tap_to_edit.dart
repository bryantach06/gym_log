import 'package:flutter/material.dart';

/// Wraps a text field so that, while unfocused, it ignores pointers: drags
/// pass through to an ancestor (e.g. a Dismissible row) instead of being
/// claimed by the field's own drag-to-select gesture. A tap focuses the field
/// and selects its contents, so a new value can be typed straight over it.
class TapToEdit extends StatefulWidget {
  final FocusNode focusNode;
  final TextEditingController controller;
  final Widget child;

  const TapToEdit({
    super.key,
    required this.focusNode,
    required this.controller,
    required this.child,
  });

  @override
  State<TapToEdit> createState() => _TapToEditState();
}

class _TapToEditState extends State<TapToEdit> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(TapToEdit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() => setState(() {});

  void _activate() {
    final text = widget.controller.text;
    widget.controller.selection = TextSelection(baseOffset: 0, extentOffset: text.length);
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.focusNode.hasFocus;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: editing ? null : _activate,
      child: IgnorePointer(ignoring: !editing, child: widget.child),
    );
  }
}
