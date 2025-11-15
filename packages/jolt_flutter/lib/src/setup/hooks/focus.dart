import 'package:flutter/widgets.dart';

import '../widget.dart';

/// Creates a focus node
///
/// The node will be automatically disposed when the component is unmounted
FocusNode useFocusNode({
  String? debugLabel,
  KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent,
  bool skipTraversal = false,
  bool canRequestFocus = true,
  bool descendantsAreFocusable = true,
  bool descendantsAreTraversable = true,
}) {
  final focusNode = FocusNode(
    debugLabel: debugLabel,
    onKeyEvent: onKeyEvent,
    skipTraversal: skipTraversal,
    canRequestFocus: canRequestFocus,
    descendantsAreFocusable: descendantsAreFocusable,
    descendantsAreTraversable: descendantsAreTraversable,
  );

  onUnmounted(focusNode.dispose);

  return focusNode;
}

/// Creates a focus scope node
///
/// The node will be automatically disposed when the component is unmounted
FocusScopeNode useFocusScopeNode({
  String? debugLabel,
  FocusOnKeyEventCallback? onKeyEvent,
  bool skipTraversal = false,
  bool canRequestFocus = true,
  TraversalEdgeBehavior traversalEdgeBehavior =
      TraversalEdgeBehavior.closedLoop,
  TraversalEdgeBehavior directionalTraversalEdgeBehavior =
      TraversalEdgeBehavior.stop,
}) {
  final scopeNode = FocusScopeNode(
    debugLabel: debugLabel,
    onKeyEvent: onKeyEvent,
    skipTraversal: skipTraversal,
    canRequestFocus: canRequestFocus,
    traversalEdgeBehavior: traversalEdgeBehavior,
    directionalTraversalEdgeBehavior: directionalTraversalEdgeBehavior,
  );

  onUnmounted(scopeNode.dispose);

  return scopeNode;
}
