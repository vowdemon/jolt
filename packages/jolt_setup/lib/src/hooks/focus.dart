import 'package:flutter/widgets.dart';
import 'package:jolt_setup/hooks.dart';

/// Creates a focus node
///
/// The node will be automatically disposed when the component is unmounted
@defineHook
FocusNode useFocusNode({
  String? debugLabel,
  KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent,
  bool skipTraversal = false,
  bool canRequestFocus = true,
  bool descendantsAreFocusable = true,
  bool descendantsAreTraversable = true,
}) {
  return useChangeNotifier(
    () => FocusNode(
      debugLabel: debugLabel,
      onKeyEvent: onKeyEvent,
      skipTraversal: skipTraversal,
      canRequestFocus: canRequestFocus,
      descendantsAreFocusable: descendantsAreFocusable,
      descendantsAreTraversable: descendantsAreTraversable,
    ),
  );
}

/// Creates a focus scope node
///
/// The node will be automatically disposed when the component is unmounted
@defineHook
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
  return useChangeNotifier(
    () => FocusScopeNode(
      debugLabel: debugLabel,
      onKeyEvent: onKeyEvent,
      skipTraversal: skipTraversal,
      canRequestFocus: canRequestFocus,
      traversalEdgeBehavior: traversalEdgeBehavior,
      directionalTraversalEdgeBehavior: directionalTraversalEdgeBehavior,
    ),
  );
}
